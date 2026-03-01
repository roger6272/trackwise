import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:traxelos/features/bluetooth/domain/entities/ble_device.dart';
import 'package:traxelos/features/bluetooth/presentation/bloc/bluetooth_bloc.dart';
import 'package:traxelos/features/bluetooth/presentation/bloc/bluetooth_event.dart';
import 'package:traxelos/features/bluetooth/presentation/bloc/bluetooth_state.dart';
import 'package:traxelos/features/bluetooth/presentation/pages/bluetooth_search_page.dart';

class MockBluetoothBloc extends MockBloc<BluetoothEvent, BluetoothState>
    implements BluetoothBloc {}

void main() {
  late MockBluetoothBloc mockBluetoothBloc;

  setUpAll(() {
    registerFallbackValue(const CheckBluetoothPermissions());
    registerFallbackValue(const RequestBluetoothPermissions());
    registerFallbackValue(const StartScan());
    registerFallbackValue(const StopScan());
    registerFallbackValue(const ConnectToDevice('test_id'));
  });

  setUp(() {
    mockBluetoothBloc = MockBluetoothBloc();
  });

  Widget createTestWidget() {
    return MaterialApp(
      home: BlocProvider<BluetoothBloc>.value(
        value: mockBluetoothBloc,
        child: const BluetoothSearchPage(),
      ),
    );
  }

  group('BluetoothSearchPage', () {
    testWidgets('displays app bar with title', (tester) async {
      when(() => mockBluetoothBloc.state).thenReturn(
        const BluetoothState(
          permissionsGranted: true,
          bluetoothEnabled: true,
        ),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Find Device'), findsOneWidget);
    });

    testWidgets('displays scan button when ready', (tester) async {
      when(() => mockBluetoothBloc.state).thenReturn(
        const BluetoothState(
          status: BluetoothStatus.ready,
          permissionsGranted: true,
          bluetoothEnabled: true,
        ),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Scan for Devices'), findsOneWidget);
    });

    testWidgets('displays scanning state', (tester) async {
      when(() => mockBluetoothBloc.state).thenReturn(
        const BluetoothState(
          status: BluetoothStatus.scanning,
          permissionsGranted: true,
          bluetoothEnabled: true,
        ),
      );

      await tester.pumpWidget(createTestWidget());
      // Use pump() instead of pumpAndSettle() due to CircularProgressIndicator animation
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Scanning...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('displays empty state when no devices found', (tester) async {
      when(() => mockBluetoothBloc.state).thenReturn(
        const BluetoothState(
          status: BluetoothStatus.ready,
          permissionsGranted: true,
          bluetoothEnabled: true,
          discoveredDevices: [],
        ),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.textContaining('No new devices found'), findsOneWidget);
    });

    testWidgets('displays discovered devices', (tester) async {
      final devices = [
        BleDevice(id: 'device_1', name: 'ESP32-Tracker', rssi: -45),
        BleDevice(id: 'device_2', name: 'ESP32-Test', rssi: -65),
      ];

      when(() => mockBluetoothBloc.state).thenReturn(
        BluetoothState(
          status: BluetoothStatus.ready,
          permissionsGranted: true,
          bluetoothEnabled: true,
          discoveredDevices: devices,
        ),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('ESP32-Tracker'), findsOneWidget);
      expect(find.text('ESP32-Test'), findsOneWidget);
    });

    testWidgets('displays permissions banner when not granted', (tester) async {
      when(() => mockBluetoothBloc.state).thenReturn(
        const BluetoothState(
          permissionsGranted: false,
          bluetoothEnabled: true,
        ),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Bluetooth permissions required'), findsOneWidget);
      expect(find.text('Grant'), findsOneWidget);
    });

    testWidgets('displays bluetooth disabled banner', (tester) async {
      when(() => mockBluetoothBloc.state).thenReturn(
        const BluetoothState(
          permissionsGranted: true,
          bluetoothEnabled: false,
        ),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.textContaining('Bluetooth is disabled'), findsOneWidget);
    });

    testWidgets('shows permissions required when not granted',
        (tester) async {
      when(() => mockBluetoothBloc.state).thenReturn(
        const BluetoothState(
          permissionsGranted: false,
          bluetoothEnabled: true,
        ),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Permissions banner should be visible
      expect(find.text('Bluetooth permissions required'), findsOneWidget);
    });

    testWidgets('tapping scan button starts scan', (tester) async {
      when(() => mockBluetoothBloc.state).thenReturn(
        const BluetoothState(
          status: BluetoothStatus.ready,
          permissionsGranted: true,
          bluetoothEnabled: true,
        ),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Scan for Devices'));
      await tester.pump();

      verify(() => mockBluetoothBloc.add(const StartScan())).called(1);
    });

    testWidgets('shows scanning text when scanning', (tester) async {
      when(() => mockBluetoothBloc.state).thenReturn(
        const BluetoothState(
          status: BluetoothStatus.scanning,
          permissionsGranted: true,
          bluetoothEnabled: true,
        ),
      );

      await tester.pumpWidget(createTestWidget());
      // Use pump() instead of pumpAndSettle() due to CircularProgressIndicator animation
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should show "Scanning..." text
      expect(find.text('Scanning...'), findsOneWidget);
    });

    testWidgets('tapping Grant button requests permissions', (tester) async {
      when(() => mockBluetoothBloc.state).thenReturn(
        const BluetoothState(
          permissionsGranted: false,
          bluetoothEnabled: true,
        ),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Grant'));
      await tester.pump();

      verify(() => mockBluetoothBloc.add(const RequestBluetoothPermissions()))
          .called(1);
    });

    testWidgets('tapping device connects to it', (tester) async {
      final devices = [
        BleDevice(id: 'device_1', name: 'ESP32-Tracker', rssi: -45),
      ];

      when(() => mockBluetoothBloc.state).thenReturn(
        BluetoothState(
          status: BluetoothStatus.ready,
          permissionsGranted: true,
          bluetoothEnabled: true,
          discoveredDevices: devices,
        ),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('ESP32-Tracker'));
      await tester.pump();

      verify(() => mockBluetoothBloc.add(const ConnectToDevice('device_1')))
          .called(1);
    });

    testWidgets('displays connecting indicator for connecting device',
        (tester) async {
      final devices = [
        BleDevice(id: 'device_1', name: 'ESP32-Tracker', rssi: -45),
      ];

      when(() => mockBluetoothBloc.state).thenReturn(
        BluetoothState(
          status: BluetoothStatus.connecting,
          permissionsGranted: true,
          bluetoothEnabled: true,
          discoveredDevices: devices,
          connectingDeviceId: 'device_1',
        ),
      );

      await tester.pumpWidget(createTestWidget());
      // Use pump() instead of pumpAndSettle() due to CircularProgressIndicator animation
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should show circular progress indicator in the list tile
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });
  });
}
