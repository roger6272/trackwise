import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:traxelos/features/auth/domain/entities/user.dart';
import 'package:traxelos/features/auth/domain/repositories/user_repository.dart';
import 'package:traxelos/features/bluetooth/domain/repositories/bluetooth_repository.dart';
import 'package:traxelos/features/bluetooth/domain/usecases/refresh_device_items_usecase.dart';
import 'package:traxelos/features/categories/domain/entities/category.dart';
import 'package:traxelos/features/categories/domain/repositories/category_repository.dart';
import 'package:traxelos/features/items/domain/entities/item.dart';
import 'package:traxelos/features/items/domain/repositories/item_repository.dart';

class MockItemRepository extends Mock implements ItemRepository {}

class MockCategoryRepository extends Mock implements CategoryRepository {}

class MockBluetoothRepository extends Mock implements BluetoothRepository {}

class MockUserRepository extends Mock implements UserRepository {}

void main() {
  late RefreshDeviceItemsUseCase useCase;
  late MockItemRepository mockItemRepository;
  late MockCategoryRepository mockCategoryRepository;
  late MockBluetoothRepository mockBluetoothRepository;
  late MockUserRepository mockUserRepository;

  const tDeviceId = 'test-device-id';
  const tDeviceInstanceId = 'device-instance-123';
  const tUserId = 'test-user-id';

  final tUser = User(id: tUserId, email: 'test@test.com', pairedDevices: const []);

  Item item(String id, int deviceItemId, {String? claimedBy}) => Item(
        id: id,
        name: 'Item $id',
        count: 0,
        todayCount: 0,
        incrementBy: 1,
        reminder: ReminderType.none,
        reminderValue: 0,
        lastUpdated: DateTime(2026),
        userId: tUserId,
        deviceItemId: deviceItemId,
        claimedBy: claimedBy,
      );

  setUp(() {
    mockItemRepository = MockItemRepository();
    mockCategoryRepository = MockCategoryRepository();
    mockBluetoothRepository = MockBluetoothRepository();
    mockUserRepository = MockUserRepository();
    useCase = RefreshDeviceItemsUseCase(
      mockItemRepository,
      mockCategoryRepository,
      mockBluetoothRepository,
      mockUserRepository,
    );

    when(() => mockUserRepository.getCurrentUser()).thenAnswer((_) async => Right(tUser));
    when(() => mockCategoryRepository.getCategories(tUserId))
        .thenAnswer((_) async => const Right(<Category>[]));
    when(() => mockBluetoothRepository.sendItems(any(), any(),
            categoryNames: any(named: 'categoryNames')))
        .thenAnswer((_) async => const Right(null));
    when(() => mockBluetoothRepository.sendSelectedItem(any(), any()))
        .thenAnswer((_) async => const Right(null));
  });

  test('device with no selection and no claim is pushed an empty list', () async {
    // e.g. reconnect after Set Up, or after its item was released — even
    // with a remembered category, the device must stay empty.
    when(() => mockItemRepository.getItems(tUserId))
        .thenAnswer((_) async => Right([item('a', 0), item('b', 1)]));

    await useCase(const RefreshDeviceItemsParams(
      deviceId: tDeviceId,
      deviceInstanceId: tDeviceInstanceId,
      categoryId: '',
    ));

    verify(() => mockBluetoothRepository.sendItems(tDeviceId, const [],
        categoryNames: any(named: 'categoryNames'))).called(1);
    verify(() => mockBluetoothRepository.sendSelectedItem(tDeviceId, -1)).called(1);
  });

  test('device holding a claim still gets its category list and selection', () async {
    final claimed = item('b', 1, claimedBy: tDeviceInstanceId);
    when(() => mockItemRepository.getItems(tUserId))
        .thenAnswer((_) async => Right([item('a', 0), claimed]));

    await useCase(const RefreshDeviceItemsParams(
      deviceId: tDeviceId,
      deviceInstanceId: tDeviceInstanceId,
    ));

    final sent = verify(() => mockBluetoothRepository.sendItems(tDeviceId, captureAny(),
        categoryNames: any(named: 'categoryNames'))).captured.single as List<Item>;
    expect(sent.map((i) => i.id), containsAll(['a', 'b']));
    verify(() => mockBluetoothRepository.sendSelectedItem(tDeviceId, 1)).called(1);
  });
}
