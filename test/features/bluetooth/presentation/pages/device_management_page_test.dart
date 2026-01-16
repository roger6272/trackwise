import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:trackwise/features/bluetooth/domain/entities/ble_device.dart';
import 'package:trackwise/features/bluetooth/presentation/bloc/bluetooth_bloc.dart';
import 'package:trackwise/features/bluetooth/presentation/bloc/bluetooth_event.dart';
import 'package:trackwise/features/bluetooth/presentation/bloc/bluetooth_state.dart';
import 'package:trackwise/features/bluetooth/presentation/pages/device_management_page.dart';
import 'package:trackwise/features/items/presentation/bloc/items_bloc.dart';
import 'package:trackwise/features/items/presentation/bloc/items_event.dart';
import 'package:trackwise/features/items/presentation/bloc/items_state.dart';

class MockBluetoothBloc extends MockBloc<BluetoothEvent, BluetoothState>
    implements BluetoothBloc {}

class MockItemsBloc extends MockBloc<ItemsEvent, ItemsState>
    implements ItemsBloc {}

void main() {
  late MockBluetoothBloc mockBluetoothBloc;
  late MockItemsBloc mockItemsBloc;

  setUpAll(() {
    registerFallbackValue(const DisconnectFromDevice());
    registerFallbackValue(const SendTimeSync());
    registerFallbackValue(const SendItemsToDevice([]));
  });

  setUp(() {
    mockBluetoothBloc = MockBluetoothBloc();
    mockItemsBloc = MockItemsBloc();
  });

  Widget createTestWidget() {
    return MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<BluetoothBloc>.value(value: mockBluetoothBloc),
          BlocProvider<ItemsBloc>.value(value: mockItemsBloc),
        ],
        child: const DeviceManagementPage(),
      ),
    );
  }

  group('DeviceManagementPage', () {
    testWidgets('displays app bar with title', (tester) async {
      final testDevice = BleDevice(
        id: 'test_device_id',
        name: 'ESP32-Tracker',
        rssi: -50,
      );

      when(() => mockBluetoothBloc.state).thenReturn(
        BluetoothState(
          status: BluetoothStatus.connected,
          connectedDevice: testDevice,
        ),
      );
      when(() => mockItemsBloc.state).thenReturn(ItemsInitial());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Device Manager'), findsOneWidget);
    });

    testWidgets('displays no device message when not connected', (tester) async {
      when(() => mockBluetoothBloc.state).thenReturn(
        const BluetoothState(status: BluetoothStatus.ready),
      );
      when(() => mockItemsBloc.state).thenReturn(ItemsInitial());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('No device connected'), findsOneWidget);
    });

    testWidgets('displays connected device info', (tester) async {
      final testDevice = BleDevice(
        id: 'test_device_id',
        name: 'ESP32-Tracker',
        rssi: -50,
      );

      when(() => mockBluetoothBloc.state).thenReturn(
        BluetoothState(
          status: BluetoothStatus.connected,
          connectedDevice: testDevice,
        ),
      );
      when(() => mockItemsBloc.state).thenReturn(ItemsInitial());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('ESP32-Tracker'), findsOneWidget);
      expect(find.text('test_device_id'), findsOneWidget);
      expect(find.textContaining('-50 dBm'), findsOneWidget);
    });

    testWidgets('displays sync section with buttons', (tester) async {
      final testDevice = BleDevice(
        id: 'test_device_id',
        name: 'ESP32-Tracker',
        rssi: -50,
      );

      when(() => mockBluetoothBloc.state).thenReturn(
        BluetoothState(
          status: BluetoothStatus.connected,
          connectedDevice: testDevice,
        ),
      );
      when(() => mockItemsBloc.state).thenReturn(ItemsInitial());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Sync Items'), findsOneWidget);
      expect(find.text('Sync Time'), findsOneWidget);
    });

    testWidgets('displays disconnect button', (tester) async {
      final testDevice = BleDevice(
        id: 'test_device_id',
        name: 'ESP32-Tracker',
        rssi: -50,
      );

      when(() => mockBluetoothBloc.state).thenReturn(
        BluetoothState(
          status: BluetoothStatus.connected,
          connectedDevice: testDevice,
        ),
      );
      when(() => mockItemsBloc.state).thenReturn(ItemsInitial());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Connection'), findsOneWidget);
      expect(find.text('Disconnect'), findsOneWidget);
    });

    testWidgets('tapping Sync Time dispatches event', (tester) async {
      final testDevice = BleDevice(
        id: 'test_device_id',
        name: 'ESP32-Tracker',
        rssi: -50,
      );

      when(() => mockBluetoothBloc.state).thenReturn(
        BluetoothState(
          status: BluetoothStatus.connected,
          connectedDevice: testDevice,
        ),
      );
      when(() => mockItemsBloc.state).thenReturn(ItemsInitial());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sync Time'));
      await tester.pump();

      verify(() => mockBluetoothBloc.add(const SendTimeSync())).called(1);
    });

    testWidgets('displays connected indicator icon', (tester) async {
      final testDevice = BleDevice(
        id: 'test_device_id',
        name: 'ESP32-Tracker',
        rssi: -50,
      );

      when(() => mockBluetoothBloc.state).thenReturn(
        BluetoothState(
          status: BluetoothStatus.connected,
          connectedDevice: testDevice,
        ),
      );
      when(() => mockItemsBloc.state).thenReturn(ItemsInitial());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.bluetooth_connected), findsOneWidget);
    });
  });
}
