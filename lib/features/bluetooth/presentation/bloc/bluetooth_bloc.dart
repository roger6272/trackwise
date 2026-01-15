import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:injectable/injectable.dart';

import '../../../../auth/firebase_auth/auth_util.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/ble_connection_state.dart';
import '../../domain/entities/ble_device.dart';
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
import '../../domain/usecases/watch_connection_state_usecase.dart';
import '../../domain/usecases/watch_device_messages_usecase.dart';
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
        _reconnectTimer = Timer(const Duration(seconds: 2), () {
          if (!_isManualDisconnect &&
              state.status == BluetoothStatus.ready &&
              !isClosed) {
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
      await Future.delayed(const Duration(milliseconds: 1000));
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

    // Cancel any pending reconnect
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

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

      // Auto-reconnect if not manual disconnect
      if (!_isManualDisconnect && _lastConnectedDeviceId != null) {
        _reconnectTimer?.cancel();
        _reconnectTimer = Timer(const Duration(seconds: 2), () {
          if (!_isManualDisconnect &&
              state.status == BluetoothStatus.ready &&
              !isClosed) {
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

  void _performInitialSync() {
    // Send time sync and request current prefs
    add(const SendTimeSync());
    add(const RequestDeviceData(type: DeviceDataType.prefs));
  }

  // ========== Data Handlers ==========

  Future<void> _onSendItems(
    SendItemsToDevice event,
    Emitter<BluetoothState> emit,
  ) async {
    final deviceId = state.connectedDevice?.id;
    if (deviceId == null) return;

    final result = await _sendItems.call(
      SendItemsParams(deviceId: deviceId, items: event.items),
    );

    result.fold(
      (failure) => emit(state.copyWith(
        status: BluetoothStatus.error,
        errorMessage: failure.message,
      )),
      (_) {}, // Success - no state change needed
    );
  }

  Future<void> _onSendSelectedItem(
    SendSelectedItem event,
    Emitter<BluetoothState> emit,
  ) async {
    final deviceId = state.connectedDevice?.id;
    if (deviceId == null) return;

    final result = await _sendSelectedItem.call(
      SendSelectedItemParams(deviceId: deviceId, itemId: event.itemId),
    );

    result.fold(
      (failure) => emit(state.copyWith(
        status: BluetoothStatus.error,
        errorMessage: failure.message,
      )),
      (_) => emit(state.copyWith(selectedItemId: event.itemId)),
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
    emit(state.copyWith(
      lastMessage: event.message,
      selectedItemId: event.message.selectedId ?? state.selectedItemId,
      hasMoreLogs: event.message.hasMore,
    ));

    // Sync device data to Firestore
    final userId = currentUserUid;
    if (userId.isNotEmpty) {
      await _syncDeviceData.call(SyncDeviceDataParams(
        message: event.message,
        userId: userId,
      ));
    }
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
