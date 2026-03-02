// KNOWN LIMITATION: These tests require a mobile platform (Android/iOS emulator or device).
// They will fail on desktop (Windows/macOS/Linux) with:
//   "Unsupported operation: flutter_blue_plus is unsupported on this platform"
// This is because flutter_blue_plus accesses Bluetooth hardware APIs that don't exist on desktop.
// Run with: flutter test --device-id=<emulator_id>
//
// These tests are skipped on non-mobile platforms in CI.
@TestOn('android || ios')
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:traxelos/core/error/failures.dart';
import 'package:traxelos/core/usecases/usecase.dart';
import 'package:traxelos/features/bluetooth/domain/entities/ble_connection_state.dart';
import 'package:traxelos/features/bluetooth/domain/entities/ble_device.dart';
import 'package:traxelos/features/bluetooth/domain/entities/ble_message.dart';
import 'package:traxelos/features/bluetooth/domain/repositories/bluetooth_repository.dart';
import 'package:traxelos/features/bluetooth/domain/usecases/check_bluetooth_enabled_usecase.dart';
import 'package:traxelos/features/bluetooth/domain/usecases/clear_device_logs_usecase.dart';
import 'package:traxelos/features/bluetooth/domain/usecases/connect_device_usecase.dart';
import 'package:traxelos/features/bluetooth/domain/usecases/disconnect_device_usecase.dart';
import 'package:traxelos/features/bluetooth/domain/usecases/request_bluetooth_permissions_usecase.dart';
import 'package:traxelos/features/bluetooth/domain/usecases/request_device_data_usecase.dart';
import 'package:traxelos/features/bluetooth/domain/usecases/scan_devices_usecase.dart';
import 'package:traxelos/features/bluetooth/domain/usecases/send_items_to_device_usecase.dart';
import 'package:traxelos/features/bluetooth/domain/usecases/send_selected_item_usecase.dart';
import 'package:traxelos/features/bluetooth/domain/usecases/send_time_sync_usecase.dart';
import 'package:traxelos/features/bluetooth/domain/usecases/stop_scan_usecase.dart';
import 'package:traxelos/features/bluetooth/domain/usecases/sync_device_data_usecase.dart';
import 'package:traxelos/features/bluetooth/domain/usecases/sync_usecase.dart';
import 'package:traxelos/features/bluetooth/domain/usecases/unpair_device_usecase.dart';
import 'package:traxelos/features/bluetooth/domain/usecases/watch_connection_state_usecase.dart';
import 'package:traxelos/features/bluetooth/domain/usecases/watch_device_messages_usecase.dart';
import 'package:traxelos/features/bluetooth/presentation/bloc/bluetooth_bloc.dart';
import 'package:traxelos/features/bluetooth/presentation/bloc/bluetooth_event.dart';
import 'package:traxelos/features/bluetooth/presentation/bloc/bluetooth_state.dart';
import 'package:traxelos/features/bluetooth/presentation/bloc/device_connection_state.dart';
import 'package:traxelos/features/auth/domain/repositories/user_repository.dart';

// Mocks
class MockScanDevicesUseCase extends Mock implements ScanDevicesUseCase {}

class MockStopScanUseCase extends Mock implements StopScanUseCase {}

class MockConnectDeviceUseCase extends Mock implements ConnectDeviceUseCase {}

class MockDisconnectDeviceUseCase extends Mock implements DisconnectDeviceUseCase {}

class MockWatchConnectionStateUseCase extends Mock implements WatchConnectionStateUseCase {}

class MockWatchDeviceMessagesUseCase extends Mock implements WatchDeviceMessagesUseCase {}

class MockSendItemsToDeviceUseCase extends Mock implements SendItemsToDeviceUseCase {}

class MockSendSelectedItemUseCase extends Mock implements SendSelectedItemUseCase {}

class MockSendTimeSyncUseCase extends Mock implements SendTimeSyncUseCase {}

class MockRequestDeviceDataUseCase extends Mock implements RequestDeviceDataUseCase {}

class MockClearDeviceLogsUseCase extends Mock implements ClearDeviceLogsUseCase {}

class MockUnpairDeviceUseCase extends Mock implements UnpairDeviceUseCase {}

class MockCheckBluetoothEnabledUseCase extends Mock implements CheckBluetoothEnabledUseCase {}

class MockRequestBluetoothPermissionsUseCase extends Mock implements RequestBluetoothPermissionsUseCase {}

class MockSyncDeviceDataUseCase extends Mock implements SyncDeviceDataUseCase {}

class MockPerformSyncUseCase extends Mock implements PerformSyncUseCase {}

class MockPerformOverrideUseCase extends Mock implements PerformOverrideUseCase {}

class MockUserRepository extends Mock implements UserRepository {}

class MockBluetoothRepository extends Mock implements BluetoothRepository {}

void main() {
  late BluetoothBloc bloc;
  late MockScanDevicesUseCase mockScanDevices;
  late MockStopScanUseCase mockStopScan;
  late MockConnectDeviceUseCase mockConnectDevice;
  late MockDisconnectDeviceUseCase mockDisconnectDevice;
  late MockWatchConnectionStateUseCase mockWatchConnectionState;
  late MockWatchDeviceMessagesUseCase mockWatchMessages;
  late MockSendItemsToDeviceUseCase mockSendItems;
  late MockSendSelectedItemUseCase mockSendSelectedItem;
  late MockSendTimeSyncUseCase mockSendTimeSync;
  late MockRequestDeviceDataUseCase mockRequestData;
  late MockClearDeviceLogsUseCase mockClearLogs;
  late MockUnpairDeviceUseCase mockUnpairDevice;
  late MockCheckBluetoothEnabledUseCase mockCheckBluetoothEnabled;
  late MockRequestBluetoothPermissionsUseCase mockRequestPermissions;
  late MockSyncDeviceDataUseCase mockSyncDeviceData;
  late MockPerformSyncUseCase mockPerformSync;
  late MockPerformOverrideUseCase mockPerformOverride;
  late MockUserRepository mockUserRepository;
  late MockBluetoothRepository mockBluetoothRepository;

  setUp(() {
    mockScanDevices = MockScanDevicesUseCase();
    mockStopScan = MockStopScanUseCase();
    mockConnectDevice = MockConnectDeviceUseCase();
    mockDisconnectDevice = MockDisconnectDeviceUseCase();
    mockWatchConnectionState = MockWatchConnectionStateUseCase();
    mockWatchMessages = MockWatchDeviceMessagesUseCase();
    mockSendItems = MockSendItemsToDeviceUseCase();
    mockSendSelectedItem = MockSendSelectedItemUseCase();
    mockSendTimeSync = MockSendTimeSyncUseCase();
    mockRequestData = MockRequestDeviceDataUseCase();
    mockClearLogs = MockClearDeviceLogsUseCase();
    mockUnpairDevice = MockUnpairDeviceUseCase();
    mockCheckBluetoothEnabled = MockCheckBluetoothEnabledUseCase();
    mockRequestPermissions = MockRequestBluetoothPermissionsUseCase();
    mockSyncDeviceData = MockSyncDeviceDataUseCase();
    mockPerformSync = MockPerformSyncUseCase();
    mockPerformOverride = MockPerformOverrideUseCase();
    mockUserRepository = MockUserRepository();
    mockBluetoothRepository = MockBluetoothRepository();

    bloc = BluetoothBloc(
      mockScanDevices,
      mockStopScan,
      mockConnectDevice,
      mockDisconnectDevice,
      mockWatchConnectionState,
      mockWatchMessages,
      mockSendItems,
      mockSendSelectedItem,
      mockSendTimeSync,
      mockRequestData,
      mockClearLogs,
      mockUnpairDevice,
      mockCheckBluetoothEnabled,
      mockRequestPermissions,
      mockSyncDeviceData,
      mockPerformSync,
      mockPerformOverride,
      mockUserRepository,
      mockBluetoothRepository,
    );
  });

  tearDown(() {
    bloc.close();
  });

  setUpAll(() {
    registerFallbackValue(const NoParams());
    registerFallbackValue(const ScanDevicesParams());
    registerFallbackValue(const ConnectDeviceParams(''));
    registerFallbackValue(const DisconnectDeviceParams(''));
    registerFallbackValue(const WatchConnectionStateParams(''));
    registerFallbackValue(const WatchDeviceMessagesParams(''));
    registerFallbackValue(const SendTimeSyncParams(''));
    registerFallbackValue(const ClearDeviceLogsParams(''));
    registerFallbackValue(RequestDeviceDataParams(
      deviceId: '',
      type: DeviceDataType.prefs,
    ));
  });

  test('initial state should be BluetoothState with initial status', () {
    expect(bloc.state.status, BluetoothStatus.initial);
    expect(bloc.state.discoveredDevices, isEmpty);
    expect(bloc.state.connectedDevice, isNull);
  });

  group('RequestBluetoothPermissions', () {
    blocTest<BluetoothBloc, BluetoothState>(
      'emits [checkingPermissions, ready] when permissions granted',
      build: () {
        when(() => mockRequestPermissions.call(any()))
            .thenAnswer((_) async => const Right(true));
        when(() => mockCheckBluetoothEnabled.call(any()))
            .thenAnswer((_) async => const Right(true));
        return bloc;
      },
      act: (bloc) => bloc.add(const RequestBluetoothPermissions()),
      expect: () => [
        const BluetoothState(status: BluetoothStatus.checkingPermissions),
        const BluetoothState(
          status: BluetoothStatus.ready,
          permissionsGranted: true,
        ),
        const BluetoothState(
          status: BluetoothStatus.ready,
          permissionsGranted: true,
          bluetoothEnabled: true,
        ),
      ],
    );

    blocTest<BluetoothBloc, BluetoothState>(
      'emits [checkingPermissions, permissionsDenied] when permissions denied',
      build: () {
        when(() => mockRequestPermissions.call(any()))
            .thenAnswer((_) async => const Right(false));
        return bloc;
      },
      act: (bloc) => bloc.add(const RequestBluetoothPermissions()),
      expect: () => [
        const BluetoothState(status: BluetoothStatus.checkingPermissions),
        const BluetoothState(
          status: BluetoothStatus.permissionsDenied,
          permissionsGranted: false,
        ),
      ],
    );

    blocTest<BluetoothBloc, BluetoothState>(
      'emits [checkingPermissions, error] when permission request fails',
      build: () {
        when(() => mockRequestPermissions.call(any()))
            .thenAnswer((_) async => const Left(BluetoothFailure('Failed')));
        return bloc;
      },
      act: (bloc) => bloc.add(const RequestBluetoothPermissions()),
      expect: () => [
        const BluetoothState(status: BluetoothStatus.checkingPermissions),
        const BluetoothState(
          status: BluetoothStatus.error,
          errorMessage: 'Failed',
        ),
      ],
    );
  });

  group('CheckBluetoothEnabled', () {
    blocTest<BluetoothBloc, BluetoothState>(
      'emits [ready] when bluetooth is enabled',
      build: () {
        when(() => mockCheckBluetoothEnabled.call(any()))
            .thenAnswer((_) async => const Right(true));
        return bloc;
      },
      act: (bloc) => bloc.add(const CheckBluetoothEnabled()),
      expect: () => [
        const BluetoothState(
          status: BluetoothStatus.ready,
          bluetoothEnabled: true,
        ),
      ],
    );

    blocTest<BluetoothBloc, BluetoothState>(
      'emits [bluetoothDisabled] when bluetooth is off',
      build: () {
        when(() => mockCheckBluetoothEnabled.call(any()))
            .thenAnswer((_) async => const Right(false));
        return bloc;
      },
      act: (bloc) => bloc.add(const CheckBluetoothEnabled()),
      expect: () => [
        const BluetoothState(
          status: BluetoothStatus.bluetoothDisabled,
          bluetoothEnabled: false,
        ),
      ],
    );
  });

  group('StartScan', () {
    final tDevices = [
      const BleDevice(id: 'device-1', name: 'Test Device', rssi: -65),
    ];

    blocTest<BluetoothBloc, BluetoothState>(
      'emits [scanning, scanning with devices, ready] when scan succeeds',
      build: () {
        when(() => mockScanDevices.call(any()))
            .thenAnswer((_) => Stream.value(Right(tDevices)));
        when(() => mockStopScan.call(any()))
            .thenAnswer((_) async => const Right(null));
        return bloc;
      },
      act: (bloc) => bloc.add(const StartScan()),
      wait: const Duration(milliseconds: 100),
      expect: () => [
        const BluetoothState(
          status: BluetoothStatus.scanning,
          discoveredDevices: [],
        ),
        BluetoothState(
          status: BluetoothStatus.scanning,
          discoveredDevices: tDevices,
        ),
        BluetoothState(
          status: BluetoothStatus.ready,
          discoveredDevices: tDevices,
        ),
      ],
    );
  });

  group('StopScan', () {
    blocTest<BluetoothBloc, BluetoothState>(
      'emits [ready] when stop scan called during scanning',
      build: () {
        when(() => mockStopScan.call(any()))
            .thenAnswer((_) async => const Right(null));
        return bloc;
      },
      seed: () => const BluetoothState(status: BluetoothStatus.scanning),
      act: (bloc) => bloc.add(const StopScan()),
      expect: () => [
        const BluetoothState(status: BluetoothStatus.ready),
      ],
    );
  });

  group('ConnectToDevice', () {
    const tDeviceId = 'test-device-id';

    blocTest<BluetoothBloc, BluetoothState>(
      'emits [connecting] and adds device to connectedDevices on connection',
      build: () {
        when(() => mockWatchConnectionState.call(any()))
            .thenAnswer((_) => Stream.value(const Right(BleConnectionState.connected)));
        when(() => mockConnectDevice.call(any()))
            .thenAnswer((_) async => const Right(true));
        when(() => mockWatchMessages.call(any()))
            .thenAnswer((_) => const Stream.empty());
        when(() => mockSendTimeSync.call(any()))
            .thenAnswer((_) async => const Right(null));
        when(() => mockRequestData.call(any()))
            .thenAnswer((_) async => const Right(null));
        return bloc;
      },
      act: (bloc) => bloc.add(const ConnectToDevice(tDeviceId)),
      wait: const Duration(milliseconds: 100),
      expect: () => [
        const BluetoothState(
          status: BluetoothStatus.connecting,
          connectingDeviceId: tDeviceId,
        ),
        // Connected state: device added to connectedDevices map
        isA<BluetoothState>().having(
          (s) => s.isConnected,
          'isConnected',
          true,
        ),
      ],
    );

    blocTest<BluetoothBloc, BluetoothState>(
      'emits [connecting, error] when connection fails',
      build: () {
        when(() => mockWatchConnectionState.call(any()))
            .thenAnswer((_) => const Stream.empty());
        when(() => mockConnectDevice.call(any()))
            .thenAnswer((_) async => const Left(BluetoothFailure('Connection failed')));
        return bloc;
      },
      act: (bloc) => bloc.add(const ConnectToDevice(tDeviceId)),
      expect: () => [
        const BluetoothState(
          status: BluetoothStatus.connecting,
          connectingDeviceId: tDeviceId,
        ),
        const BluetoothState(
          status: BluetoothStatus.error,
          errorMessage: 'Connection failed',
        ),
      ],
    );
  });

  group('DisconnectFromDevice', () {
    const tDevice = BleDevice(id: 'device-1', name: 'Test', rssi: -65);
    final tConnectedDevices = {
      'device-1': DeviceConnectionState(
        device: tDevice,
        syncStatus: DeviceSyncStatus.synced,
      ),
    };

    blocTest<BluetoothBloc, BluetoothState>(
      'emits [ready with empty connectedDevices] when disconnect succeeds',
      build: () {
        when(() => mockDisconnectDevice.call(any()))
            .thenAnswer((_) async => const Right(null));
        return bloc;
      },
      seed: () => BluetoothState(
        status: BluetoothStatus.ready,
        connectedDevices: tConnectedDevices,
      ),
      act: (bloc) => bloc.add(const DisconnectFromDevice(deviceInstanceId: 'device-1')),
      expect: () => [
        const BluetoothState(status: BluetoothStatus.ready),
      ],
    );

    blocTest<BluetoothBloc, BluetoothState>(
      'emits [error] when disconnect fails',
      build: () {
        when(() => mockDisconnectDevice.call(any()))
            .thenAnswer((_) async => const Left(BluetoothFailure('Disconnect failed')));
        return bloc;
      },
      seed: () => BluetoothState(
        status: BluetoothStatus.ready,
        connectedDevices: tConnectedDevices,
      ),
      act: (bloc) => bloc.add(const DisconnectFromDevice(deviceInstanceId: 'device-1')),
      expect: () => [
        isA<BluetoothState>().having(
          (s) => s.status,
          'status',
          BluetoothStatus.error,
        ),
      ],
    );
  });

  group('MessageReceived', () {
    blocTest<BluetoothBloc, BluetoothState>(
      'updates hasMoreLogs from logs message when device connected',
      build: () => bloc,
      seed: () {
        const tDevice = BleDevice(id: 'device-1', name: 'Test', rssi: -65);
        return BluetoothState(
          connectedDevices: {
            'device-1': DeviceConnectionState(
              device: tDevice,
              syncStatus: DeviceSyncStatus.synced,
            ),
          },
        );
      },
      act: (bloc) {
        final message = BleMessage(
          type: BleMessageType.logs,
          data: [],
          hasMore: true,
          receivedAt: DateTime.now(),
        );
        bloc.add(MessageReceived(message, deviceInstanceId: 'device-1'));
      },
      expect: () => [
        isA<BluetoothState>().having(
          (s) => s.hasMoreLogs,
          'hasMoreLogs',
          true,
        ),
      ],
    );

    blocTest<BluetoothBloc, BluetoothState>(
      'does not emit when no device connected (message ignored)',
      build: () => bloc,
      act: (bloc) {
        final message = BleMessage(
          type: BleMessageType.logs,
          data: [],
          hasMore: true,
          receivedAt: DateTime.now(),
        );
        bloc.add(MessageReceived(message, deviceInstanceId: 'unknown-device'));
      },
      // When deviceInstanceId doesn't match any connected device, no state update
      expect: () => [],
    );
  });

  group('ScanResultsUpdated', () {
    final tDevices = [
      const BleDevice(id: 'device-1', name: 'Test Device', rssi: -65),
      const BleDevice(id: 'device-2', name: 'Test Device 2', rssi: -78),
    ];

    blocTest<BluetoothBloc, BluetoothState>(
      'emits state with discoveredDevices',
      build: () => bloc,
      seed: () => const BluetoothState(status: BluetoothStatus.scanning),
      act: (bloc) => bloc.add(ScanResultsUpdated(tDevices)),
      expect: () => [
        BluetoothState(
          status: BluetoothStatus.scanning,
          discoveredDevices: tDevices,
        ),
      ],
    );
  });

  group('State helpers', () {
    test('isScanning returns true when status is scanning', () {
      const state = BluetoothState(status: BluetoothStatus.scanning);
      expect(state.isScanning, true);
    });

    test('isConnected returns true when connectedDevices is non-empty', () {
      const tDevice = BleDevice(id: '1', name: 'Test', rssi: -65);
      final state = BluetoothState(
        connectedDevices: {
          '1': DeviceConnectionState(
            device: tDevice,
            syncStatus: DeviceSyncStatus.synced,
          ),
        },
      );
      expect(state.isConnected, true);
    });

    test('isConnected returns false when connectedDevices is empty', () {
      const state = BluetoothState();
      expect(state.isConnected, false);
    });

    test('isConnecting returns true when status is connecting', () {
      const state = BluetoothState(status: BluetoothStatus.connecting);
      expect(state.isConnecting, true);
    });
  });

  group('UpdateSelectedItemFromDevice', () {
    const tDevice = BleDevice(id: 'ble-1', name: 'Test', rssi: -65);
    const tDeviceId = 'device-1';

    blocTest<BluetoothBloc, BluetoothState>(
      'sets selectedItemId when itemId is non-empty',
      seed: () => BluetoothState(
        connectedDevices: {
          tDeviceId: DeviceConnectionState(
            device: tDevice,
            syncStatus: DeviceSyncStatus.synced,
          ),
        },
      ),
      build: () => bloc,
      act: (bloc) => bloc.add(
        const UpdateSelectedItemFromDevice('item-42', deviceInstanceId: tDeviceId),
      ),
      expect: () => [
        BluetoothState(
          connectedDevices: {
            tDeviceId: DeviceConnectionState(
              device: tDevice,
              syncStatus: DeviceSyncStatus.synced,
              selectedItemId: 'item-42',
            ),
          },
        ),
      ],
    );

    blocTest<BluetoothBloc, BluetoothState>(
      'clears selectedItemId when itemId is empty string',
      seed: () => BluetoothState(
        connectedDevices: {
          tDeviceId: DeviceConnectionState(
            device: tDevice,
            syncStatus: DeviceSyncStatus.synced,
            selectedItemId: 'item-42',
          ),
        },
      ),
      build: () => bloc,
      act: (bloc) => bloc.add(
        const UpdateSelectedItemFromDevice('', deviceInstanceId: tDeviceId),
      ),
      expect: () => [
        BluetoothState(
          connectedDevices: {
            tDeviceId: DeviceConnectionState(
              device: tDevice,
              syncStatus: DeviceSyncStatus.synced,
              // selectedItemId cleared to null
            ),
          },
        ),
      ],
    );

    blocTest<BluetoothBloc, BluetoothState>(
      'is a no-op when deviceInstanceId is empty',
      seed: () => const BluetoothState(),
      build: () => bloc,
      act: (bloc) => bloc.add(
        const UpdateSelectedItemFromDevice('item-42', deviceInstanceId: ''),
      ),
      expect: () => [],
    );
  });
}
