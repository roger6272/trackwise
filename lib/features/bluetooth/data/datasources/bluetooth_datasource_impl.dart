import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:injectable/injectable.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/utils/bluetooth_constants.dart';
import '../../../items/domain/entities/item.dart';
import '../../domain/entities/ble_connection_state.dart';
import '../../domain/entities/ble_message.dart';
import '../../domain/entities/sync_state.dart';
import '../models/ble_device_model.dart';
import '../models/ble_message_model.dart';
import 'bluetooth_datasource.dart';

/// Real implementation of BluetoothDataSource using flutter_blue_plus.
///
/// Handles all BLE operations including:
/// - Device scanning with filtering
/// - Connection management
/// - Chunked writes (180-byte MTU, 30ms delay)
/// - Chunk assembly for incoming messages
/// - Notification subscriptions
@LazySingleton(as: BluetoothDataSource)
class BluetoothDataSourceImpl implements BluetoothDataSource {
  BluetoothDevice? _connectedDevice;
  BleDeviceModel? _connectedDeviceModel;

  // Cached characteristics (cleared on disconnect, reused for performance)
  BluetoothCharacteristic? _readChar;
  BluetoothCharacteristic? _notifyChar;
  BluetoothCharacteristic? _setItemsChar;
  BluetoothCharacteristic? _writeChar;

  // Negotiated MTU (payload size, excluding ATT overhead)
  int _negotiatedMtu = BluetoothConstants.defaultMtuLimit;

  // Notification stream management
  StreamSubscription<List<int>>? _notifySubscription;
  final _messageController = StreamController<BleMessage>.broadcast();
  final _messageBuffer = StringBuffer();
  Timer? _messageTimeoutTimer;

  /// Timeout for incomplete message assembly (5 seconds)
  static const Duration _messageAssemblyTimeout = Duration(seconds: 5);

  /// Maximum buffer size to prevent memory exhaustion (64KB)
  static const int _maxBufferSize = 64 * 1024;

  /// Timeout for multi-device sync commands (10 seconds)
  static const Duration _syncCommandTimeout = Duration(seconds: 10);

  /// Number of items per chunk for override protocol
  static const int _overrideChunkSize = 10;

  // Connection state tracking
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  final _connectionStateController = StreamController<BleConnectionState>.broadcast();

  // BLE write queue for serialization (prevents interleaved chunks)
  final _writeQueue = <_WriteOperation>[];
  bool _isProcessingWrite = false;

  @override
  bool get isScanning => FlutterBluePlus.isScanningNow;

  @override
  BleDeviceModel? get connectedDevice => _connectedDeviceModel;

  // ========== Scanning ==========

  @override
  Stream<List<BleDeviceModel>> scanDevices({
    Duration timeout = const Duration(seconds: 15),
    String? filterByName,
  }) {
    final controller = StreamController<List<BleDeviceModel>>();
    final devices = <String, BleDeviceModel>{};

    StreamSubscription<List<ScanResult>>? scanSubscription;

    controller.onListen = () async {
      // IMPORTANT: Set up listener BEFORE starting scan to avoid race condition
      scanSubscription = FlutterBluePlus.scanResults.listen(
        (results) {
          for (final result in results) {
            // Only include devices with a name
            if (result.device.platformName.isEmpty) {
              continue;
            }

            // Apply name filter if provided
            if (filterByName != null) {
              if (!result.device.platformName.toLowerCase()
                  .contains(filterByName.toLowerCase())) {
                continue;
              }
            }

            final model = BleDeviceModel.fromScanResult(result);
            devices[model.id] = model;
          }

          // Emit sorted by RSSI (strongest first)
          final sortedDevices = devices.values.toList()
            ..sort((a, b) => b.rssi.compareTo(a.rssi));
          controller.add(sortedDevices);
        },
        onError: controller.addError,
      );

      // Wait for Bluetooth adapter to be on
      await FlutterBluePlus.adapterState
          .where((val) => val == BluetoothAdapterState.on)
          .first;

      // Set up scan completion listener BEFORE starting scan to avoid race condition
      // (scan could complete before listener is attached if we use .then() after startScan)
      // Add timeout to prevent hanging if scan fails or completes instantly
      FlutterBluePlus.isScanning
          .where((s) => !s)
          .skip(1) // Skip initial false state before scan starts
          .first
          .timeout(timeout + const Duration(seconds: 5), onTimeout: () => false)
          .then((_) {
        if (!controller.isClosed) {
          controller.close();
        }
      });

      // Now start the scan
      await FlutterBluePlus.startScan(
        timeout: timeout,
        androidUsesFineLocation: true,
      );
    };

    controller.onCancel = () {
      scanSubscription?.cancel();
      FlutterBluePlus.stopScan();
    };

    return controller.stream;
  }

  @override
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  // ========== Connection ==========

  @override
  Future<BluetoothDevice> connect(String deviceId) async {
    // Stop any ongoing scan before connecting (helps avoid GATT 133 errors)
    if (FlutterBluePlus.isScanningNow) {
      await FlutterBluePlus.stopScan();
      // Brief delay to let the BLE stack settle
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // Disconnect from any existing connection
    if (_connectedDevice != null) {
      await disconnect(_connectedDevice!.remoteId.str);
    }

    final device = BluetoothDevice.fromId(deviceId);

    // Retry connection with exponential backoff for GATT 133 errors
    await _connectWithRetry(device, maxRetries: 3);

    _connectedDevice = device;
    _connectedDeviceModel = BleDeviceModel.fromBluetoothDevice(device);

    // Request high connection priority for faster data transfer
    // High priority: ~7.5ms connection interval (vs ~30ms default)
    // This is optional - fails silently if unsupported (e.g., iOS ignores this)
    try {
      await device.requestConnectionPriority(
        connectionPriorityRequest: ConnectionPriority.high,
      );
      debugPrint('Requested HIGH connection priority (target: ~7.5ms interval)');
      debugPrint('   - Default interval: ~30-50ms');
      debugPrint('   - High priority interval: ~7.5-15ms');
      debugPrint('   - Note: iOS ignores this request (Apple controls parameters)');
    } catch (e) {
      debugPrint('Could not set connection priority: $e');
      debugPrint('   Connection will continue with default parameters');
    }

    // Request larger MTU for faster data transfer
    // Default BLE MTU is 23 bytes, we request 512 for larger payloads
    try {
      final mtu = await device.requestMtu(BluetoothConstants.requestedMtu);
      // flutter_blue_plus enforces max write size as (MTU - 3), but also caps at 512
      // Use the more conservative value to avoid write failures
      final calculatedPayload = mtu - BluetoothConstants.attOverhead;
      _negotiatedMtu = calculatedPayload > 509 ? 509 : calculatedPayload; // Cap at 509 (512-3)
      debugPrint('MTU negotiated: $mtu bytes (payload: $_negotiatedMtu bytes)');
      debugPrint('   - Default MTU: 23 bytes');
      debugPrint('   - Requested: ${BluetoothConstants.requestedMtu} bytes');
      debugPrint('   - Negotiated: $mtu bytes, using payload: $_negotiatedMtu bytes');
    } catch (e) {
      _negotiatedMtu = BluetoothConstants.defaultMtuLimit;
      debugPrint('MTU negotiation failed, using default: $_negotiatedMtu bytes');
      debugPrint('   Error: $e');
    }

    // Set up connection state monitoring
    _connectionSubscription?.cancel();
    _connectionSubscription = device.connectionState.listen((state) {
      // Only emit disconnected state here - connected state will be emitted
      // after service discovery completes to avoid race conditions
      if (state == BluetoothConnectionState.disconnected) {
        _connectionStateController.add(BleConnectionState.disconnected);
        _clearConnectionState();
      }
    });

    // NOTE: Do NOT emit connected state here!
    // The repository will call emitConnectedState() after discoverServices() completes
    // to ensure characteristics are cached before any code reacts to "connected"

    return device;
  }

  /// Connects to a BLE device with automatic retry on failure.
  ///
  /// Handles common Android GATT errors (especially 133) by retrying
  /// with exponential backoff: 500ms, 1000ms, 2000ms.
  Future<void> _connectWithRetry(
    BluetoothDevice device, {
    int maxRetries = 3,
  }) async {
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        await device.connect(
          license: License.free,
          timeout: const Duration(seconds: BluetoothConstants.connectionTimeoutSeconds),
          autoConnect: false,
        );
        return; // Success
      } catch (e) {
        final isLastAttempt = attempt == maxRetries;
        final errorStr = e.toString();

        // Check if it's a GATT 133 or similar transient error worth retrying
        final isRetryableError = errorStr.contains('133') ||
            errorStr.contains('GATT') ||
            errorStr.contains('ANDROID_SPECIFIC_ERROR');

        if (isLastAttempt || !isRetryableError) {
          debugPrint('BLE connect failed after ${attempt + 1} attempt(s): $e');
          rethrow;
        }

        // Exponential backoff: 500ms, 1000ms, 2000ms
        final delay = Duration(milliseconds: 500 * (1 << attempt));
        debugPrint('BLE connect failed (attempt ${attempt + 1}/${maxRetries + 1}), retrying in ${delay.inMilliseconds}ms: $e');
        await Future.delayed(delay);

        // Try to clear BLE stack state before retry
        try {
          await device.disconnect();
        } catch (_) {
          // Ignore disconnect errors during retry cleanup
        }
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
  }

  @override
  Future<void> disconnect(String deviceId) async {
    // Cancel connection listener first to prevent double cleanup
    // (listener also calls _clearConnectionState on disconnect)
    _connectionSubscription?.cancel();
    _connectionSubscription = null;

    final device = BluetoothDevice.fromId(deviceId);
    await device.disconnect();
    _clearConnectionState();
  }

  /// Clears all connection state including cached characteristics.
  ///
  /// Called on disconnect to ensure fresh discovery on next connection.
  void _clearConnectionState() {
    _connectedDevice = null;
    _connectedDeviceModel = null;
    _clearCharacteristicCache();
    _negotiatedMtu = BluetoothConstants.defaultMtuLimit;
    _notifySubscription?.cancel();
    _notifySubscription = null;
    _messageBuffer.clear();
    _messageTimeoutTimer?.cancel();
    _messageTimeoutTimer = null;
  }

  /// Clears the cached characteristics.
  ///
  /// This forces a fresh discoverServices() call on next operation,
  /// which is necessary after reconnection to get valid characteristic handles.
  void _clearCharacteristicCache() {
    _readChar = null;
    _notifyChar = null;
    _setItemsChar = null;
    _writeChar = null;
    debugPrint('BLE characteristic cache cleared');
  }

  BleConnectionState _mapConnectionState(BluetoothConnectionState state) {
    switch (state) {
      case BluetoothConnectionState.connected:
        return BleConnectionState.connected;
      case BluetoothConnectionState.disconnected:
        return BleConnectionState.disconnected;
      default:
        return BleConnectionState.connecting;
    }
  }

  @override
  Stream<BleConnectionState> watchConnectionState(String deviceId) {
    // Use our internal controller which gets updated when we connect
    // This ensures we don't miss any state changes
    return _connectionStateController.stream;
  }

  @override
  void emitConnectedState() {
    _connectionStateController.add(BleConnectionState.connected);
  }

  // ========== Services & Characteristics ==========

  /// Ensures characteristics are cached, discovering services only if needed.
  ///
  /// This optimization avoids redundant discoverServices() calls which take
  /// 400-1000ms each. Characteristics are cached after first discovery and
  /// reused for subsequent operations until disconnect.
  Future<void> _ensureCharacteristicsCached(BluetoothDevice device) async {
    // Return immediately if already cached
    if (_writeChar != null && _readChar != null && _notifyChar != null && _setItemsChar != null) {
      debugPrint('Using cached BLE characteristics (skipping discovery)');
      return;
    }

    // Need to discover services and cache characteristics
    debugPrint('Discovering BLE services (first time or cache cleared)...');
    await discoverServices(device);
  }

  @override
  Future<void> discoverServices(BluetoothDevice device) async {
    final services = await device.discoverServices();

    // Search ALL services for our characteristics (like the old working code)
    // Don't filter by service UUID - just find characteristics by their UUIDs
    for (final service in services) {
      for (final char in service.characteristics) {
        final uuid = char.uuid.toString().toLowerCase();

        if (uuid == BluetoothConstants.readCharacteristicUUID.toLowerCase()) {
          _readChar = char;
        } else if (uuid == BluetoothConstants.notifyCharacteristicUUID.toLowerCase()) {
          _notifyChar = char;
        } else if (uuid == BluetoothConstants.setItemsCharacteristicUUID.toLowerCase()) {
          _setItemsChar = char;
        } else if (uuid == BluetoothConstants.writeCharacteristicUUID.toLowerCase()) {
          _writeChar = char;
        }
      }
    }

    // Validate all required characteristics were found
    final missingChars = <String>[];
    if (_readChar == null) missingChars.add('READ');
    if (_notifyChar == null) missingChars.add('NOTIFY');
    if (_setItemsChar == null) missingChars.add('SET_ITEMS');
    if (_writeChar == null) missingChars.add('WRITE');

    if (missingChars.isNotEmpty) {
      final error = 'Missing required BLE characteristics: ${missingChars.join(', ')}. '
          'Device may not be a valid Traxogic device or firmware needs update.';
      debugPrint(error);
      throw StateError(error);
    }

    debugPrint('All BLE characteristics discovered and cached successfully');

    // Subscribe to notifications
    await _subscribeToNotifications();
  }

  Future<void> _subscribeToNotifications() async {
    if (_notifyChar == null) return;

    await _notifyChar!.setNotifyValue(true);

    _notifySubscription?.cancel();
    _notifySubscription = _notifyChar!.lastValueStream.listen(
      _handleNotificationData,
      onError: (error) {
        _messageController.addError(error);
      },
    );
  }

  void _handleNotificationData(List<int> data) {
    if (data.isEmpty) return;

    // Decode bytes to string and add to buffer
    final chunk = utf8.decode(data, allowMalformed: true);
    _messageBuffer.write(chunk);

    // Check buffer size to prevent memory exhaustion
    if (_messageBuffer.length > _maxBufferSize) {
      debugPrint('Message buffer overflow (${_messageBuffer.length} bytes) - clearing to prevent memory exhaustion');
      _messageBuffer.clear();
      _messageTimeoutTimer?.cancel();
      _messageTimeoutTimer = null;
      return;
    }

    // Reset message assembly timeout timer
    _messageTimeoutTimer?.cancel();
    _messageTimeoutTimer = Timer(_messageAssemblyTimeout, _onMessageAssemblyTimeout);

    // Check for complete messages (newline delimiter)
    _processMessageBuffer();
  }

  /// Called when message assembly times out (no newline received within timeout).
  /// Clears stale partial messages to prevent blocking subsequent messages.
  void _onMessageAssemblyTimeout() {
    if (_messageBuffer.isNotEmpty) {
      debugPrint('Message assembly timeout - clearing stale buffer: ${_messageBuffer.toString().substring(0, _messageBuffer.length > 100 ? 100 : _messageBuffer.length)}...');
      _messageBuffer.clear();
    }
  }

  void _processMessageBuffer() {
    var content = _messageBuffer.toString();

    while (content.contains('\n')) {
      final idx = content.indexOf('\n');
      final messageJson = content.substring(0, idx);

      // Update content for next iteration
      content = content.substring(idx + 1);

      if (messageJson.trim().isEmpty) continue;

      try {
        debugPrint('Parsing BLE message: $messageJson');
        final message = BleMessageModel.fromJson(messageJson);
        debugPrint('Parsed message type: ${message.type}, data: ${message.data}');
        _messageController.add(message);
      } catch (e) {
        debugPrint('BLE message parse error: $e');
        debugPrint('Raw message was: $messageJson');
      }
    }

    // Store remaining content back in buffer
    _messageBuffer.clear();
    _messageBuffer.write(content);

    // Cancel timeout if buffer is empty (all messages processed)
    if (content.isEmpty) {
      _messageTimeoutTimer?.cancel();
      _messageTimeoutTimer = null;
    }
  }

  // ========== Write Operations ==========

  @override
  Future<void> writeItems(String deviceId, String jsonData) async {
    if (_setItemsChar == null) {
      throw StateError('SET_ITEMS characteristic not found. Call discoverServices first.');
    }
    // Use queue to prevent interleaved chunks with other writes
    await _enqueueWrite(() => _writeChunked(_setItemsChar!, jsonData));
  }

  @override
  Future<void> writeCommand(String deviceId, String jsonData) async {
    if (_writeChar == null) {
      throw StateError('WRITE characteristic not found. Call discoverServices first.');
    }
    // Use queue to prevent interleaved chunks with other writes
    await _enqueueWrite(() => _writeChunked(_writeChar!, jsonData));
  }

  /// Writes a command without newline delimiter (for prepare_read commands).
  @override
  Future<void> writeCommandRaw(String jsonData) async {
    if (_writeChar == null) {
      throw StateError('WRITE characteristic not found. Call discoverServices first.');
    }
    // Use queue to prevent interleaved chunks with other writes
    await _enqueueWrite(() async {
      final bytes = utf8.encode(jsonData);
      await _writeWithRetry(_writeChar!, bytes);
    });
  }

  /// Writes data in chunks to respect MTU limits.
  ///
  /// Uses negotiated MTU (or default 180 bytes if negotiation failed).
  /// ESP32 requires 20ms delay between chunks to process.
  /// Adds newline delimiter at end so firmware knows when message is complete.
  Future<void> _writeChunked(
    BluetoothCharacteristic char,
    String data,
  ) async {
    // Add newline delimiter so firmware can detect end of message
    // This is critical for messages larger than MTU (like override_chunk)
    final bytes = utf8.encode('$data\n');

    // Use negotiated MTU for optimal chunk size
    final mtu = _negotiatedMtu;
    const chunkDelay = Duration(milliseconds: BluetoothConstants.chunkDelayMs);

    for (var i = 0; i < bytes.length; i += mtu) {
      final end = (i + mtu < bytes.length) ? i + mtu : bytes.length;
      final chunk = bytes.sublist(i, end);

      await _writeWithRetry(char, chunk);

      // Delay between chunks (except after last chunk)
      if (end < bytes.length) {
        await Future.delayed(chunkDelay);
      }
    }
  }

  /// Writes data to a characteristic with automatic retry on failure.
  ///
  /// Retries up to [maxRetries] times with exponential backoff:
  /// - 1st retry: 100ms delay
  /// - 2nd retry: 200ms delay
  /// - 3rd retry: 400ms delay
  Future<void> _writeWithRetry(
    BluetoothCharacteristic char,
    List<int> data, {
    int maxRetries = 3,
  }) async {
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        await char.write(data, withoutResponse: false);
        return; // Success
      } catch (e) {
        final isLastAttempt = attempt == maxRetries;
        if (isLastAttempt) {
          debugPrint('BLE write failed after ${maxRetries + 1} attempts: $e');
          rethrow;
        }

        // Exponential backoff: 100ms, 200ms, 400ms
        final delay = Duration(milliseconds: 100 * (1 << attempt));
        debugPrint('BLE write failed (attempt ${attempt + 1}/${maxRetries + 1}), retrying in ${delay.inMilliseconds}ms: $e');
        await Future.delayed(delay);
      }
    }
  }

  /// Reads data from a characteristic with automatic retry on failure.
  ///
  /// Retries up to [maxRetries] times with exponential backoff:
  /// - 1st retry: 100ms delay
  /// - 2nd retry: 200ms delay
  /// - 3rd retry: 400ms delay
  Future<List<int>> _readWithRetry(
    BluetoothCharacteristic char, {
    int maxRetries = 3,
  }) async {
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        return await char.read();
      } catch (e) {
        final isLastAttempt = attempt == maxRetries;
        if (isLastAttempt) {
          debugPrint('BLE read failed after ${maxRetries + 1} attempts: $e');
          rethrow;
        }

        // Exponential backoff: 100ms, 200ms, 400ms
        final delay = Duration(milliseconds: 100 * (1 << attempt));
        debugPrint('BLE read failed (attempt ${attempt + 1}/${maxRetries + 1}), retrying in ${delay.inMilliseconds}ms: $e');
        await Future.delayed(delay);
      }
    }
    throw StateError('Unreachable');
  }

  // ========== Read Operations ==========

  @override
  Future<String> readData(String deviceId) async {
    if (_readChar == null) {
      throw StateError('READ characteristic not found. Call discoverServices first.');
    }

    final bytes = await _readWithRetry(_readChar!);
    return utf8.decode(bytes, allowMalformed: true);
  }

  @override
  Future<String> rediscoverAndReadData(String deviceId) async {
    if (_connectedDevice == null) {
      throw StateError('Not connected to any device.');
    }

    // Use cached characteristics if available (avoids redundant discovery)
    await _ensureCharacteristicsCached(_connectedDevice!);

    if (_readChar == null) {
      throw StateError('READ characteristic not found after discovery.');
    }

    // Read from the cached characteristic with retry
    final bytes = await _readWithRetry(_readChar!);
    final result = utf8.decode(bytes, allowMalformed: true);
    return result;
  }

  @override
  Future<String> prepareReadCycle(String command) async {
    if (_connectedDevice == null) {
      throw StateError('Not connected to any device.');
    }

    // Ensure characteristics are cached (only discovers if not already cached)
    await _ensureCharacteristicsCached(_connectedDevice!);

    if (_writeChar == null) {
      throw StateError('WRITE characteristic not found.');
    }

    if (_readChar == null) {
      throw StateError('READ characteristic not found.');
    }

    // STEP 1: Write command using cached write characteristic
    await _writeChar!.write(utf8.encode(command), withoutResponse: false);

    // Add delay to give ESP32 time to process command and update READ characteristic
    await Future.delayed(const Duration(milliseconds: BluetoothConstants.prepareReadDelayMs));

    // Verify device is still connected after delay
    if (_connectedDevice == null) {
      throw StateError('Device disconnected during prepare_read cycle.');
    }

    // STEP 2: Read from cached read characteristic
    final bytes = await _readWithRetry(_readChar!);
    final result = utf8.decode(bytes, allowMalformed: true);
    return result;
  }

  @override
  void emitMessage(BleMessage message) {
    _messageController.add(message);
  }

  @override
  Stream<BleMessage> watchNotifications(String deviceId) {
    return _messageController.stream;
  }

  // ========== Multi-Device Sync Commands ==========

  @override
  Future<HandshakeResult> sendHandshake({
    required String uid,
    required int syncSeq,
  }) async {
    if (_writeChar == null) {
      throw StateError('WRITE characteristic not found. Call discoverServices first.');
    }

    debugPrint('Sending handshake: uid=$uid, syncSeq=$syncSeq');

    // Build handshake command
    final command = jsonEncode({
      'cmd': 'handshake',
      'uid': uid,
      'sync_seq': syncSeq,
    });

    // Send command and wait for response with timeout
    final response = await _sendCommandAndWaitForResponse(command);

    debugPrint('Handshake response: $response');

    return HandshakeResult.fromJson(response);
  }

  @override
  Future<OverrideResult> sendOverrideChunked({
    required String uid,
    required int syncSeq,
    required int selectedId,
    required List<Item> items,
    Map<String, String> categoryNames = const {},
  }) async {
    if (_writeChar == null) {
      throw StateError('WRITE characteristic not found. Call discoverServices first.');
    }

    debugPrint('Starting override: uid=$uid, syncSeq=$syncSeq, selectedId=$selectedId, itemCount=${items.length}');

    // Chunk items (10 items per chunk)
    final chunks = <List<Map<String, dynamic>>>[];
    for (var i = 0; i < items.length; i += _overrideChunkSize) {
      final end = min(i + _overrideChunkSize, items.length);
      final chunkItems = items.sublist(i, end).map((item) => _itemToDeviceJson(item, categoryNames)).toList();
      chunks.add(chunkItems);
    }

    // Handle empty items list - still need to send override with 0 chunks
    final totalChunks = chunks.isEmpty ? 0 : chunks.length;

    debugPrint('Override chunked into $totalChunks chunks');

    try {
      // Step 1: Send override_start (includes UID for device setup)
      final startCommand = jsonEncode({
        'cmd': 'override_start',
        'uid': uid,
        'sync_seq': syncSeq,
        'total_chunks': totalChunks,
      });
      await _enqueueWrite(() => _writeChunked(_writeChar!, startCommand));
      debugPrint('Sent override_start');

      // Step 2: Send each chunk sequentially
      // Note: Chunks don't have individual responses - device validates at override_end
      for (var i = 0; i < chunks.length; i++) {
        final chunkCommand = jsonEncode({
          'cmd': 'override_chunk',
          'index': i,
          'items': chunks[i],
        });
        await _enqueueWrite(() => _writeChunked(_writeChar!, chunkCommand));
        debugPrint('Sent override_chunk $i/${chunks.length}');
      }

      // Step 3: Send override_end and wait for response
      final endCommand = jsonEncode({
        'cmd': 'override_end',
        'selected_id': selectedId,
      });

      final response = await _sendCommandAndWaitForResponse(endCommand);

      debugPrint('Override response: $response');

      return OverrideResult.fromJson(response);
    } catch (e) {
      // BLE error during chunk send - abort override
      debugPrint('Override aborted due to error: $e');
      rethrow;
    }
  }

  @override
  Future<SyncCompleteResult> sendSyncComplete(int syncSeq) async {
    if (_writeChar == null) {
      throw StateError('WRITE characteristic not found. Call discoverServices first.');
    }

    debugPrint('Sending sync_complete: syncSeq=$syncSeq');

    final command = jsonEncode({
      'cmd': 'sync_complete',
      'sync_seq': syncSeq,
    });

    final response = await _sendCommandAndWaitForResponse(command);

    debugPrint('sync_complete response: $response');

    return SyncCompleteResult.fromJson(response);
  }

  /// Sends a command and waits for a JSON response via notification.
  ///
  /// Uses the existing notification stream to receive the response.
  /// Throws [TimeoutException] if no response within [_syncCommandTimeout].
  Future<Map<String, dynamic>> _sendCommandAndWaitForResponse(String command) async {
    // Create a completer to wait for the response
    final completer = Completer<Map<String, dynamic>>();
    StreamSubscription<BleMessage>? subscription;

    // Set up timeout
    final timer = Timer(_syncCommandTimeout, () {
      if (!completer.isCompleted) {
        subscription?.cancel();
        completer.completeError(
          TimeoutException('BLE command timed out after ${_syncCommandTimeout.inSeconds} seconds'),
        );
      }
    });

    // Listen for the response on the notification stream
    subscription = _messageController.stream.listen(
      (message) {
        debugPrint('_sendCommandAndWaitForResponse: Received message type=${message.type}, data=${message.data}');
        // Check if this is a sync protocol response (has 'status' field)
        // Sync responses have type syncResponse and data is the full JSON map
        if (message.type == BleMessageType.syncResponse &&
            message.data is Map<String, dynamic> &&
            (message.data as Map<String, dynamic>).containsKey('status')) {
          debugPrint('_sendCommandAndWaitForResponse: Got syncResponse, completing future');
          timer.cancel();
          subscription?.cancel();
          if (!completer.isCompleted) {
            completer.complete(message.data as Map<String, dynamic>);
          }
        }
      },
      onError: (error) {
        timer.cancel();
        subscription?.cancel();
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
    );

    // Send the command
    await _enqueueWrite(() => _writeChunked(_writeChar!, command));

    // Wait for response
    return completer.future;
  }

  /// Converts an Item to the JSON format expected by device for override.
  ///
  /// Fields sent during override (from implementation plan 1.11):
  /// - device_item_id: Item slot ID (0-99)
  /// - name: Item name (max 32 chars)
  /// - category: Category name (max 32 chars)
  /// - count: Total count
  /// - todaycount: Today's count
  /// - increment: Count per press (1-1000)
  /// - reminder: Reminder type
  /// - reminder_value: Reminder threshold
  /// - lastResetTime: Last reset timestamp (UTC seconds)
  /// - reset_number: Reset counter
  Map<String, dynamic> _itemToDeviceJson(Item item, Map<String, String> categoryNames) {
    return {
      'device_item_id': item.deviceItemId ?? 0,
      'name': item.name,
      'category': (item.categoryId == null || item.categoryId!.isEmpty)
          ? 'Uncategorized'
          : (categoryNames[item.categoryId] ?? 'Uncategorized'),
      'count': item.count,
      'todaycount': item.todayCount,
      'increment': item.incrementBy,
      'reminder': _reminderTypeToInt(item.reminder),
      'reminder_value': item.reminderValue,
      'lastResetTime': (item.lastResetTime?.toUtc().millisecondsSinceEpoch ?? 0) ~/ 1000,
      'reset_number': item.resetNumber,
    };
  }

  /// Converts ReminderType enum to ESP32 integer format.
  int _reminderTypeToInt(ReminderType type) {
    switch (type) {
      case ReminderType.none:
        return 0;
      case ReminderType.target:
        return 1;
      case ReminderType.interval:
        return 2;
    }
  }

  // ========== Permissions & Adapter State ==========

  @override
  Future<bool> isBluetoothEnabled() async {
    final state = await FlutterBluePlus.adapterState.first;
    return state == BluetoothAdapterState.on;
  }

  @override
  Stream<bool> watchBluetoothState() {
    return FlutterBluePlus.adapterState.map(
      (state) => state == BluetoothAdapterState.on,
    );
  }

  @override
  Future<bool> requestPermissions() async {
    // Request Bluetooth permissions (Android 12+)
    final bluetoothScan = await Permission.bluetoothScan.request();
    final bluetoothConnect = await Permission.bluetoothConnect.request();

    // Request location permission (required for BLE scanning)
    final location = await Permission.locationWhenInUse.request();

    return bluetoothScan.isGranted &&
           bluetoothConnect.isGranted &&
           location.isGranted;
  }

  // ========== Write Queue ==========

  /// Enqueues a write operation and processes it when ready.
  /// Ensures writes are serialized to prevent interleaved chunks.
  Future<void> _enqueueWrite(Future<void> Function() writeOperation) async {
    final completer = Completer<void>();
    _writeQueue.add(_WriteOperation(writeOperation, completer));

    // Start processing if not already running
    if (!_isProcessingWrite) {
      _processWriteQueue();
    }

    return completer.future;
  }

  /// Processes queued write operations sequentially.
  Future<void> _processWriteQueue() async {
    if (_isProcessingWrite || _writeQueue.isEmpty) return;

    _isProcessingWrite = true;

    while (_writeQueue.isNotEmpty) {
      final operation = _writeQueue.removeAt(0);
      try {
        await operation.execute();
        operation.completer.complete();
      } catch (e) {
        operation.completer.completeError(e);
      }
    }

    _isProcessingWrite = false;
  }

  // ========== Cleanup ==========

  @override
  Future<void> dispose() async {
    _messageTimeoutTimer?.cancel();
    await _notifySubscription?.cancel();
    await _connectionSubscription?.cancel();
    await _messageController.close();
    await _connectionStateController.close();

    // Clear pending write operations
    for (final op in _writeQueue) {
      op.completer.completeError(StateError('Datasource disposed'));
    }
    _writeQueue.clear();

    if (_connectedDevice != null) {
      await _connectedDevice!.disconnect();
    }

    _clearConnectionState();
  }
}

/// Represents a queued write operation.
class _WriteOperation {
  final Future<void> Function() execute;
  final Completer<void> completer;

  _WriteOperation(this.execute, this.completer);
}
