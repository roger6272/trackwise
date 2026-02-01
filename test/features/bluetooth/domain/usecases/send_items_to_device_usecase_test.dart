import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:traxelos/core/error/failures.dart';
import 'package:traxelos/features/bluetooth/domain/repositories/bluetooth_repository.dart';
import 'package:traxelos/features/bluetooth/domain/usecases/send_items_to_device_usecase.dart';
import 'package:traxelos/features/items/domain/entities/item.dart';

class MockBluetoothRepository extends Mock implements BluetoothRepository {}

void main() {
  late SendItemsToDeviceUseCase useCase;
  late MockBluetoothRepository mockRepository;

  setUp(() {
    mockRepository = MockBluetoothRepository();
    useCase = SendItemsToDeviceUseCase(mockRepository);
  });

  const tDeviceId = 'test-device-id';

  Item createTestItem(String id) {
    return Item(
      id: id,
      name: 'Test Item $id',
      count: 100,
      todayCount: 10,
      incrementBy: 1,
      reminder: ReminderType.none,
      reminderValue: 0,
      lastResetTime: DateTime(2024, 1, 1),
      lastUpdated: DateTime(2024, 1, 1),
      userId: 'user-1',
    );
  }

  group('SendItemsToDeviceUseCase', () {
    test('should call repository.sendItems with correct parameters', () async {
      // arrange
      final tItems = [createTestItem('1'), createTestItem('2')];
      when(() => mockRepository.sendItems(tDeviceId, tItems))
          .thenAnswer((_) async => const Right(null));

      // act
      final result = await useCase(SendItemsParams(
        deviceId: tDeviceId,
        items: tItems,
      ));

      // assert
      expect(result, const Right(null));
      verify(() => mockRepository.sendItems(tDeviceId, tItems)).called(1);
    });

    test('should return ValidationFailure when items exceed max limit', () async {
      // arrange
      final tItems = List.generate(
        SendItemsToDeviceUseCase.maxItems + 1,
        (i) => createTestItem('item-$i'),
      );

      // act
      final result = await useCase(SendItemsParams(
        deviceId: tDeviceId,
        items: tItems,
      ));

      // assert
      expect(result, isA<Left>());
      expect((result as Left).value, isA<ValidationFailure>());
      verifyNever(() => mockRepository.sendItems(any(), any()));
    });

    test('should allow exactly maxItems', () async {
      // arrange
      final tItems = List.generate(
        SendItemsToDeviceUseCase.maxItems,
        (i) => createTestItem('item-$i'),
      );
      when(() => mockRepository.sendItems(tDeviceId, tItems))
          .thenAnswer((_) async => const Right(null));

      // act
      final result = await useCase(SendItemsParams(
        deviceId: tDeviceId,
        items: tItems,
      ));

      // assert
      expect(result, const Right(null));
      verify(() => mockRepository.sendItems(tDeviceId, tItems)).called(1);
    });

    test('should return failure from repository', () async {
      // arrange
      final tItems = [createTestItem('1')];
      when(() => mockRepository.sendItems(tDeviceId, tItems))
          .thenAnswer((_) async => const Left(BluetoothFailure('Send failed')));

      // act
      final result = await useCase(SendItemsParams(
        deviceId: tDeviceId,
        items: tItems,
      ));

      // assert
      expect(result, isA<Left>());
      expect((result as Left).value, isA<BluetoothFailure>());
    });

    test('should allow empty items list', () async {
      // arrange
      final tItems = <Item>[];
      when(() => mockRepository.sendItems(tDeviceId, tItems))
          .thenAnswer((_) async => const Right(null));

      // act
      final result = await useCase(SendItemsParams(
        deviceId: tDeviceId,
        items: tItems,
      ));

      // assert
      expect(result, const Right(null));
    });
  });

  group('SendItemsParams', () {
    test('props should contain deviceId, items, and categoryNames', () {
      final tItems = [createTestItem('1')];
      final params = SendItemsParams(deviceId: tDeviceId, items: tItems);

      expect(params.props, [tDeviceId, tItems, const <String, String>{}]);
    });

    test('two params with same values should be equal', () {
      final tItems = [createTestItem('1')];
      final params1 = SendItemsParams(deviceId: tDeviceId, items: tItems);
      final params2 = SendItemsParams(deviceId: tDeviceId, items: tItems);

      expect(params1, equals(params2));
    });
  });
}
