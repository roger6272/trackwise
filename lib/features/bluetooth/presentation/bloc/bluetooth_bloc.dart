import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:injectable/injectable.dart';

import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/bluetooth_constants.dart';
import '../../../auth/domain/repositories/user_repository.dart';
import '../../domain/entities/ble_connection_state.dart';
import '../../domain/entities/ble_device.dart';
import '../../domain/entities/ble_message.dart';
import '../../domain/usecases/check_bluetooth_enabled_usecase.dart';
import '../../domain/usecases/clear_device_logs_usecase.dart';
import '../../domain/usecases/connect_device_usecase.dart';
import '../../domain/usecases/disconnect_device_usecase.dart';
import '../../domain/usecases/request_bluetooth_permissions_usecase.dart';
import '../../domain/usecases/request_device_data_usecase.dart';
import '../../domain/usecases/scan_devices_usecase.dart';
import '../../domain/usecases/send_items_to_device_usecase.dart';
import '../../domain/usecases/send_selected_item_usecase.dart';
import '../../domain/usecases/send_time_sync_usecase.dart';
import '../../domain/usecases/stop_scan_usecase.dart';
import '../../domain/usecases/sync_device_data_usecase.dart';
import '../../domain/usecases/sync_usecase.dart';
import '../../domain/failures/sync_failures.dart';
import '../../domain/usecases/watch_connection_state_usecase.dart';
import '../../domain/usecases/watch_device_messages_usecase.dart';
import '../../domain/repositories/bluetooth_repository.dart';
import 'bluetooth_event.dart';
import 'bluetooth_state.dart';

/// BLoC for managing Bluetooth/BLE operations.
///
/// Handles:
/// - Permission checking and requests
/// - Device scanning
/// - Connection management with auto-reconnect
/// - Data sending/receiving with ESP32
/// - Message stream processing
/// - Multi-device sync and conflict resolution
@lazySingleton
class BluetoothBloc extends Bloc<BluetoothEvent, BluetoothState> {
  final ScanDevicesUseCase _scanDevices;
  final StopScanUseCase _stopScan;
  final ConnectDeviceUseCase _connectDevice;
  final DisconnectDeviceUseCase _disconnectDevice;
  final WatchConnectionStateUseCase _watchConnectionState;
  final WatchDeviceMessagesUseCase _watchMessages;
  final SendItemsToDeviceUseCase _sendItems;
  final SendSelectedItemUseCase _sendSelectedItem;
  final SendTimeSyncUseCase _sendTimeSync;
  final RequestDeviceDataUseCase _requestData;
  final ClearDeviceLogsUseCase _clearLogs;
  final CheckBluetoothEnabledUseCase _checkBluetoothEnabled;
  final RequestBluetoothPermissionsUseCase _requestPermissions;
  final SyncDeviceDataUseCase _syncDeviceData;
  final PerformSyncUseCase _performSync;
  final PerformOverrideUseCase _performOverride;
  final UserRepository _userRepository;
  final BluetoothRepository _bluetoothRepository;

  // Stream subscriptions
  StreamSubscription<dynamic>? _scanSubscription;
  StreamSubscription<dynamic>? _connectionSubscription;
  StreamSubscription<dynamic>? _messageSubscription;
  StreamSubscription<bool>? _bluetoothStateSubscription;

  // Auto-reconnect tracking
  bool _isManualDisconnect = false;
  String? _lastConnectedDeviceId;
  Timer? _reconnectTimer;
  bool _wasBluetoothOff = false;
  int _reconnectAttempts = 0;

  /// Maximum reconnect delay in seconds (caps exponential growth)
  static const int _maxReconnectDelaySeconds = 60;

  /// Calculate reconnect delay with exponential backoff.
  /// Starts at 2 seconds, doubles each attempt, caps at 60 seconds.
  Duration _getReconnectDelay() {
    // 2^attempts * 2 seconds: 2s, 4s, 8s, 16s, 32s, 60s (capped)
    final delaySeconds = (1 << _reconnectAttempts) * 2;
    final cappedDelay =
        delaySeconds > _maxReconnectDelaySeconds ? _maxReconnectDelaySeconds : delaySeconds;
    return Duration(seconds: cappedDelay);
  }

  BluetoothBloc(
    this._scanDevices,
    this._stopScan,
    this._connectDevice,
    this._disconnectDevice,
    this._watchConnectionState,
    this._watchMessages,
    this._sendItems,
    this._sendSelectedItem,
    this._sendTimeSync,
    this._requestData,
    this._clearLogs,
    this._checkBluetoothEnabled,
    this._requestPermissions,
    this._syncDeviceData,
    this._performSync,
    this._performOverride,
    this._userRepository,
    this._bluetoothRepository,
  ) : super(const BluetoothState()) {
    // Register event handlers
    on<CheckBluetoothPermissions>(_onCheckPermissions);
    on<RequestBluetoothPermissions>(_onRequestPermissions);
    on<CheckBluetoothEnabled>(_onCheckBluetoothEnabled);
    on<BluetoothAdapterStateChanged>(_onBluetoothAdapterStateChanged);
    on<StartScan>(_onStartScan);

    // Start watching Bluetooth adapter state
    _startWatchingBluetoothState();
    on<StopScan>(_onStopScan);
    on<ConnectToDevice>(_onConnect);
    on<DisconnectFromDevice>(_onDisconnect);
    on<ConnectionStateChanged>(_onConnectionStateChanged);
    on<SendItemsToDevice>(_onSendItems);
    on<SendSelectedItem>(_onSendSelectedItem);
    on<SendTimeSync>(_onSendTimeSync);
    on<RequestDeviceData>(_onRequestData);
    on<ClearDeviceLogs>(_onClearLogs);
    on<MessageReceived>(_onMessageReceived);
    on<ScanResultsUpdated>(_onScanResultsUpdated);
    on<UpdateSelectedItemFromDevice>(_onUpdateSelectedItemFromDevice);

    // Multi-device events
    on<LoadPairedDevices>(_onLoadPairedDevices);
    on<UpdateDeviceName>(_onUpdateDeviceName);
    on<RemovePairedDevice>(_onRemovePairedDevice);
    on<SyncConflictDetected>(_onSyncConflictDetected);
    on<ConfirmSyncOverride>(_onConfirmSyncOverride);
    on<CancelSyncConflict>(_onCancelSyncConflict);
    on<ClearConflictState>(_onClearConflictState);
    on<SyncCompleted>(_onSyncCompleted);
  }

  // ========== Bluetooth Adapter State ==========

  void _startWatchingBluetoothState() {
    _bluetoothStateSubscription = fbp.FlutterBluePlus.adapterState
        .map((state) => state == fbp.BluetoothAdapterState.on)
        .listen((isEnabled) {
      add(BluetoothAdapterStateChanged(isEnabled));
    });
  }

  void _onBluetoothAdapterStateChanged(
    BluetoothAdapterStateChanged event,
    Emitter<BluetoothState> emit,
  ) {
    if (!event.isEnabled) {
      // Bluetooth turned off
      _wasBluetoothOff = true;
      emit(state.copyWith(
        bluetoothEnabled: false,
        status: BluetoothStatus.bluetoothDisabled,
        clearConnectedDevice: true,
      ));
    } else {
      // Bluetooth turned on
      emit(state.copyWith(
        bluetoothEnabled: true,
        status: BluetoothStatus.ready,
      ));

      // Auto-reconnect if Bluetooth was off and we have a device to reconnect to
      if (_wasBluetoothOff &&
          !_isManualDisconnect &&
          _lastConnectedDeviceId != null) {
        _reconnectTimer?.cancel();
        final delay = _getReconnectDelay();
        if (kDebugMode) print('🔄 Auto-reconnect scheduled in ${delay.inSeconds}s (attempt ${_reconnectAttempts + 1})');
        _reconnectTimer = Timer(delay, () {
          if (!_isManualDisconnect &&
              state.status == BluetoothStatus.ready &&
              !isClosed) {
            _reconnectAttempts++;
            add(ConnectToDevice(_lastConnectedDeviceId!));
          }
        });
      }
      _wasBluetoothOff = false;
    }
  }

  // ========== Permission Handlers ==========

  Future<void> _onCheckPermissions(
    CheckBluetoothPermissions event,
    Emitter<BluetoothState> emit,
  ) async {
    // Don't change status if already connected
    if (state.status != BluetoothStatus.connected) {
      emit(state.copyWith(status: BluetoothStatus.checkingPermissions));
    }

    final result = await _requestPermissions.call(const NoParams());
    result.fold(
      (failure) => emit(state.copyWith(
        status: BluetoothStatus.error,
        errorMessage: failure.message,
      )),
      (granted) {
        if (granted) {
          // Only set to ready if not already connected
          emit(state.copyWith(
            permissionsGranted: true,
            status: state.status == BluetoothStatus.connected
                ? BluetoothStatus.connected
                : BluetoothStatus.ready,
          ));
          // Check if Bluetooth is enabled
          add(const CheckBluetoothEnabled());
        } else {
          emit(state.copyWith(
            permissionsGranted: false,
            status: BluetoothStatus.permissionsDenied,
          ));
        }
      },
    );
  }

  Future<void> _onRequestPermissions(
    RequestBluetoothPermissions event,
    Emitter<BluetoothState> emit,
  ) async {
    emit(state.copyWith(status: BluetoothStatus.checkingPermissions));

    final result = await _requestPermissions.call(const NoParams());
    result.fold(
      (failure) => emit(state.copyWith(
        status: BluetoothStatus.error,
        errorMessage: failure.message,
      )),
      (granted) {
        if (granted) {
          emit(state.copyWith(
            permissionsGranted: true,
            status: BluetoothStatus.ready,
          ));
          add(const CheckBluetoothEnabled());
        } else {
          emit(state.copyWith(
            permissionsGranted: false,
            status: BluetoothStatus.permissionsDenied,
          ));
        }
      },
    );
  }

  Future<void> _onCheckBluetoothEnabled(
    CheckBluetoothEnabled event,
    Emitter<BluetoothState> emit,
  ) async {
    final result = await _checkBluetoothEnabled.call(const NoParams());
    result.fold(
      (failure) => emit(state.copyWith(
        status: BluetoothStatus.error,
        errorMessage: failure.message,
      )),
      (enabled) {
        if (enabled) {
          // Only set to ready if not already connected
          emit(state.copyWith(
            bluetoothEnabled: true,
            status: state.status == BluetoothStatus.connected
                ? BluetoothStatus.connected
                : BluetoothStatus.ready,
          ));
        } else {
          emit(state.copyWith(
            bluetoothEnabled: false,
            status: BluetoothStatus.bluetoothDisabled,
          ));
        }
      },
    );
  }

  // ========== Scan Handlers ==========

  Future<void> _onStartScan(
    StartScan event,
    Emitter<BluetoothState> emit,
  ) async {
    // Cancel any existing scan
    await _scanSubscription?.cancel();

    emit(state.copyWith(
      status: BluetoothStatus.scanning,
      discoveredDevices: [],
    ));

    _scanSubscription = _scanDevices
        .call(ScanDevicesParams(timeout: event.timeout))
        .listen(
      (either) {
        either.fold(
          (failure) => add(const StopScan()),
          (devices) => add(ScanResultsUpdated(devices)),
        );
      },
      onDone: () {
        if (state.status == BluetoothStatus.scanning) {
          add(const StopScan());
        }
      },
      onError: (error) {
        add(const StopScan());
      },
    );
  }

  Future<void> _onStopScan(
    StopScan event,
    Emitter<BluetoothState> emit,
  ) async {
    await _scanSubscription?.cancel();
    _scanSubscription = null;

    await _stopScan.call(const NoParams());

    if (state.status == BluetoothStatus.scanning) {
      emit(state.copyWith(status: BluetoothStatus.ready));
    }
  }

  void _onScanResultsUpdated(
    ScanResultsUpdated event,
    Emitter<BluetoothState> emit,
  ) {
    emit(state.copyWith(
      discoveredDevices: event.devices,
    ));
  }

  // ========== Connection Handlers ==========

  Future<void> _onConnect(
    ConnectToDevice event,
    Emitter<BluetoothState> emit,
  ) async {
    // Cancel any pending reconnect
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    // Stop scanning if active and wait for it to complete
    if (state.isScanning) {
      await _stopScan.call(const NoParams());
      // Cancel the scan subscription to avoid race conditions
      await _scanSubscription?.cancel();
      _scanSubscription = null;
      // Give BLE stack time to settle after stopping scan (prevents error 133)
      await Future.delayed(const Duration(milliseconds: BluetoothConstants.scanStopDelayMs));
    }

    // Guard: Check if Bluetooth is ready
    if (!state.bluetoothEnabled) {
      emit(state.copyWith(
        status: BluetoothStatus.error,
        errorMessage: 'Bluetooth is not enabled',
      ));
      return;
    }

    if (!state.permissionsGranted) {
      emit(state.copyWith(
        status: BluetoothStatus.error,
        errorMessage: 'Bluetooth permissions not granted',
      ));
      return;
    }

    _isManualDisconnect = false;
    _lastConnectedDeviceId = event.deviceId;

    emit(state.copyWith(
      status: BluetoothStatus.connecting,
      connectingDeviceId: event.deviceId,
      clearErrorMessage: true,
    ));

    // Set up connection state watcher
    _connectionSubscription?.cancel();
    _connectionSubscription = _watchConnectionState
        .call(WatchConnectionStateParams(event.deviceId))
        .listen((either) {
      either.fold(
        (failure) {}, // Ignore errors in connection stream
        (connectionState) {
          final isConnected = connectionState == BleConnectionState.connected;
          add(ConnectionStateChanged(
            isConnected: isConnected,
            deviceId: event.deviceId,
          ));
        },
      );
    });

    // Attempt connection
    final result = await _connectDevice.call(
      ConnectDeviceParams(event.deviceId),
    );

    result.fold(
      (failure) {
        emit(state.copyWith(
          status: BluetoothStatus.error,
          errorMessage: failure.message,
          clearConnectingDeviceId: true,
        ));
      },
      (_) {
        // Connection successful - state will be updated by stream
      },
    );
  }

  Future<void> _onDisconnect(
    DisconnectFromDevice event,
    Emitter<BluetoothState> emit,
  ) async {
    _isManualDisconnect = true;

    // Cancel any pending reconnect and reset attempts
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;

    final deviceId = state.connectedDevice?.id ?? state.connectingDeviceId;
    if (deviceId == null) return;

    emit(state.copyWith(status: BluetoothStatus.disconnecting));

    // Don't await these - they can hang if the stream is mid-emission
    _messageSubscription?.cancel();
    _messageSubscription = null;

    _connectionSubscription?.cancel();
    _connectionSubscription = null;

    final result = await _disconnectDevice.call(
      DisconnectDeviceParams(deviceId),
    );

    result.fold(
      (failure) => emit(state.copyWith(
        status: BluetoothStatus.error,
        errorMessage: failure.message,
      )),
      (_) => emit(state.copyWith(
        status: BluetoothStatus.ready,
        clearConnectedDevice: true,
        clearConnectingDeviceId: true,
      )),
    );
  }

  void _onConnectionStateChanged(
    ConnectionStateChanged event,
    Emitter<BluetoothState> emit,
  ) {
    if (event.isConnected) {
      // Reset reconnect attempts on successful connection
      _reconnectAttempts = 0;

      // Find device in discovered list or create from ID
      final device = state.discoveredDevices.firstWhere(
        (d) => d.id == event.deviceId,
        orElse: () => BleDevice(
          id: event.deviceId!,
          name: 'Unknown Device',
          rssi: 0,
        ),
      );

      emit(state.copyWith(
        status: BluetoothStatus.connected,
        connectedDevice: device,
        clearConnectingDeviceId: true,
      ));

      // Start listening to messages
      _subscribeToMessages(event.deviceId!);

      // Perform initial sync
      _performInitialSync();
    } else {
      // Disconnected
      emit(state.copyWith(
        status: BluetoothStatus.ready,
        clearConnectedDevice: true,
        clearConnectingDeviceId: true,
      ));

      // Auto-reconnect if not manual disconnect (with exponential backoff)
      if (!_isManualDisconnect && _lastConnectedDeviceId != null) {
        _reconnectTimer?.cancel();
        final delay = _getReconnectDelay();
        if (kDebugMode) print('🔄 Auto-reconnect scheduled in ${delay.inSeconds}s (attempt ${_reconnectAttempts + 1})');
        _reconnectTimer = Timer(delay, () {
          if (!_isManualDisconnect &&
              state.status == BluetoothStatus.ready &&
              !isClosed) {
            _reconnectAttempts++;
            add(ConnectToDevice(_lastConnectedDeviceId!));
          }
        });
      }
    }
  }

  void _subscribeToMessages(String deviceId) {
    _messageSubscription?.cancel();
    _messageSubscription = _watchMessages
        .call(WatchDeviceMessagesParams(deviceId))
        .listen((either) {
      either.fold(
        (failure) {}, // Ignore errors in message stream
        (message) => add(MessageReceived(message)),
      );
    });
  }

  Future<void> _performInitialSync() async {
    final deviceId = state.connectedDevice?.id;
    if (deviceId == null) return;

    // Small delay to let BLE connection stabilize
    await Future.delayed(const Duration(milliseconds: BluetoothConstants.connectionStabilizeDelayMs));

    // Send time sync first and await it
    final timeSyncResult = await _sendTimeSync.call(SendTimeSyncParams(deviceId));
    timeSyncResult.fold(
      (failure) { if (kDebugMode) print('Time sync failed: ${failure.message}'); },
      (_) { if (kDebugMode) print('Initial sync: time sync sent'); },
    );

    // Small delay between commands to avoid overwhelming BLE
    await Future.delayed(const Duration(milliseconds: BluetoothConstants.commandIntervalDelayMs));

    // Perform the new handshake-based sync flow
    if (kDebugMode) print('Initial sync: starting handshake flow');

    final syncResult = await _performSync.call(
      PerformSyncParams(deviceId: deviceId),
    );

    syncResult.fold(
      (failure) {
        if (failure is SyncConflictFailure) {
          // Conflict detected - notify UI to show dialog
          if (kDebugMode) print('Sync conflict detected: app=${failure.appSyncSeq}, device=${failure.deviceSyncSeq}, deviceInstanceId=${failure.deviceInstanceId}');
          add(SyncConflictDetected(
            appSyncSeq: failure.appSyncSeq,
            deviceSyncSeq: failure.deviceSyncSeq,
            deviceInstanceId: failure.deviceInstanceId,
          ));
        } else if (failure is WrongAccountFailure) {
          if (kDebugMode) print('Wrong account - device locked to different user');
          // TODO: Show wrong account dialog
        } else if (failure is NoInternetFailure) {
          if (kDebugMode) print('No internet - falling back to old sync flow');
          // Fall back to old sync flow when offline
          _performLegacySync(deviceId);
        } else {
          if (kDebugMode) print('Sync failed: ${failure.message}');
        }
      },
      (result) {
        if (kDebugMode) print('Sync completed successfully, deviceInstanceId=${result.deviceInstanceId}');
        // Use event to update state (emit not available outside event handlers)
        add(SyncCompleted(deviceInstanceId: result.deviceInstanceId));
      },
    );
  }

  /// Legacy sync flow for offline mode (no internet).
  /// Uses prepare_read to get prefs/logs from device.
  Future<void> _performLegacySync(String deviceId) async {
    // Request prefs from device (item counts, selected item)
    final prefsResult = await _requestData.call(
      RequestDeviceDataParams(
        deviceId: deviceId,
        type: DeviceDataType.prefs,
        page: 0,
      ),
    );

    prefsResult.fold(
      (failure) { if (kDebugMode) print('Failed to request prefs: ${failure.message}'); },
      (_) { if (kDebugMode) print('Legacy sync: prefs requested'); },
    );

    // Small delay before requesting logs
    await Future.delayed(const Duration(milliseconds: BluetoothConstants.commandIntervalDelayMs));

    // Request logs from device (event history)
    final logsResult = await _requestData.call(
      RequestDeviceDataParams(
        deviceId: deviceId,
        type: DeviceDataType.logs,
        page: 0,
      ),
    );

    logsResult.fold(
      (failure) { if (kDebugMode) print('Failed to request logs: ${failure.message}'); },
      (_) { if (kDebugMode) print('Legacy sync: logs requested'); },
    );
  }

  // ========== Data Handlers ==========

  Future<void> _onSendItems(
    SendItemsToDevice event,
    Emitter<BluetoothState> emit,
  ) async {
    final deviceId = state.connectedDevice?.id;
    if (deviceId == null) return;

    final result = await _sendItems.call(
      SendItemsParams(
        deviceId: deviceId,
        items: event.items,
        categoryNames: event.categoryNames,
      ),
    );

    result.fold(
      (failure) => emit(state.copyWith(
        status: BluetoothStatus.error,
        errorMessage: failure.message,
      )),
      (_) {},
    );
  }

  Future<void> _onSendSelectedItem(
    SendSelectedItem event,
    Emitter<BluetoothState> emit,
  ) async {
    final deviceId = state.connectedDevice?.id;
    if (deviceId == null) return;

    // Optimistic update: update UI immediately before device responds
    emit(state.copyWith(selectedItemId: event.itemId));

    final result = await _sendSelectedItem.call(
      SendSelectedItemParams(
        deviceId: deviceId,
        itemId: event.itemId,
        deviceItemId: event.deviceItemId,
      ),
    );

    result.fold(
      (failure) => emit(state.copyWith(
        status: BluetoothStatus.error,
        errorMessage: failure.message,
      )),
      (_) {},
    );
  }

  Future<void> _onSendTimeSync(
    SendTimeSync event,
    Emitter<BluetoothState> emit,
  ) async {
    final deviceId = state.connectedDevice?.id;
    if (deviceId == null) return;

    final result = await _sendTimeSync.call(
      SendTimeSyncParams(deviceId),
    );

    result.fold(
      (failure) {}, // Silently ignore time sync failures
      (_) {},
    );
  }

  Future<void> _onRequestData(
    RequestDeviceData event,
    Emitter<BluetoothState> emit,
  ) async {
    final deviceId = state.connectedDevice?.id;
    if (deviceId == null) return;

    final result = await _requestData.call(
      RequestDeviceDataParams(
        deviceId: deviceId,
        type: event.type,
        page: event.page,
      ),
    );

    result.fold(
      (failure) => emit(state.copyWith(
        status: BluetoothStatus.error,
        errorMessage: failure.message,
      )),
      (_) {
        // Command sent successfully
        // Response will arrive via notifications (MessageReceived event)
      },
    );
  }

  Future<void> _onClearLogs(
    ClearDeviceLogs event,
    Emitter<BluetoothState> emit,
  ) async {
    final deviceId = state.connectedDevice?.id;
    if (deviceId == null) return;

    final result = await _clearLogs.call(
      ClearDeviceLogsParams(deviceId),
    );

    result.fold(
      (failure) => emit(state.copyWith(
        status: BluetoothStatus.error,
        errorMessage: failure.message,
      )),
      (_) {},
    );
  }

  // ========== Message Handlers ==========

  Future<void> _onMessageReceived(
    MessageReceived event,
    Emitter<BluetoothState> emit,
  ) async {
    final message = event.message;

    // Initial state update (selectedItemId will be updated after sync)
    emit(state.copyWith(
      lastMessage: message,
      hasMoreLogs: message.hasMore,
    ));

    // Sync device data to Firestore
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (userId.isNotEmpty) {
      final result = await _syncDeviceData.call(SyncDeviceDataParams(
        message: message,
        userId: userId,
      ));

      // Update selectedItemId if sync returned a mapped Firestore ID
      // or clear it if device explicitly says no selection
      result.fold(
        (failure) {
          // Log sync failure but don't fail the message handling
          debugPrint('Sync failed: ${failure.message}');
        },
        (syncResult) {
          if (syncResult.selectedFirestoreId != null) {
            emit(state.copyWith(selectedItemId: syncResult.selectedFirestoreId));
          } else if (syncResult.clearSelection) {
            // Device explicitly said no item selected - clear app's selection
            emit(state.copyWith(clearSelectedItemId: true));
          }
        },
      );
    }

    // Handle log pagination - if more pages available, request them
    if (message.type == BleMessageType.logs && message.hasMore) {
      final deviceId = state.connectedDevice?.id;
      if (deviceId != null) {
        final currentPage = message.page ?? 0;
        await Future.delayed(const Duration(milliseconds: BluetoothConstants.commandIntervalDelayMs));
        add(RequestDeviceData(type: DeviceDataType.logs, page: currentPage + 1));
      }
    }

    // Clear logs on device when all pages received
    if (message.type == BleMessageType.logs && !message.hasMore) {
      add(const ClearDeviceLogs());
    }
  }

  /// Updates selected item ID from device prefs during initial sync.
  Future<void> _onUpdateSelectedItemFromDevice(
    UpdateSelectedItemFromDevice event,
    Emitter<BluetoothState> emit,
  ) async {
    emit(state.copyWith(selectedItemId: event.itemId));
  }

  // ========== Paired Device Handlers ==========

  /// Loads paired devices from the user repository.
  Future<void> _onLoadPairedDevices(
    LoadPairedDevices event,
    Emitter<BluetoothState> emit,
  ) async {
    final result = await _userRepository.getCurrentUser();
    result.fold(
      (failure) {
        if (kDebugMode) print('Failed to load paired devices: ${failure.message}');
      },
      (user) {
        emit(state.copyWith(pairedDevices: user.pairedDevices));
      },
    );
  }

  /// Updates a paired device's name.
  Future<void> _onUpdateDeviceName(
    UpdateDeviceName event,
    Emitter<BluetoothState> emit,
  ) async {
    final result = await _userRepository.updateDeviceName(
      event.deviceInstanceId,
      event.newName,
    );

    result.fold(
      (failure) {
        if (kDebugMode) print('Failed to update device name: ${failure.message}');
      },
      (_) {
        // Update local state
        final updatedDevices = state.pairedDevices.map((device) {
          if (device.deviceInstanceId == event.deviceInstanceId) {
            return device.copyWith(deviceName: event.newName);
          }
          return device;
        }).toList();

        emit(state.copyWith(pairedDevices: updatedDevices));
      },
    );
  }

  /// Removes a paired device from the user's list.
  /// If the device is currently connected, disconnects first.
  Future<void> _onRemovePairedDevice(
    RemovePairedDevice event,
    Emitter<BluetoothState> emit,
  ) async {
    // Check if the device being unpaired is the currently connected device
    final isConnectedDevice = state.connectedDeviceInstanceId == event.deviceInstanceId;

    // Disconnect first if this is the connected device
    if (isConnectedDevice && state.connectedDevice != null) {
      if (kDebugMode) print('Disconnecting from device being unpaired');
      _isManualDisconnect = true;
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      _reconnectAttempts = 0;

      await _bluetoothRepository.disconnect(state.connectedDevice!.id);
    }

    final result = await _userRepository.removePairedDevice(event.deviceInstanceId);

    result.fold(
      (failure) {
        if (kDebugMode) print('Failed to remove paired device: ${failure.message}');
      },
      (_) {
        // Update local state
        final updatedDevices = state.pairedDevices
            .where((d) => d.deviceInstanceId != event.deviceInstanceId)
            .toList();

        if (isConnectedDevice) {
          // Also clear connected state
          emit(state.copyWith(
            pairedDevices: updatedDevices,
            status: BluetoothStatus.ready,
            clearConnectedDevice: true,
            clearConnectedDeviceInstanceId: true,
          ));
        } else {
          emit(state.copyWith(pairedDevices: updatedDevices));
        }
      },
    );
  }

  // ========== Sync Conflict Handlers ==========

  /// Handles sync conflict detection - UI should show the dialog.
  Future<void> _onSyncConflictDetected(
    SyncConflictDetected event,
    Emitter<BluetoothState> emit,
  ) async {
    if (kDebugMode) print('BluetoothBloc: Setting hasConflict=true, deviceInstanceId=${event.deviceInstanceId}');
    emit(state.copyWith(
      hasConflict: true,
      conflictAppSyncSeq: event.appSyncSeq,
      conflictDeviceSyncSeq: event.deviceSyncSeq,
      conflictDeviceInstanceId: event.deviceInstanceId,
    ));
  }

  /// User confirmed override - perform the override sync.
  Future<void> _onConfirmSyncOverride(
    ConfirmSyncOverride event,
    Emitter<BluetoothState> emit,
  ) async {
    final deviceId = state.connectedDevice?.id;
    if (deviceId == null) {
      emit(state.copyWith(
        clearConflict: true,
        errorMessage: 'No device connected',
      ));
      return;
    }

    emit(state.copyWith(
      isOverriding: true,
      clearConflict: true,
    ));

    final result = await _performOverride.call(
      PerformOverrideParams(deviceId: deviceId),
    );

    result.fold(
      (failure) {
        emit(state.copyWith(
          isOverriding: false,
          errorMessage: failure.message,
        ));
      },
      (syncResult) {
        emit(state.copyWith(
          isOverriding: false,
          selectedItemId: syncResult.selectedFirestoreId,
        ));

        if (kDebugMode) print('Override completed successfully');
      },
    );
  }

  /// User cancelled conflict dialog - disconnect from device.
  Future<void> _onCancelSyncConflict(
    CancelSyncConflict event,
    Emitter<BluetoothState> emit,
  ) async {
    emit(state.copyWith(clearConflict: true));

    // Disconnect from device
    final deviceId = state.connectedDevice?.id;
    if (deviceId != null) {
      _isManualDisconnect = true;
      await _bluetoothRepository.disconnect(deviceId);
      emit(state.copyWith(
        status: BluetoothStatus.ready,
        clearConnectedDevice: true,
        clearConnectedDeviceInstanceId: true,
      ));
    }
  }

  /// Clears conflict state after it's been handled.
  Future<void> _onClearConflictState(
    ClearConflictState event,
    Emitter<BluetoothState> emit,
  ) async {
    emit(state.copyWith(clearConflict: true));
  }

  /// Handles successful sync completion.
  Future<void> _onSyncCompleted(
    SyncCompleted event,
    Emitter<BluetoothState> emit,
  ) async {
    emit(state.copyWith(connectedDeviceInstanceId: event.deviceInstanceId));
    // Reload paired devices to update UI
    add(const LoadPairedDevices());
  }

  // ========== Cleanup ==========

  @override
  Future<void> close() async {
    _reconnectTimer?.cancel();
    await _scanSubscription?.cancel();
    await _connectionSubscription?.cancel();
    await _messageSubscription?.cancel();
    await _bluetoothStateSubscription?.cancel();
    return super.close();
  }
}
