import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:injectable/injectable.dart';

import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/bluetooth_constants.dart';
import '../../../../core/utils/logger.dart';
import '../../../auth/domain/repositories/user_repository.dart';
import '../../../items/domain/repositories/item_repository.dart';
import '../../domain/entities/ble_connection_state.dart';
import '../../domain/entities/ble_device.dart';
import '../../domain/entities/paired_device.dart';
import '../../domain/entities/ble_message.dart';
import '../../domain/usecases/check_bluetooth_enabled_usecase.dart';
import '../../domain/usecases/clear_device_logs_usecase.dart';
import '../../domain/usecases/unpair_device_usecase.dart';
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
import '../../domain/usecases/refresh_device_items_usecase.dart';
import '../../domain/usecases/sync_usecase.dart';
import '../../domain/failures/sync_failures.dart';
import '../../domain/usecases/watch_connection_state_usecase.dart';
import '../../domain/usecases/watch_device_messages_usecase.dart';
import '../../domain/repositories/bluetooth_repository.dart';
import 'bluetooth_event.dart';
import 'bluetooth_state.dart';
import 'device_connection_state.dart';

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
  final UnpairDeviceUseCase _unpairDevice;
  final CheckBluetoothEnabledUseCase _checkBluetoothEnabled;
  final RequestBluetoothPermissionsUseCase _requestPermissions;
  final SyncDeviceDataUseCase _syncDeviceData;
  final PerformSyncUseCase _performSync;
  final PerformOverrideUseCase _performOverride;
  final RefreshDeviceItemsUseCase _refreshDeviceItems;
  final UserRepository _userRepository;
  final BluetoothRepository _bluetoothRepository;
  final ItemRepository _itemRepository;

  // Stream subscriptions
  StreamSubscription<dynamic>? _scanSubscription;
  final Map<String, StreamSubscription<dynamic>> _connectionSubscriptions = {};
  final Map<String, StreamSubscription<dynamic>> _messageSubscriptions = {};
  StreamSubscription<bool>? _bluetoothStateSubscription;

  // Auto-reconnect tracking (per-device)
  final Set<String> _manualDisconnects = {};
  final Set<String> _devicesToReconnect = {};
  final Map<String, Timer> _reconnectTimers = {};
  bool _wasBluetoothOff = false; // Keep global — adapter state is global
  final Map<String, int> _reconnectAttempts = {};

  // Per-device claim queue: serializes fire-and-forget atomicClaimSwap calls
  // so they execute in order, preventing stale-release race conditions.
  final Map<String, Future<void>> _claimQueues = {};

  // Per-device category cache: used to skip cross-category pushes.
  final Map<String, String> _deviceCategories = {};

  /// Maximum reconnect delay in seconds (caps exponential growth)
  static const int _maxReconnectDelaySeconds = 60;

  /// Calculate reconnect delay with exponential backoff.
  /// Starts at 2 seconds, doubles each attempt, caps at 60 seconds.
  Duration _getReconnectDelay(String deviceInstanceId) {
    // 2^attempts * 2 seconds: 2s, 4s, 8s, 16s, 32s, 60s (capped)
    final attempts = _reconnectAttempts[deviceInstanceId] ?? 0;
    final delaySeconds = (1 << attempts) * 2;
    final cappedDelay =
        delaySeconds > _maxReconnectDelaySeconds ? _maxReconnectDelaySeconds : delaySeconds;
    return Duration(seconds: cappedDelay);
  }

  // ========== Helper Methods ==========

  /// Returns an updated connectedDevices map with the given device modified.
  /// Returns the current map unchanged if the device is not found.
  Map<String, DeviceConnectionState> _updateDevice(
    String deviceInstanceId,
    DeviceConnectionState Function(DeviceConnectionState) update,
  ) {
    final current = state.connectedDevices[deviceInstanceId];
    if (current == null) return state.connectedDevices;
    return {...state.connectedDevices, deviceInstanceId: update(current)};
  }

  /// Returns an updated connectedDevices map with the given device removed.
  Map<String, DeviceConnectionState> _removeDevice(String deviceInstanceId) {
    return Map.of(state.connectedDevices)..remove(deviceInstanceId);
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
    this._unpairDevice,
    this._checkBluetoothEnabled,
    this._requestPermissions,
    this._syncDeviceData,
    this._performSync,
    this._performOverride,
    this._refreshDeviceItems,
    this._userRepository,
    this._bluetoothRepository,
    this._itemRepository,
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
    on<UnpairDevice>(_onUnpairDevice);
    on<MessageReceived>(_onMessageReceived);
    on<ScanResultsUpdated>(_onScanResultsUpdated);
    on<UpdateSelectedItemFromDevice>(_onUpdateSelectedItemFromDevice);

    // Multi-device events
    on<LoadPairedDevices>(_onLoadPairedDevices);
    on<UpdateDeviceName>(_onUpdateDeviceName);
    on<UpdateDeviceColor>(_onUpdateDeviceColor);
    on<RemovePairedDevice>(_onRemovePairedDevice);
    on<SyncConflictDetected>(_onSyncConflictDetected);
    on<ConfirmSyncOverride>(_onConfirmSyncOverride);
    on<CancelSyncConflict>(_onCancelSyncConflict);
    on<ClearConflictState>(_onClearConflictState);
    on<SyncCompleted>(_onSyncCompleted);
    // Device setup events (uninitialized/factory reset)
    on<DeviceSetupRequired>(_onDeviceSetupRequired);
    on<ConfirmDeviceSetup>(_onConfirmDeviceSetup);
    on<CancelDeviceSetup>(_onCancelDeviceSetup);
    on<ClearSetupState>(_onClearSetupState);
    // Wrong account events
    on<WrongAccountDetected>(_onWrongAccountDetected);
    on<DismissWrongAccount>(_onDismissWrongAccount);
    // Handshake completed event (stub for Task 10)
    on<HandshakeCompleted>(_onHandshakeCompleted);
    // Claim events (stub handlers, implemented in Task 13)
    on<ClaimItem>(_onClaimItem);
    on<ReleaseItem>(_onReleaseItem);
    on<RefreshAllDevices>(_onRefreshAllDevices);
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
        connectedDevices: const {},
      ));
    } else {
      // Bluetooth turned on
      emit(state.copyWith(
        bluetoothEnabled: true,
        status: BluetoothStatus.ready,
      ));

      // Auto-reconnect for all non-manually-disconnected devices when BT comes back on
      if (_wasBluetoothOff) {
        for (final deviceId in _devicesToReconnect.toList()) {
          if (!_manualDisconnects.contains(deviceId)) {
            _reconnectTimers[deviceId]?.cancel();
            final delay = _getReconnectDelay(deviceId);
            AppLogger.debug('🔄 Auto-reconnect for $deviceId scheduled in ${delay.inSeconds}s (BT re-enabled)');
            _reconnectTimers[deviceId] = Timer(delay, () {
              if (!_manualDisconnects.contains(deviceId) &&
                  state.status == BluetoothStatus.ready &&
                  !isClosed) {
                _reconnectAttempts[deviceId] = (_reconnectAttempts[deviceId] ?? 0) + 1;
                add(ConnectToDevice(deviceId));
              }
            });
          }
        }
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
    if (!state.isConnected) {
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
            status: state.isConnected ? null : BluetoothStatus.ready,
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
            status: state.isConnected ? null : BluetoothStatus.ready,
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
    // Cancel any pending reconnect for this device
    _reconnectTimers[event.deviceId]?.cancel();
    _reconnectTimers.remove(event.deviceId);

    // Stop scanning if active and wait for it to complete
    if (state.isScanning) {
      await _stopScan.call(const NoParams());
      // Cancel the scan subscription to avoid race conditions
      await _scanSubscription?.cancel();
      _scanSubscription = null;
      // Give BLE stack time to settle after stopping scan (prevents error 133)
      await Future.delayed(const Duration(milliseconds: BluetoothConstants.scanStopDelayMs));
    }

    // Guard: Ensure permissions and adapter state are up-to-date
    // (may not have been checked yet if user navigated directly to pairing page)
    if (!state.permissionsGranted) {
      final permResult = await _requestPermissions.call(const NoParams());
      final granted = permResult.fold((_) => false, (v) => v);
      emit(state.copyWith(permissionsGranted: granted));
      if (!granted) {
        emit(state.copyWith(
          status: BluetoothStatus.error,
          errorMessage: 'Bluetooth permissions not granted',
        ));
        return;
      }
    }

    if (!state.bluetoothEnabled) {
      final btResult = await _checkBluetoothEnabled.call(const NoParams());
      final enabled = btResult.fold((_) => false, (v) => v);
      emit(state.copyWith(bluetoothEnabled: enabled));
      if (!enabled) {
        emit(state.copyWith(
          status: BluetoothStatus.error,
          errorMessage: 'Bluetooth is not enabled',
        ));
        return;
      }
    }

    _manualDisconnects.remove(event.deviceId);

    emit(state.copyWith(
      status: BluetoothStatus.connecting,
      connectingDeviceId: event.deviceId,
      clearErrorMessage: true,
    ));

    // Set up connection state watcher
    _connectionSubscriptions[event.deviceId]?.cancel();
    _connectionSubscriptions[event.deviceId] = _watchConnectionState
        .call(WatchConnectionStateParams(event.deviceId))
        .listen((either) {
      either.fold(
        (failure) {}, // Ignore errors in connection stream
        (connectionState) {
          final isConnected = connectionState == BleConnectionState.connected;
          add(ConnectionStateChanged(
            isConnected: isConnected,
            deviceInstanceId: event.deviceId,
          ));
        },
      );
    });

    // Attempt connection with retry for Android error 133
    const maxRetries = 3;
    const retryDelay = Duration(milliseconds: 500);

    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      final result = await _connectDevice.call(
        ConnectDeviceParams(event.deviceId),
      );

      final shouldRetry = result.fold(
        (failure) {
          // Check if this is Android GATT error 133 (common intermittent failure)
          final isError133 = failure.message.contains('133') ||
              failure.message.contains('ANDROID_SPECIFIC_ERROR');

          if (isError133 && attempt < maxRetries) {
            AppLogger.debug('Connection failed with error 133, retrying ($attempt/$maxRetries)...');
            return true; // Retry
          }

          // Final attempt failed or non-retryable error
          emit(state.copyWith(
            status: BluetoothStatus.error,
            errorMessage: failure.message,
            clearConnectingDeviceId: true,
          ));
          return false; // Don't retry
        },
        (_) {
          // Connection successful - state will be updated by stream
          return false; // Don't retry
        },
      );

      if (!shouldRetry) break;

      // Wait before retrying
      await Future.delayed(retryDelay);
    }
  }

  Future<void> _onDisconnect(
    DisconnectFromDevice event,
    Emitter<BluetoothState> emit,
  ) async {
    final deviceId = event.deviceInstanceId.isNotEmpty
        ? event.deviceInstanceId
        : state.connectedDevice?.id ?? state.connectingDeviceId;
    if (deviceId == null || deviceId.isEmpty) return;

    _manualDisconnects.add(deviceId);
    _devicesToReconnect.remove(deviceId);

    // Cancel any pending reconnect and reset attempts
    _reconnectTimers[deviceId]?.cancel();
    _reconnectTimers.remove(deviceId);
    _reconnectAttempts.remove(deviceId);
    _claimQueues.remove(deviceId);
    _deviceCategories.remove(deviceId);

    // Don't await these - they can hang if the stream is mid-emission
    _messageSubscriptions[deviceId]?.cancel();
    _messageSubscriptions.remove(deviceId);

    _connectionSubscriptions[deviceId]?.cancel();
    _connectionSubscriptions.remove(deviceId);

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
        connectedDevices: _removeDevice(deviceId),
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
      _reconnectAttempts.remove(event.deviceInstanceId);
      _devicesToReconnect.remove(event.deviceInstanceId);

      // Find device in discovered list, paired devices, or create from ID
      final device = state.discoveredDevices.firstWhere(
        (d) => d.id == event.deviceInstanceId,
        orElse: () {
          // Check paired devices for a friendly name
          final paired = state.pairedDevices.cast<PairedDevice?>().firstWhere(
            (d) => d!.deviceInstanceId == event.deviceInstanceId,
            orElse: () => null,
          );
          return BleDevice(
            id: event.deviceInstanceId,
            name: paired?.deviceName ?? 'Traxelos Device',
            rssi: 0,
          );
        },
      );

      emit(state.copyWith(
        status: BluetoothStatus.ready,
        connectedDevices: {
          ...state.connectedDevices,
          event.deviceInstanceId: DeviceConnectionState(
            device: device,
            syncStatus: DeviceSyncStatus.handshaking,
          ),
        },
        clearConnectingDeviceId: true,
      ));

      // Start listening to messages
      _subscribeToMessages(event.deviceInstanceId);

      // Perform initial sync
      _performInitialSync(event.deviceInstanceId);
    } else {
      // Disconnected
      final deviceId = event.deviceInstanceId;
      emit(state.copyWith(
        status: state.connectedDevices.length <= 1 ? BluetoothStatus.ready : null,
        connectedDevices: _removeDevice(deviceId),
        clearConnectingDeviceId: true,
      ));

      // Auto-reconnect if not manual disconnect (with exponential backoff)
      final disconnectedId = event.deviceInstanceId;
      if (!_manualDisconnects.contains(disconnectedId)) {
        _devicesToReconnect.add(disconnectedId);
        _reconnectTimers[disconnectedId]?.cancel();
        final delay = _getReconnectDelay(disconnectedId);
        AppLogger.debug('🔄 Auto-reconnect for $disconnectedId scheduled in ${delay.inSeconds}s (attempt ${(_reconnectAttempts[disconnectedId] ?? 0) + 1})');
        _reconnectTimers[disconnectedId] = Timer(delay, () {
          if (!_manualDisconnects.contains(disconnectedId) &&
              state.status == BluetoothStatus.ready &&
              !isClosed) {
            _reconnectAttempts[disconnectedId] = (_reconnectAttempts[disconnectedId] ?? 0) + 1;
            add(ConnectToDevice(disconnectedId));
          }
        });
      }
    }
  }

  void _subscribeToMessages(String deviceInstanceId) {
    _messageSubscriptions[deviceInstanceId]?.cancel();
    _messageSubscriptions[deviceInstanceId] = _watchMessages
        .call(WatchDeviceMessagesParams(deviceInstanceId))
        .listen((either) {
      either.fold(
        (failure) {}, // Ignore errors in message stream
        (message) => add(MessageReceived(message, deviceInstanceId: deviceInstanceId)),
      );
    });
  }

  Future<void> _performInitialSync(String deviceInstanceId) async {
    // Small delay to let BLE connection stabilize
    await Future.delayed(const Duration(milliseconds: BluetoothConstants.connectionStabilizeDelayMs));

    // Send time sync first and await it
    final timeSyncResult = await _sendTimeSync.call(SendTimeSyncParams(deviceInstanceId));
    timeSyncResult.fold(
      (failure) { AppLogger.debug('Time sync failed: ${failure.message}'); },
      (_) { AppLogger.debug('Initial sync: time sync sent'); },
    );

    // Small delay between commands to avoid overwhelming BLE
    await Future.delayed(const Duration(milliseconds: BluetoothConstants.commandIntervalDelayMs));

    // Perform the new handshake-based sync flow
    AppLogger.debug('Initial sync: starting handshake flow');

    final syncResult = await _performSync.call(
      PerformSyncParams(deviceId: deviceInstanceId),
    );

    syncResult.fold(
      (failure) {
        if (failure is SyncConflictFailure) {
          final conflictDeviceId = failure.deviceInstanceId ?? deviceInstanceId;
          final isAlreadyPaired = state.pairedDevices.any(
            (d) => d.deviceInstanceId.toUpperCase() == conflictDeviceId.toUpperCase(),
          );
          if (isAlreadyPaired) {
            // Already-paired device with stale sync_seq — auto-override silently
            AppLogger.debug('Sync conflict for paired device $conflictDeviceId — auto-overriding');
            add(ConfirmSyncOverride(
              deviceInstanceId: conflictDeviceId,
            ));
          } else {
            // New device or genuinely dangerous conflict — show dialog
            AppLogger.debug('Sync conflict detected: app=${failure.appSyncSeq}, device=${failure.deviceSyncSeq}, deviceInstanceId=$conflictDeviceId');
            add(SyncConflictDetected(
              appSyncSeq: failure.appSyncSeq,
              deviceSyncSeq: failure.deviceSyncSeq,
              deviceInstanceId: conflictDeviceId,
            ));
          }
        } else if (failure is DeviceUninitializedFailure) {
          // Device needs setup (factory reset or new device)
          AppLogger.debug('Device uninitialized: deviceInstanceId=${failure.deviceInstanceId}');
          add(DeviceSetupRequired(deviceInstanceId: failure.deviceInstanceId));
        } else if (failure is WrongAccountFailure) {
          AppLogger.debug('Wrong account - device locked to different user');
          add(const WrongAccountDetected());
        } else if (failure is NoInternetFailure) {
          AppLogger.debug('No internet - falling back to old sync flow');
          // Fall back to old sync flow when offline
          _performLegacySync(deviceInstanceId);
        } else {
          AppLogger.debug('Sync failed: ${failure.message}, falling back to legacy sync');
          _performLegacySync(deviceInstanceId);
        }
      },
      (result) {
        AppLogger.debug('Sync completed successfully, deviceInstanceId=$deviceInstanceId');
        // Use event to update state (emit not available outside event handlers)
        add(HandshakeCompleted(deviceInstanceId: deviceInstanceId, result: result));
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
      (failure) { AppLogger.debug('Failed to request prefs: ${failure.message}'); },
      (_) { AppLogger.debug('Legacy sync: prefs requested'); },
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
      (failure) { AppLogger.debug('Failed to request logs: ${failure.message}'); },
      (_) { AppLogger.debug('Legacy sync: logs requested'); },
    );
  }

  // ========== Data Handlers ==========

  Future<void> _onSendItems(
    SendItemsToDevice event,
    Emitter<BluetoothState> emit,
  ) async {
    final deviceId = event.deviceInstanceId;
    if (deviceId.isEmpty) return;

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
    final deviceId = event.deviceInstanceId;
    if (deviceId.isEmpty) return;

    // Optimistic update: update UI immediately before device responds
    emit(state.copyWith(
      connectedDevices: _updateDevice(
        deviceId,
        (d) => d.copyWith(selectedItemId: event.itemId),
      ),
    ));

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
    // Use target device if specified, fall back to first connected (single-device compat)
    final deviceId = event.deviceInstanceId != null
        ? state.connectedDevices[event.deviceInstanceId]?.device.id
        : state.connectedDevice?.id;
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
    // Use target device if specified, fall back to first connected (single-device compat)
    final deviceId = event.deviceInstanceId != null
        ? state.connectedDevices[event.deviceInstanceId]?.device.id
        : state.connectedDevice?.id;
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
    // Use target device if specified, fall back to first connected (single-device compat)
    final deviceId = event.deviceInstanceId != null
        ? state.connectedDevices[event.deviceInstanceId]?.device.id
        : state.connectedDevice?.id;
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

  Future<void> _onUnpairDevice(
    UnpairDevice event,
    Emitter<BluetoothState> emit,
  ) async {
    // Use target device if specified, fall back to first connected (single-device compat)
    final deviceId = event.deviceInstanceId != null
        ? state.connectedDevices[event.deviceInstanceId]?.device.id
        : state.connectedDevice?.id;
    if (deviceId == null) return;

    final result = await _unpairDevice.call(
      UnpairDeviceParams(deviceId),
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
    final deviceInstanceId = event.deviceInstanceId;

    // Update device state: clear isSyncing when prefs arrive, update hasMoreLogs
    final isSyncingUpdate = message.type == BleMessageType.prefs
        ? DeviceSyncStatus.synced
        : null;
    emit(state.copyWith(
      connectedDevices: _updateDevice(deviceInstanceId, (d) => d.copyWith(
        hasMoreLogs: message.hasMore,
        syncStatus: isSyncingUpdate,
      )),
    ));

    // Sync device data to Firestore
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (userId.isNotEmpty) {
      final result = await _syncDeviceData.call(SyncDeviceDataParams(
        message: message,
        userId: userId,
        deviceInstanceId: deviceInstanceId,
      ));

      // Update selectedItemId if sync returned a mapped Firestore ID
      // or clear it if device explicitly says no selection
      result.fold(
        (failure) {
          // Log sync failure but don't fail the message handling
          AppLogger.debug('Sync failed: ${failure.message}');
        },
        (syncResult) {
          if (syncResult.selectedFirestoreId != null) {
            final previousItemId = state.connectedDevices[deviceInstanceId]?.selectedItemId;
            // Skip if selection hasn't changed (prefs echo from device)
            if (previousItemId == syncResult.selectedFirestoreId) {
              AppLogger.debug('Skipping prefs echo for ${syncResult.selectedFirestoreId} on $deviceInstanceId');
              return;
            }
            // Optimistic update: show selection immediately for UI responsiveness
            emit(state.copyWith(
              connectedDevices: _updateDevice(deviceInstanceId, (d) => d.copyWith(
                selectedItemId: syncResult.selectedFirestoreId,
              )),
            ));
            // Dispatch ClaimItem to handle Firestore claim logic in background.
            // Push to other devices so they get claim-filtered item lists.
            // The echo check above (previousItemId == selectedFirestoreId)
            // prevents infinite loops: when B receives a push and echoes
            // back the same selection, the check short-circuits.
            add(ClaimItem(
              itemId: syncResult.selectedFirestoreId!,
              deviceInstanceId: deviceInstanceId,
              previousItemId: previousItemId,
            ));
          } else if (syncResult.clearSelection) {
            // Device explicitly said no item selected - clear app's selection
            emit(state.copyWith(
              connectedDevices: _updateDevice(deviceInstanceId, (d) => d.copyWith(
                clearSelectedItemId: true,
              )),
            ));
          }
        },
      );
    }

    // Handle log pagination - if more pages available, request them
    if (message.type == BleMessageType.logs && message.hasMore) {
      final currentPage = message.page ?? 0;
      await Future.delayed(const Duration(milliseconds: BluetoothConstants.commandIntervalDelayMs));
      add(RequestDeviceData(type: DeviceDataType.logs, page: currentPage + 1, deviceInstanceId: deviceInstanceId));
    }

    // Clear logs on device when all pages received
    if (message.type == BleMessageType.logs && !message.hasMore) {
      add(ClearDeviceLogs(deviceInstanceId: deviceInstanceId));
    }
  }

  /// Updates selected item ID from device prefs during initial sync.
  Future<void> _onUpdateSelectedItemFromDevice(
    UpdateSelectedItemFromDevice event,
    Emitter<BluetoothState> emit,
  ) async {
    final deviceId = event.deviceInstanceId;
    if (deviceId.isNotEmpty) {
      emit(state.copyWith(
        connectedDevices: _updateDevice(deviceId, (d) => d.copyWith(selectedItemId: event.itemId)),
      ));
    }
  }

  // ========== Paired Device Handlers ==========

  /// Loads paired devices from the user repository.
  Future<void> _onLoadPairedDevices(
    LoadPairedDevices event,
    Emitter<BluetoothState> emit,
  ) async {
    final result = await _userRepository.getCurrentUser();
    result.fold(
      (failure) {},
      (user) => emit(state.copyWith(pairedDevices: user.pairedDevices)),
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
        AppLogger.debug('Failed to update device name: ${failure.message}');
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

  Future<void> _onUpdateDeviceColor(
    UpdateDeviceColor event,
    Emitter<BluetoothState> emit,
  ) async {
    final result = await _userRepository.updateDeviceColor(
      event.deviceInstanceId,
      event.newColor,
    );

    result.fold(
      (failure) {
        AppLogger.debug('Failed to update device color: ${failure.message}');
      },
      (_) {
        final updatedDevices = state.pairedDevices.map((device) {
          if (device.deviceInstanceId == event.deviceInstanceId) {
            return device.copyWith(color: event.newColor);
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
    // Release all claims for this device before unpairing
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (userId.isNotEmpty) {
      final releaseResult = await _itemRepository.releaseAllClaims(event.deviceInstanceId, userId);
      releaseResult.fold(
        (failure) => AppLogger.debug('Failed to release claims for ${event.deviceInstanceId}: ${failure.message}'),
        (_) => AppLogger.debug('Released all claims for device ${event.deviceInstanceId}'),
      );
    }

    // Check if the device being unpaired is currently connected (direct map lookup)
    final deviceState = state.connectedDevices[event.deviceInstanceId];

    // Disconnect first if this device is connected
    if (deviceState != null) {
      AppLogger.debug('Disconnecting from device being unpaired');
      _manualDisconnects.add(event.deviceInstanceId);
      _devicesToReconnect.remove(event.deviceInstanceId);
      _reconnectTimers[event.deviceInstanceId]?.cancel();
      _reconnectTimers.remove(event.deviceInstanceId);
      _reconnectAttempts.remove(event.deviceInstanceId);
      _claimQueues.remove(event.deviceInstanceId);
      _deviceCategories.remove(event.deviceInstanceId);

      await _bluetoothRepository.disconnect(deviceState.device.id);
    }

    final result = await _userRepository.removePairedDevice(event.deviceInstanceId);

    result.fold(
      (failure) {
        AppLogger.debug('Failed to remove paired device: ${failure.message}');
      },
      (_) {
        // Update local state
        final updatedDevices = state.pairedDevices
            .where((d) => d.deviceInstanceId != event.deviceInstanceId)
            .toList();

        if (deviceState != null) {
          // Also clear connected state for this device
          emit(state.copyWith(
            pairedDevices: updatedDevices,
            status: BluetoothStatus.ready,
            connectedDevices: _removeDevice(event.deviceInstanceId),
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
    final deviceInstanceId = event.deviceInstanceId;
    AppLogger.debug('BluetoothBloc: Setting conflict, deviceInstanceId=$deviceInstanceId');
    if (deviceInstanceId.isEmpty) return;

    // If we have a device in the map, update its status
    // If not yet in map (handshake just completed), add it
    final existing = state.connectedDevices[deviceInstanceId];
    final updated = existing != null
        ? _updateDevice(deviceInstanceId, (d) => d.copyWith(
            syncStatus: DeviceSyncStatus.conflict,
            conflictAppSyncSeq: event.appSyncSeq,
            conflictDeviceSyncSeq: event.deviceSyncSeq,
          ))
        : {
            ...state.connectedDevices,
            deviceInstanceId: DeviceConnectionState(
              device: state.connectedDevice ?? BleDevice(id: deviceInstanceId, name: 'Traxelos Device', rssi: 0),
              syncStatus: DeviceSyncStatus.conflict,
              conflictAppSyncSeq: event.appSyncSeq,
              conflictDeviceSyncSeq: event.deviceSyncSeq,
            ),
          };

    emit(state.copyWith(connectedDevices: updated));
  }

  /// User confirmed override - perform the override sync.
  Future<void> _onConfirmSyncOverride(
    ConfirmSyncOverride event,
    Emitter<BluetoothState> emit,
  ) async {
    final deviceId = event.deviceInstanceId;
    if (deviceId.isEmpty) {
      emit(state.copyWith(errorMessage: 'No device connected'));
      return;
    }

    final deviceName = state.connectedDevices[deviceId]?.device.name;

    // Clear conflict and set isOverriding
    emit(state.copyWith(
      connectedDevices: _updateDevice(deviceId, (d) => d.copyWith(
        isOverriding: true,
        syncStatus: DeviceSyncStatus.syncing,
        clearConflict: true,
      )),
    ));

    // Use event's selectedItemId if provided, otherwise fall back to device state
    final selectedItemId = event.currentSelectedItemId
        ?? state.connectedDevices[deviceId]?.selectedItemId;
    AppLogger.debug('Override: selectedItemId=$selectedItemId');

    final result = await _performOverride.call(
      PerformOverrideParams(
        deviceId: deviceId,
        deviceInstanceId: deviceId,
        deviceName: deviceName,
        currentSelectedFirestoreId: selectedItemId,
      ),
    );

    result.fold(
      (failure) {
        emit(state.copyWith(
          connectedDevices: _updateDevice(deviceId, (d) => d.copyWith(isOverriding: false)),
          errorMessage: failure.message,
        ));
      },
      (syncResult) {
        emit(state.copyWith(
          connectedDevices: _updateDevice(deviceId, (d) => d.copyWith(
            isOverriding: false,
            selectedItemId: syncResult.selectedFirestoreId,
          )),
        ));

        AppLogger.debug('Override completed successfully');
        add(SyncCompleted(deviceInstanceId: deviceId));
      },
    );
  }

  /// User cancelled conflict dialog - disconnect from the conflicting device.
  Future<void> _onCancelSyncConflict(
    CancelSyncConflict event,
    Emitter<BluetoothState> emit,
  ) async {
    final deviceId = event.deviceInstanceId;

    // Clear conflict state for this specific device
    emit(state.copyWith(
      connectedDevices: _updateDevice(deviceId, (d) => d.copyWith(
        syncStatus: DeviceSyncStatus.handshaking,
        clearConflict: true,
      )),
    ));

    // Disconnect from this device
    _manualDisconnects.add(deviceId);
    _devicesToReconnect.remove(deviceId);
    await _bluetoothRepository.disconnect(deviceId);
    emit(state.copyWith(
      status: state.connectedDevices.length <= 1 ? BluetoothStatus.ready : null,
      connectedDevices: _removeDevice(deviceId),
    ));
  }

  /// Clears conflict state after it's been handled.
  Future<void> _onClearConflictState(
    ClearConflictState event,
    Emitter<BluetoothState> emit,
  ) async {
    // Clear conflict from all devices that have it
    final clearedDevices = Map.fromEntries(
      state.connectedDevices.entries.map((e) => MapEntry(
        e.key,
        e.value.syncStatus == DeviceSyncStatus.conflict
            ? e.value.copyWith(syncStatus: DeviceSyncStatus.handshaking, clearConflict: true)
            : e.value,
      )),
    );
    emit(state.copyWith(connectedDevices: clearedDevices));
  }

  /// Handles successful sync completion.
  Future<void> _onSyncCompleted(
    SyncCompleted event,
    Emitter<BluetoothState> emit,
  ) async {
    final deviceInstanceId = event.deviceInstanceId;
    if (deviceInstanceId.isNotEmpty) {
      emit(state.copyWith(
        connectedDevices: _updateDevice(deviceInstanceId, (d) => d.copyWith(
          syncStatus: DeviceSyncStatus.synced,
        )),
      ));
    }
    // Reload paired devices to update UI
    add(const LoadPairedDevices());
  }

  // ========== Device Setup Handlers (uninitialized/factory reset) ==========

  /// Handles uninitialized device detection - UI should show setup dialog.
  Future<void> _onDeviceSetupRequired(
    DeviceSetupRequired event,
    Emitter<BluetoothState> emit,
  ) async {
    AppLogger.debug('BluetoothBloc: Setting needsSetup=true, deviceInstanceId=${event.deviceInstanceId}');
    final deviceInstanceId = event.deviceInstanceId;

    // If we have a device in the map, update its status
    // If not yet in map, add it
    final existing = state.connectedDevices[deviceInstanceId];
    final updated = existing != null
        ? _updateDevice(deviceInstanceId, (d) => d.copyWith(syncStatus: DeviceSyncStatus.setup))
        : {
            ...state.connectedDevices,
            deviceInstanceId: DeviceConnectionState(
              device: state.connectedDevice ?? BleDevice(id: deviceInstanceId, name: 'Traxelos Device', rssi: 0),
              syncStatus: DeviceSyncStatus.setup,
            ),
          };

    emit(state.copyWith(connectedDevices: updated));
  }

  /// User confirmed device setup - perform override to transfer items.
  Future<void> _onConfirmDeviceSetup(
    ConfirmDeviceSetup event,
    Emitter<BluetoothState> emit,
  ) async {
    final deviceId = event.deviceInstanceId;
    if (deviceId.isEmpty) {
      emit(state.copyWith(errorMessage: 'No device connected'));
      return;
    }

    final deviceName = state.connectedDevices[deviceId]?.device.name;

    // Clear setup and set isOverriding
    emit(state.copyWith(
      connectedDevices: _updateDevice(deviceId, (d) => d.copyWith(
        isOverriding: true,
        syncStatus: DeviceSyncStatus.syncing,
      )),
    ));

    // Use event's selectedItemId if provided, otherwise fall back to device state
    final selectedItemId = event.currentSelectedItemId
        ?? state.connectedDevices[deviceId]?.selectedItemId;

    final result = await _performOverride.call(
      PerformOverrideParams(
        deviceId: deviceId,
        deviceInstanceId: deviceId,
        deviceName: deviceName,
        currentSelectedFirestoreId: selectedItemId,
      ),
    );

    result.fold(
      (failure) {
        emit(state.copyWith(
          connectedDevices: _updateDevice(deviceId, (d) => d.copyWith(isOverriding: false)),
          errorMessage: failure.message,
        ));
      },
      (syncResult) {
        emit(state.copyWith(
          connectedDevices: _updateDevice(deviceId, (d) => d.copyWith(
            isOverriding: false,
            selectedItemId: syncResult.selectedFirestoreId,
          )),
        ));

        AppLogger.debug('Device setup completed successfully');
        add(SyncCompleted(deviceInstanceId: deviceId));
      },
    );
  }

  /// User cancelled device setup dialog - disconnect from device (device stays empty/unpaired).
  Future<void> _onCancelDeviceSetup(
    CancelDeviceSetup event,
    Emitter<BluetoothState> emit,
  ) async {
    final deviceId = event.deviceInstanceId;
    _manualDisconnects.add(deviceId);
    _devicesToReconnect.remove(deviceId);
    await _bluetoothRepository.disconnect(deviceId);
    emit(state.copyWith(
      status: state.connectedDevices.length <= 1 ? BluetoothStatus.ready : null,
      connectedDevices: _removeDevice(deviceId),
    ));
  }

  /// Clears setup state after it's been handled.
  Future<void> _onClearSetupState(
    ClearSetupState event,
    Emitter<BluetoothState> emit,
  ) async {
    // Clear setup from all devices that have it
    final clearedDevices = Map.fromEntries(
      state.connectedDevices.entries.map((e) => MapEntry(
        e.key,
        e.value.syncStatus == DeviceSyncStatus.setup
            ? e.value.copyWith(syncStatus: DeviceSyncStatus.handshaking)
            : e.value,
      )),
    );
    emit(state.copyWith(connectedDevices: clearedDevices));
  }

  // ========== Wrong Account Handlers ==========

  /// Device is locked to a different user account.
  /// Set state to show dialog, then disconnect.
  Future<void> _onWrongAccountDetected(
    WrongAccountDetected event,
    Emitter<BluetoothState> emit,
  ) async {
    final deviceInstId = state.connectedDeviceInstanceId;
    if (deviceInstId != null) {
      emit(state.copyWith(
        connectedDevices: _updateDevice(deviceInstId, (d) => d.copyWith(
          syncStatus: DeviceSyncStatus.wrongAccount,
        )),
      ));
    }
  }

  /// User dismissed wrong account dialog - disconnect from device.
  Future<void> _onDismissWrongAccount(
    DismissWrongAccount event,
    Emitter<BluetoothState> emit,
  ) async {
    // Disconnect from device
    final deviceId = state.connectedDevice?.id;
    if (deviceId != null) {
      final connectedInstId = state.connectedDeviceInstanceId ?? deviceId;
      _manualDisconnects.add(connectedInstId);
      _devicesToReconnect.remove(connectedInstId);
      await _bluetoothRepository.disconnect(deviceId);
      emit(state.copyWith(
        status: BluetoothStatus.ready,
        connectedDevices: _removeDevice(connectedInstId),
      ));
    }
  }

  // ========== Handshake Handler ==========

  /// Handles successful handshake completion, updating device sync status.
  Future<void> _onHandshakeCompleted(
    HandshakeCompleted event,
    Emitter<BluetoothState> emit,
  ) async {
    final deviceId = event.deviceInstanceId;
    final result = event.result;

    switch (result.type) {
      case SyncResultType.success:
      case SyncResultType.overrideComplete:
        emit(state.copyWith(
          connectedDevices: _updateDevice(deviceId, (d) => d.copyWith(
            syncStatus: DeviceSyncStatus.synced,
            selectedItemId: result.selectedFirestoreId,
          )),
        ));
        // Reload paired devices to update UI
        add(const LoadPairedDevices());

        // Claim the selected item if handshake returned one
        if (result.selectedFirestoreId != null) {
          final previousItemId = state.connectedDevices[deviceId]?.selectedItemId;
          add(ClaimItem(
            itemId: result.selectedFirestoreId!,
            deviceInstanceId: deviceId,
            previousItemId: previousItemId,
          ));
        }

        // Always push claim-filtered items on connection. When
        // selectedFirestoreId is null (normal sync), RefreshDeviceItemsUseCase
        // falls back to the device's claimedBy item for correct selection.
        _refreshAndUpdateCategory(deviceId, result.selectedFirestoreId);
    }
  }

  // ========== Claim Handlers ==========

  Future<void> _onClaimItem(
    ClaimItem event,
    Emitter<BluetoothState> emit,
  ) async {
    if (state.connectedDevices[event.deviceInstanceId] == null) return;

    // Fire-and-forget but SERIALIZED per device: each claim waits for the
    // previous one to complete before starting, preventing out-of-order
    // Firestore transactions that would leave stale claims behind.
    final previousItemId = event.previousItemId;
    final deviceInstanceId = event.deviceInstanceId;
    final fromDeviceEcho = event.fromDeviceEcho;
    final itemId = event.itemId;

    final previous = _claimQueues[deviceInstanceId] ?? Future.value();
    _claimQueues[deviceInstanceId] = previous.then((_) async {
      final result = await _itemRepository.atomicClaimSwap(
        itemId, deviceInstanceId, previousItemId,
      );
      if (result.isLeft()) {
        final failure = result.fold((f) => f, (_) => throw StateError('unreachable'));
        AppLogger.debug('Claim failed for $itemId: ${failure.message}');
        // Corrective push: revert device to the correct item list + selection.
        _refreshAndUpdateCategory(deviceInstanceId, previousItemId);
        return;
      }
      AppLogger.debug('Claimed item $itemId for device $deviceInstanceId'
          '${fromDeviceEcho ? ' (echo, no push)' : ''}');
      if (!fromDeviceEcho) {
        // Resolve source device's category (lightweight, no BLE send) before
        // deciding which other devices need a push. This ensures the cache
        // is up-to-date after a cross-category switch.
        final r = await _refreshDeviceItems.resolveCategory(RefreshDeviceItemsParams(
          deviceId: deviceInstanceId,
          deviceInstanceId: deviceInstanceId,
          selectedItemId: itemId,
        ));
        r.fold(
          (f) => AppLogger.debug('Category lookup failed for $deviceInstanceId: ${f.message}'),
          (categoryId) => _deviceCategories[deviceInstanceId] = categoryId,
        );
        _pushToOtherDevices(deviceInstanceId,
            sourceCategoryId: _deviceCategories[deviceInstanceId]);
      }
    });
  }

  Future<void> _onReleaseItem(
    ReleaseItem event,
    Emitter<BluetoothState> emit,
  ) async {
    final result = await _itemRepository.releaseItem(event.itemId);
    result.fold(
      (failure) => AppLogger.debug('Failed to release item ${event.itemId}: ${failure.message}'),
      (_) {
        AppLogger.debug('Released claim on item ${event.itemId}');
        // Push updated items to ALL connected devices (released item now available)
        _pushToAllDevices();
      },
    );
  }

  void _onRefreshAllDevices(
    RefreshAllDevices event,
    Emitter<BluetoothState> emit,
  ) {
    _pushToAllDevices();
  }

  // ========== Claim-Filtered Push Helpers ==========

  /// Push claim-filtered items to all connected devices except the specified one.
  /// Skips devices in a different category than [sourceCategoryId] when provided.
  void _pushToOtherDevices(String excludeDeviceId, {String? sourceCategoryId}) {
    for (final entry in state.connectedDevices.entries) {
      if (entry.key == excludeDeviceId) continue;
      if (!entry.value.isOnline) continue;
      // Skip devices in a different category — their item list is unaffected.
      final targetCategory = _deviceCategories[entry.key];
      if (sourceCategoryId != null &&
          targetCategory != null &&
          targetCategory != sourceCategoryId) {
        continue;
      }
      _refreshAndUpdateCategory(entry.key, entry.value.selectedItemId);
    }
  }

  /// Push claim-filtered items to ALL connected devices.
  void _pushToAllDevices() {
    for (final entry in state.connectedDevices.entries) {
      if (!entry.value.isOnline) continue;
      _refreshAndUpdateCategory(entry.key, entry.value.selectedItemId);
    }
  }

  /// Calls [RefreshDeviceItemsUseCase] and caches the device's category.
  void _refreshAndUpdateCategory(String deviceId, String? selectedItemId) {
    _refreshDeviceItems.call(RefreshDeviceItemsParams(
      deviceId: deviceId,
      deviceInstanceId: deviceId,
      selectedItemId: selectedItemId,
    )).then((r) => r.fold(
      (f) => AppLogger.debug('Push to $deviceId failed: ${f.message}'),
      (result) => _deviceCategories[deviceId] = result.categoryId,
    ));
  }

  // ========== Cleanup ==========

  @override
  Future<void> close() async {
    for (final timer in _reconnectTimers.values) {
      timer.cancel();
    }
    _reconnectTimers.clear();
    await _scanSubscription?.cancel();
    for (final sub in _connectionSubscriptions.values) {
      await sub.cancel();
    }
    _connectionSubscriptions.clear();
    for (final sub in _messageSubscriptions.values) {
      await sub.cancel();
    }
    _messageSubscriptions.clear();
    await _bluetoothStateSubscription?.cancel();
    return super.close();
  }
}
