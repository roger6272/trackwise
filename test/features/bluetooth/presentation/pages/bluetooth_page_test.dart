import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:trackwise/features/bluetooth/domain/entities/ble_device.dart';
import 'package:trackwise/features/bluetooth/presentation/bloc/bluetooth_bloc.dart';
import 'package:trackwise/features/bluetooth/presentation/bloc/bluetooth_event.dart';
import 'package:trackwise/features/bluetooth/presentation/bloc/bluetooth_state.dart';
import 'package:trackwise/features/bluetooth/presentation/pages/bluetooth_page.dart';

class MockBluetoothBloc extends MockBloc<BluetoothEvent, BluetoothState>
    implements BluetoothBloc {}

void main() {
  late MockBluetoothBloc mockBluetoothBloc;

  setUpAll(() {
    registerFallbackValue(const CheckBluetoothPermissions());
    registerFallbackValue(const RequestBluetoothPermissions());
    registerFallbackValue(const DisconnectFromDevice());
  });

  setUp(() {
    mockBluetoothBloc = MockBluetoothBloc();
  });

  Widget createTestWidget() {
    return MaterialApp(
      home: BlocProvider<BluetoothBloc>.value(
        value: mockBluetoothBloc,
        child: const BluetoothPage(),
      ),
    );
  }

  group('BluetoothPage', () {
    testWidgets('displays app bar with title', (tester) async {
      when(() => mockBluetoothBloc.state).thenReturn(const BluetoothState());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Find Bluetooth text in AppBar
      expect(find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Bluetooth'),
      ), findsOneWidget);
    });

    testWidgets('displays ready state when permissions granted and BT enabled',
        (tester) async {
      when(() => mockBluetoothBloc.state).thenReturn(
        const BluetoothState(
          status: BluetoothStatus.ready,
          permissionsGranted: true,
          bluetoothEnabled: true,
        ),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Ready to Connect'), findsOneWidget);
      expect(find.text('Find Device'), findsOneWidget);
    });

    testWidgets('displays permissions required when not granted', (tester) async {
      when(() => mockBluetoothBloc.state).thenReturn(
        const BluetoothState(
          status: BluetoothStatus.permissionsDenied,
          permissionsGranted: false,
          bluetoothEnabled: true,
        ),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Permissions Required'), findsOneWidget);
      expect(find.text('Grant Permissions'), findsOneWidget);
    });

    testWidgets('displays bluetooth disabled when BT is off', (tester) async {
      when(() => mockBluetoothBloc.state).thenReturn(
        const BluetoothState(
          status: BluetoothStatus.bluetoothDisabled,
          permissionsGranted: true,
          bluetoothEnabled: false,
        ),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Bluetooth Disabled'), findsOneWidget);
    });

    testWidgets('displays connecting state', (tester) async {
      when(() => mockBluetoothBloc.state).thenReturn(
        const BluetoothState(
          status: BluetoothStatus.connecting,
          permissionsGranted: true,
          bluetoothEnabled: true,
        ),
      );

      await tester.pumpWidget(createTestWidget());
      // Use pump instead of pumpAndSettle due to animation
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Connecting'), findsWidgets);
    });

    testWidgets('displays connected state with device info', (tester) async {
      final testDevice = BleDevice(
        id: 'test_device_id',
        name: 'ESP32-Tracker',
        rssi: -50,
      );

      when(() => mockBluetoothBloc.state).thenReturn(
        BluetoothState(
          status: BluetoothStatus.connected,
          permissionsGranted: true,
          bluetoothEnabled: true,
          connectedDevice: testDevice,
        ),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Connected'), findsOneWidget);
      expect(find.textContaining('ESP32-Tracker'), findsWidgets);
      expect(find.text('Manage Device'), findsOneWidget);
      expect(find.text('Disconnect'), findsOneWidget);
    });

    testWidgets('shows info section with bluetooth status', (tester) async {
      when(() => mockBluetoothBloc.state).thenReturn(
        const BluetoothState(
          status: BluetoothStatus.ready,
          permissionsGranted: true,
          bluetoothEnabled: true,
        ),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('About ESP32 Connection'), findsOneWidget);
      expect(find.text('Permissions'), findsOneWidget);
      expect(find.text('Device'), findsOneWidget);
    });

    testWidgets('Find Device button is visible when ready', (tester) async {
      when(() => mockBluetoothBloc.state).thenReturn(
        const BluetoothState(
          status: BluetoothStatus.ready,
          permissionsGranted: true,
          bluetoothEnabled: true,
        ),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Find Device'), findsOneWidget);
    });

    testWidgets('shows permissions message when not granted',
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

      expect(find.text('Permissions Required'), findsOneWidget);
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

    testWidgets('tapping Disconnect dispatches event', (tester) async {
      final testDevice = BleDevice(
        id: 'test_device_id',
        name: 'ESP32-Tracker',
        rssi: -50,
      );

      when(() => mockBluetoothBloc.state).thenReturn(
        BluetoothState(
          status: BluetoothStatus.connected,
          permissionsGranted: true,
          bluetoothEnabled: true,
          connectedDevice: testDevice,
        ),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Disconnect'));
      await tester.pump();

      verify(() => mockBluetoothBloc.add(const DisconnectFromDevice())).called(1);
    });
  });
}
