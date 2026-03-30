import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:traxelos/features/bluetooth/domain/entities/ble_device.dart';
import 'package:traxelos/features/bluetooth/domain/entities/paired_device.dart';
import 'package:traxelos/features/bluetooth/presentation/bloc/bluetooth_bloc.dart';
import 'package:traxelos/features/bluetooth/presentation/bloc/bluetooth_event.dart';
import 'package:traxelos/features/bluetooth/presentation/bloc/bluetooth_state.dart';
import 'package:traxelos/features/bluetooth/presentation/bloc/device_connection_state.dart';
import 'package:traxelos/features/bluetooth/presentation/pages/bluetooth_page.dart';
import 'package:traxelos/features/ota/presentation/bloc/ota_bloc.dart';
import 'package:traxelos/features/ota/presentation/bloc/ota_event.dart';
import 'package:traxelos/features/ota/presentation/bloc/ota_state.dart';

class MockBluetoothBloc extends MockBloc<BluetoothEvent, BluetoothState>
    implements BluetoothBloc {}

class MockOtaBloc extends MockBloc<OtaEvent, OtaBlocState>
    implements OtaBloc {}

void main() {
  late MockBluetoothBloc mockBluetoothBloc;
  late MockOtaBloc mockOtaBloc;

  setUpAll(() {
    registerFallbackValue(const CheckBluetoothPermissions());
    registerFallbackValue(const RequestBluetoothPermissions());
    registerFallbackValue(const LoadPairedDevices());
    registerFallbackValue(const DisconnectFromDevice(deviceInstanceId: ''));
  });

  setUp(() {
    mockBluetoothBloc = MockBluetoothBloc();
    mockOtaBloc = MockOtaBloc();
    when(() => mockOtaBloc.state).thenReturn(const OtaInitial());
  });

  Widget createTestWidget() {
    return MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<BluetoothBloc>.value(value: mockBluetoothBloc),
          BlocProvider<OtaBloc>.value(value: mockOtaBloc),
        ],
        child: const BluetoothPage(),
      ),
    );
  }

  final testDevice = PairedDevice(
    deviceInstanceId: 'test_device_id',
    deviceName: 'ESP32-Tracker',
    pairedAt: DateTime(2026, 1, 1),
    color: 0,
  );

  group('BluetoothPage', () {
    testWidgets('displays app bar with title', (tester) async {
      when(() => mockBluetoothBloc.state).thenReturn(const BluetoothState());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text('Bluetooth'),
          ),
          findsOneWidget);
    });

    testWidgets('displays empty state when no paired devices', (tester) async {
      when(() => mockBluetoothBloc.state).thenReturn(
        const BluetoothState(
          status: BluetoothStatus.ready,
          permissionsGranted: true,
          bluetoothEnabled: true,
        ),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('No devices paired'), findsOneWidget);
      expect(find.text('Find Device'), findsOneWidget);
    });

    testWidgets('displays permissions banner and Grant button when not granted',
        (tester) async {
      when(() => mockBluetoothBloc.state).thenReturn(
        const BluetoothState(
          status: BluetoothStatus.permissionsDenied,
          permissionsGranted: false,
          bluetoothEnabled: true,
        ),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Bluetooth permissions required'), findsOneWidget);
      expect(find.text('Grant Permissions'), findsOneWidget);
    });

    testWidgets('displays bluetooth disabled banner when BT is off',
        (tester) async {
      when(() => mockBluetoothBloc.state).thenReturn(
        const BluetoothState(
          status: BluetoothStatus.bluetoothDisabled,
          permissionsGranted: true,
          bluetoothEnabled: false,
        ),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Bluetooth is disabled'), findsOneWidget);
    });

    testWidgets('displays device list with paired device', (tester) async {
      when(() => mockBluetoothBloc.state).thenReturn(
        BluetoothState(
          status: BluetoothStatus.ready,
          permissionsGranted: true,
          bluetoothEnabled: true,
          pairedDevices: [testDevice],
        ),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('ESP32-Tracker'), findsOneWidget);
      expect(find.text('No devices connected'), findsOneWidget);
    });

    testWidgets('displays connected device with summary', (tester) async {
      final bleDevice = BleDevice(
        id: 'test_device_id',
        name: 'ESP32-Tracker',
        rssi: -50,
      );

      when(() => mockBluetoothBloc.state).thenReturn(
        BluetoothState(
          status: BluetoothStatus.ready,
          permissionsGranted: true,
          bluetoothEnabled: true,
          pairedDevices: [testDevice],
          connectedDevices: {
            'test_device_id': DeviceConnectionState(
              device: bleDevice,
              syncStatus: DeviceSyncStatus.synced,
            ),
          },
        ),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('1 of 1 connected'), findsOneWidget);
      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('ESP32-Tracker'), findsOneWidget);
    });

    testWidgets('search button is visible in AppBar when devices are paired',
        (tester) async {
      when(() => mockBluetoothBloc.state).thenReturn(
        BluetoothState(
          status: BluetoothStatus.ready,
          permissionsGranted: true,
          bluetoothEnabled: true,
          pairedDevices: [testDevice],
        ),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.bluetooth_searching), findsOneWidget);
    });

    testWidgets('tapping Grant Permissions dispatches event', (tester) async {
      when(() => mockBluetoothBloc.state).thenReturn(
        const BluetoothState(
          status: BluetoothStatus.permissionsDenied,
          permissionsGranted: false,
          bluetoothEnabled: true,
        ),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Grant Permissions'));
      await tester.pump();

      verify(() => mockBluetoothBloc.add(const RequestBluetoothPermissions()))
          .called(1);
    });

    testWidgets('tapping Disconnect in popup menu dispatches event',
        (tester) async {
      final bleDevice = BleDevice(
        id: 'test_device_id',
        name: 'ESP32-Tracker',
        rssi: -50,
      );

      when(() => mockBluetoothBloc.state).thenReturn(
        BluetoothState(
          status: BluetoothStatus.ready,
          permissionsGranted: true,
          bluetoothEnabled: true,
          pairedDevices: [testDevice],
          connectedDevices: {
            'test_device_id': DeviceConnectionState(
              device: bleDevice,
              syncStatus: DeviceSyncStatus.synced,
            ),
          },
        ),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Open popup menu
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // Tap disconnect
      await tester.tap(find.text('Disconnect'));
      await tester.pump();

      verify(() =>
              mockBluetoothBloc.add(any(that: isA<DisconnectFromDevice>())))
          .called(1);
    });
  });
}
