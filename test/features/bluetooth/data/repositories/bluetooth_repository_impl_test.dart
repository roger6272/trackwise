import 'package:dartz/dartz.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:trackwise/core/error/failures.dart';
import 'package:trackwise/features/bluetooth/data/datasources/bluetooth_datasource.dart';
import 'package:trackwise/features/bluetooth/data/models/ble_device_model.dart';
import 'package:trackwise/features/bluetooth/data/models/ble_message_model.dart';
import 'package:trackwise/features/bluetooth/data/repositories/bluetooth_repository_impl.dart';
import 'package:trackwise/features/bluetooth/domain/entities/ble_connection_state.dart';
import 'package:trackwise/features/bluetooth/domain/entities/ble_message.dart';
import 'package:trackwise/features/items/domain/entities/item.dart';

class MockBluetoothDataSource extends Mock implements BluetoothDataSource {}

class MockBluetoothDevice extends Mock implements BluetoothDevice {}

void main() {
  late BluetoothRepositoryImpl repository;
  late MockBluetoothDataSource mockDataSource;

  setUpAll(() {
    registerFallbackValue(const Duration(seconds: 15));
    registerFallbackValue(<Item>[]);
  });

  setUp(() {
    mockDataSource = MockBluetoothDataSource();
    repository = BluetoothRepositoryImpl(mockDataSource);
  });

  group('scanDevices', () {
    final tDevices = [
      const BleDeviceModel(
        id: 'device-1',
        name: 'Test Device 1',
        rssi: -65,
        isConnectable: true,
      ),
      const BleDeviceModel(
        id: 'device-2',
        name: 'Test Device 2',
        rssi: -78,
        isConnectable: true,
      ),
    ];

    test('should emit devices from datasource stream', () async {
      // arrange
      when(() => mockDataSource.scanDevices(timeout: any(named: 'timeout')))
          .thenAnswer((_) => Stream.value(tDevices));

      // act
      final stream = repository.scanDevices();

      // assert
      await expectLater(
        stream,
        emits(isA<Right>().having(
          (r) => (r as Right).value,
          'devices',
          hasLength(2),
        )),
      );
    });

    test('should emit failure when datasource throws', () async {
      // arrange
      when(() => mockDataSource.scanDevices(timeout: any(named: 'timeout')))
          .thenAnswer((_) => Stream.error(Exception('Scan failed')));

      // act
      final stream = repository.scanDevices();

      // assert
      await expectLater(
        stream,
        emits(isA<Left>().having(
          (l) => (l as Left).value,
          'failure',
          isA<BluetoothFailure>(),
        )),
      );
    });
  });

  group('stopScan', () {
    test('should return Right(void) on success', () async {
      // arrange
      when(() => mockDataSource.stopScan()).thenAnswer((_) async {});

      // act
      final result = await repository.stopScan();

      // assert
      expect(result, const Right(null));
      verify(() => mockDataSource.stopScan()).called(1);
    });

    test('should return Left(BluetoothFailure) on error', () async {
      // arrange
      when(() => mockDataSource.stopScan()).thenThrow(Exception('Stop failed'));

      // act
      final result = await repository.stopScan();

      // assert
      expect(result, isA<Left>());
      expect((result as Left).value, isA<BluetoothFailure>());
    });
  });

  group('connect', () {
    const tDeviceId = 'test-device-id';
    final tBluetoothDevice = MockBluetoothDevice();

    test('should return Right(true) when connection and service discovery succeed', () async {
      // arrange
      when(() => mockDataSource.connect(tDeviceId))
          .thenAnswer((_) async => tBluetoothDevice);
      when(() => mockDataSource.discoverServices(tBluetoothDevice))
          .thenAnswer((_) async {});

      // act
      final result = await repository.connect(tDeviceId);

      // assert
      expect(result, const Right(true));
      verify(() => mockDataSource.connect(tDeviceId)).called(1);
      verify(() => mockDataSource.discoverServices(tBluetoothDevice)).called(1);
    });

    test('should return Left(BluetoothFailure) when connection fails', () async {
      // arrange
      when(() => mockDataSource.connect(tDeviceId))
          .thenThrow(Exception('Connection failed'));

      // act
      final result = await repository.connect(tDeviceId);

      // assert
      expect(result, isA<Left>());
      expect((result as Left).value, isA<BluetoothFailure>());
    });
  });

  group('disconnect', () {
    const tDeviceId = 'test-device-id';

    test('should return Right(void) on success', () async {
      // arrange
      when(() => mockDataSource.disconnect(tDeviceId))
          .thenAnswer((_) async {});

      // act
      final result = await repository.disconnect(tDeviceId);

      // assert
      expect(result, const Right(null));
      verify(() => mockDataSource.disconnect(tDeviceId)).called(1);
    });

    test('should return Left(BluetoothFailure) on error', () async {
      // arrange
      when(() => mockDataSource.disconnect(tDeviceId))
          .thenThrow(Exception('Disconnect failed'));

      // act
      final result = await repository.disconnect(tDeviceId);

      // assert
      expect(result, isA<Left>());
    });
  });

  group('sendItems', () {
    const tDeviceId = 'test-device-id';
    final tItems = [
      Item(
        id: 'item-1',
        name: 'Test Item',
        count: 100,
        todayCount: 10,
        incrementBy: 1,
        reminder: ReminderType.none,
        reminderValue: 0,
        lastResetTime: DateTime(2024, 1, 1),
        lastUpdated: DateTime(2024, 1, 1),
        userId: 'user-1',
      ),
    ];

    test('should call writeItems with formatted JSON', () async {
      // arrange
      when(() => mockDataSource.writeItems(tDeviceId, any()))
          .thenAnswer((_) async {});

      // act
      final result = await repository.sendItems(tDeviceId, tItems);

      // assert
      expect(result, const Right(null));
      verify(() => mockDataSource.writeItems(tDeviceId, any())).called(1);
    });

    test('should return Left(BluetoothFailure) on error', () async {
      // arrange
      when(() => mockDataSource.writeItems(tDeviceId, any()))
          .thenThrow(Exception('Write failed'));

      // act
      final result = await repository.sendItems(tDeviceId, tItems);

      // assert
      expect(result, isA<Left>());
    });
  });

  group('sendSelectedItem', () {
    const tDeviceId = 'test-device-id';
    const tItemId = 'item-1';

    test('should call writeCommand with correct JSON', () async {
      // arrange
      when(() => mockDataSource.writeCommand(tDeviceId, any()))
          .thenAnswer((_) async {});

      // act
      final result = await repository.sendSelectedItem(tDeviceId, tItemId);

      // assert
      expect(result, const Right(null));
      verify(() => mockDataSource.writeCommand(
        tDeviceId,
        any(that: allOf(contains('"cmd":"set_selected"'), contains('"id":"$tItemId"'))),
      )).called(1);
    });
  });

  group('sendTimeSync', () {
    const tDeviceId = 'test-device-id';

    test('should call writeCommand with time data', () async {
      // arrange
      when(() => mockDataSource.writeCommand(tDeviceId, any()))
          .thenAnswer((_) async {});

      // act
      final result = await repository.sendTimeSync(tDeviceId);

      // assert
      expect(result, const Right(null));
      verify(() => mockDataSource.writeCommand(
        tDeviceId,
        any(that: allOf(contains('"cmd":"set_time"'), contains('"utc_time"'))),
      )).called(1);
    });
  });

  group('watchMessages', () {
    const tDeviceId = 'test-device-id';

    test('should emit messages from datasource stream', () async {
      // arrange
      final tMessage = BleMessageModel(
        type: BleMessageType.event,
        data: {'event': 'increment'},
        hasMore: false,
        receivedAt: DateTime.now(),
      );

      when(() => mockDataSource.watchNotifications(tDeviceId))
          .thenAnswer((_) => Stream.value(tMessage));

      // act
      final stream = repository.watchMessages(tDeviceId);

      // assert
      await expectLater(
        stream,
        emits(isA<Right>().having(
          (r) => ((r as Right).value as BleMessage).type,
          'message type',
          BleMessageType.event,
        )),
      );
    });
  });

  group('isBluetoothEnabled', () {
    test('should return Right(true) when bluetooth is enabled', () async {
      // arrange
      when(() => mockDataSource.isBluetoothEnabled())
          .thenAnswer((_) async => true);

      // act
      final result = await repository.isBluetoothEnabled();

      // assert
      expect(result, const Right(true));
    });

    test('should return Right(false) when bluetooth is disabled', () async {
      // arrange
      when(() => mockDataSource.isBluetoothEnabled())
          .thenAnswer((_) async => false);

      // act
      final result = await repository.isBluetoothEnabled();

      // assert
      expect(result, const Right(false));
    });
  });

  group('requestPermissions', () {
    test('should return Right(true) when permissions granted', () async {
      // arrange
      when(() => mockDataSource.requestPermissions())
          .thenAnswer((_) async => true);

      // act
      final result = await repository.requestPermissions();

      // assert
      expect(result, const Right(true));
    });

    test('should return Right(false) when permissions denied', () async {
      // arrange
      when(() => mockDataSource.requestPermissions())
          .thenAnswer((_) async => false);

      // act
      final result = await repository.requestPermissions();

      // assert
      expect(result, const Right(false));
    });
  });

  group('watchConnectionState', () {
    const tDeviceId = 'test-device-id';

    test('should emit connection states from datasource', () async {
      // arrange
      when(() => mockDataSource.watchConnectionState(tDeviceId))
          .thenAnswer((_) => Stream.fromIterable([
                BleConnectionState.connecting,
                BleConnectionState.connected,
              ]));

      // act
      final stream = repository.watchConnectionState(tDeviceId);

      // assert
      await expectLater(
        stream,
        emitsInOrder([
          isA<Right>().having(
            (r) => (r as Right).value,
            'state',
            BleConnectionState.connecting,
          ),
          isA<Right>().having(
            (r) => (r as Right).value,
            'state',
            BleConnectionState.connected,
          ),
        ]),
      );
    });
  });
}
