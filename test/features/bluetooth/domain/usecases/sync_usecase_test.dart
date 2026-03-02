import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:traxelos/core/error/failures.dart';
import 'package:traxelos/core/services/connectivity_service.dart';
import 'package:traxelos/features/auth/domain/entities/user.dart';
import 'package:traxelos/features/auth/domain/repositories/user_repository.dart';
import 'package:traxelos/features/bluetooth/domain/entities/paired_device.dart';
import 'package:traxelos/features/bluetooth/domain/entities/sync_state.dart';
import 'package:traxelos/features/bluetooth/domain/failures/sync_failures.dart';
import 'package:traxelos/features/bluetooth/domain/repositories/bluetooth_repository.dart';
import 'package:traxelos/features/bluetooth/domain/usecases/sync_usecase.dart';
import 'package:traxelos/features/categories/domain/entities/category.dart';
import 'package:traxelos/features/categories/domain/repositories/category_repository.dart';
import 'package:traxelos/features/items/domain/entities/item.dart';
import 'package:traxelos/features/items/domain/repositories/item_repository.dart';

class MockBluetoothRepository extends Mock implements BluetoothRepository {}

class MockUserRepository extends Mock implements UserRepository {}

class MockItemRepository extends Mock implements ItemRepository {}

class MockCategoryRepository extends Mock implements CategoryRepository {}

class MockConnectivityService extends Mock implements ConnectivityService {}

void main() {
  late PerformSyncUseCase performSyncUseCase;
  late PerformOverrideUseCase performOverrideUseCase;
  late MockBluetoothRepository mockBluetoothRepository;
  late MockUserRepository mockUserRepository;
  late MockItemRepository mockItemRepository;
  late MockCategoryRepository mockCategoryRepository;
  late MockConnectivityService mockConnectivityService;

  setUpAll(() {
    registerFallbackValue(PairedDevice(
      deviceInstanceId: 'test',
      deviceName: 'Test Device',
      pairedAt: DateTime.now(),
    ));
  });

  setUp(() {
    mockBluetoothRepository = MockBluetoothRepository();
    mockUserRepository = MockUserRepository();
    mockItemRepository = MockItemRepository();
    mockCategoryRepository = MockCategoryRepository();
    mockConnectivityService = MockConnectivityService();

    performSyncUseCase = PerformSyncUseCase(
      mockBluetoothRepository,
      mockUserRepository,
      mockConnectivityService,
    );

    performOverrideUseCase = PerformOverrideUseCase(
      mockBluetoothRepository,
      mockUserRepository,
      mockItemRepository,
      mockCategoryRepository,
      mockConnectivityService,
    );
  });

  const tDeviceId = 'test-device-id';
  const tUserId = 'test-user-id';
  const tDeviceInstanceId = 'device-instance-123';

  final tUser = User(
    id: tUserId,
    email: 'test@test.com',
    lastSelectedDeviceItemId: 0,
    pairedDevices: const [],
  );

  final tUserWithDevice = User(
    id: tUserId,
    email: 'test@test.com',
    lastSelectedDeviceItemId: 0,
    pairedDevices: [
      PairedDevice(
        deviceInstanceId: tDeviceInstanceId,
        deviceName: 'Traxelos Device',
        pairedAt: DateTime.now(),
      ),
    ],
  );

  group('PerformSyncUseCase', () {
    group('performSync', () {
      test('should return NoInternetFailure when no internet connection', () async {
        // arrange
        when(() => mockConnectivityService.hasInternetConnection())
            .thenAnswer((_) async => false);

        // act
        final result = await performSyncUseCase(
          const PerformSyncParams(deviceId: tDeviceId),
        );

        // assert
        expect(result.isLeft(), true);
        result.fold(
          (failure) => expect(failure, isA<NoInternetFailure>()),
          (_) => fail('Should return failure'),
        );
      });

      test('should return NotAuthenticatedFailure when user not logged in', () async {
        // arrange
        when(() => mockConnectivityService.hasInternetConnection())
            .thenAnswer((_) async => true);
        when(() => mockUserRepository.getCurrentUser())
            .thenAnswer((_) async => const Left(AuthFailure('Not authenticated')));

        // act
        final result = await performSyncUseCase(
          const PerformSyncParams(deviceId: tDeviceId),
        );

        // assert
        expect(result.isLeft(), true);
        result.fold(
          (failure) => expect(failure, isA<NotAuthenticatedFailure>()),
          (_) => fail('Should return failure'),
        );
      });

      test('should send handshake with uid', () async {
        // arrange
        when(() => mockConnectivityService.hasInternetConnection())
            .thenAnswer((_) async => true);
        when(() => mockUserRepository.getCurrentUser())
            .thenAnswer((_) async => Right(tUserWithDevice));
        when(() => mockBluetoothRepository.sendHandshake(
          deviceId: tDeviceId,
          uid: tUserId,
        )).thenAnswer((_) async => const Right(HandshakeResult(
          status: SyncStatus.inSync,
          deviceInstanceId: tDeviceInstanceId,
        )));

        // act
        await performSyncUseCase(
          const PerformSyncParams(deviceId: tDeviceId),
        );

        // assert
        verify(() => mockBluetoothRepository.sendHandshake(
          deviceId: tDeviceId,
          uid: tUserId,
        )).called(1);
      });

      test('should return WrongAccountFailure when device paired to another account', () async {
        // arrange
        when(() => mockConnectivityService.hasInternetConnection())
            .thenAnswer((_) async => true);
        when(() => mockUserRepository.getCurrentUser())
            .thenAnswer((_) async => Right(tUser));
        when(() => mockBluetoothRepository.sendHandshake(
          deviceId: tDeviceId,
          uid: tUserId,
        )).thenAnswer((_) async => const Right(HandshakeResult(
          status: SyncStatus.wrongAccount,
          deviceInstanceId: tDeviceInstanceId,
        )));

        // act
        final result = await performSyncUseCase(
          const PerformSyncParams(deviceId: tDeviceId),
        );

        // assert
        expect(result.isLeft(), true);
        result.fold(
          (failure) => expect(failure, isA<WrongAccountFailure>()),
          (_) => fail('Should return failure'),
        );
      });

      test('should return DeviceLimitFailure when 10 devices already paired', () async {
        // arrange
        final userWith10Devices = User(
          id: tUserId,
          email: 'test@test.com',
          lastSelectedDeviceItemId: 0,
          pairedDevices: List.generate(
            10,
            (i) => PairedDevice(
              deviceInstanceId: 'device-$i',
              deviceName: 'Device $i',
              pairedAt: DateTime.now(),
            ),
          ),
        );

        when(() => mockConnectivityService.hasInternetConnection())
            .thenAnswer((_) async => true);
        when(() => mockUserRepository.getCurrentUser())
            .thenAnswer((_) async => Right(userWith10Devices));
        when(() => mockBluetoothRepository.sendHandshake(
          deviceId: tDeviceId,
          uid: tUserId,
        )).thenAnswer((_) async => const Right(HandshakeResult(
          status: SyncStatus.inSync,
          deviceInstanceId: 'new-device',
        )));

        // act
        final result = await performSyncUseCase(
          const PerformSyncParams(deviceId: tDeviceId),
        );

        // assert
        expect(result.isLeft(), true);
        result.fold(
          (failure) => expect(failure, isA<DeviceLimitFailure>()),
          (_) => fail('Should return failure'),
        );
      });

      test('should add new device to paired list when not already paired', () async {
        // arrange
        when(() => mockConnectivityService.hasInternetConnection())
            .thenAnswer((_) async => true);
        when(() => mockUserRepository.getCurrentUser())
            .thenAnswer((_) async => Right(tUser)); // User has no devices
        when(() => mockBluetoothRepository.sendHandshake(
          deviceId: tDeviceId,
          uid: tUserId,
        )).thenAnswer((_) async => const Right(HandshakeResult(
          status: SyncStatus.inSync,
          deviceInstanceId: tDeviceInstanceId,
        )));
        when(() => mockUserRepository.addPairedDevice(any()))
            .thenAnswer((_) async => const Right(null));

        // act
        await performSyncUseCase(
          const PerformSyncParams(deviceId: tDeviceId),
        );

        // assert
        verify(() => mockUserRepository.addPairedDevice(any())).called(1);
      });

      test('should return success immediately without Firestore update', () async {
        // arrange
        when(() => mockConnectivityService.hasInternetConnection())
            .thenAnswer((_) async => true);
        when(() => mockUserRepository.getCurrentUser())
            .thenAnswer((_) async => Right(tUserWithDevice));
        when(() => mockBluetoothRepository.sendHandshake(
          deviceId: tDeviceId,
          uid: tUserId,
        )).thenAnswer((_) async => const Right(HandshakeResult(
          status: SyncStatus.inSync,
          deviceInstanceId: tDeviceInstanceId,
        )));

        // act
        final result = await performSyncUseCase(
          const PerformSyncParams(deviceId: tDeviceId),
        );

        // assert
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should succeed'),
          (syncResult) => expect(syncResult.type, SyncResultType.success),
        );
        // No Firestore update should happen during normal sync (only override)
        verifyNever(() => mockUserRepository.updateLastSelectedItem(
          lastSelectedDeviceItemId: any(named: 'lastSelectedDeviceItemId'),
        ));
      });
    });
  });

  group('PerformOverrideUseCase', () {
    final tItems = [
      Item(
        id: 'item-1',
        name: 'Test Item 1',
        count: 10,
        todayCount: 5,
        incrementBy: 1,
        reminder: ReminderType.none,
        reminderValue: 0,
        lastUpdated: DateTime.now(),
        userId: tUserId,
        deviceItemId: 0,
      ),
      Item(
        id: 'item-2',
        name: 'Test Item 2',
        count: 20,
        todayCount: 10,
        incrementBy: 1,
        reminder: ReminderType.none,
        reminderValue: 0,
        lastUpdated: DateTime.now(),
        userId: tUserId,
        deviceItemId: 1,
      ),
    ];

    final tCategories = <Category>[
      Category(
        id: 'cat-1',
        name: 'Category 1',
        userId: tUserId,
        order: 0,
        createdAt: DateTime.now(),
        lastUpdated: DateTime.now(),
      ),
    ];

    test('should return NoInternetFailure when no internet', () async {
      // arrange
      when(() => mockConnectivityService.hasInternetConnection())
          .thenAnswer((_) async => false);

      // act
      final result = await performOverrideUseCase(
        const PerformOverrideParams(deviceId: tDeviceId, deviceInstanceId: tDeviceInstanceId),
      );

      // assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<NoInternetFailure>()),
        (_) => fail('Should return failure'),
      );
    });

    test('should return TooManyItemsFailure when >100 items', () async {
      // arrange
      final tooManyItems = List.generate(
        101,
        (i) => Item(
          id: 'item-$i',
          name: 'Item $i',
          count: i,
          todayCount: 0,
          incrementBy: 1,
          reminder: ReminderType.none,
          reminderValue: 0,
          lastUpdated: DateTime.now(),
          userId: tUserId,
          deviceItemId: i,
        ),
      );

      when(() => mockConnectivityService.hasInternetConnection())
          .thenAnswer((_) async => true);
      when(() => mockUserRepository.getCurrentUser())
          .thenAnswer((_) async => Right(tUser));
      when(() => mockItemRepository.getItems(tUserId))
          .thenAnswer((_) async => Right(tooManyItems));

      // act
      final result = await performOverrideUseCase(
        const PerformOverrideParams(deviceId: tDeviceId, deviceInstanceId: tDeviceInstanceId),
      );

      // assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) {
          expect(failure, isA<TooManyItemsFailure>());
          expect((failure as TooManyItemsFailure).itemCount, 101);
        },
        (_) => fail('Should return failure'),
      );
    });

    test('should successfully perform override', () async {
      // arrange
      when(() => mockConnectivityService.hasInternetConnection())
          .thenAnswer((_) async => true);
      when(() => mockUserRepository.getCurrentUser())
          .thenAnswer((_) async => Right(tUser));
      when(() => mockItemRepository.getItems(tUserId))
          .thenAnswer((_) async => Right(tItems));
      when(() => mockCategoryRepository.getCategories(tUserId))
          .thenAnswer((_) async => Right(tCategories));
      when(() => mockBluetoothRepository.sendOverrideChunked(
        deviceId: tDeviceId,
        uid: tUserId,
        selectedId: tUser.lastSelectedDeviceItemId,
        items: tItems,
        categoryNames: any(named: 'categoryNames'),
      )).thenAnswer((_) async => const Right(OverrideResult(
        status: 'override_complete',
      )));
      when(() => mockUserRepository.updateLastSelectedItem(
        lastSelectedDeviceItemId: tUser.lastSelectedDeviceItemId,
      )).thenAnswer((_) async => const Right(null));
      when(() => mockUserRepository.addPairedDevice(any()))
          .thenAnswer((_) async => const Right(null));

      // act
      final result = await performOverrideUseCase(
        const PerformOverrideParams(deviceId: tDeviceId, deviceInstanceId: tDeviceInstanceId),
      );

      // assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should succeed'),
        (syncResult) => expect(syncResult.type, SyncResultType.overrideComplete),
      );
      verify(() => mockBluetoothRepository.sendOverrideChunked(
        deviceId: tDeviceId,
        uid: tUserId,
        selectedId: tUser.lastSelectedDeviceItemId,
        items: tItems,
        categoryNames: any(named: 'categoryNames'),
      )).called(1);
    });

    test('should exclude items claimed by other devices from override payload', () async {
      // arrange — item-2 is claimed by a different device
      final itemClaimedByOther = Item(
        id: 'item-2',
        name: 'Test Item 2',
        count: 20,
        todayCount: 10,
        incrementBy: 1,
        reminder: ReminderType.none,
        reminderValue: 0,
        lastUpdated: DateTime.now(),
        userId: tUserId,
        deviceItemId: 1,
        claimedBy: 'other-device-999',
      );
      final itemsWithClaim = [tItems[0], itemClaimedByOther];

      when(() => mockConnectivityService.hasInternetConnection())
          .thenAnswer((_) async => true);
      when(() => mockUserRepository.getCurrentUser())
          .thenAnswer((_) async => Right(tUser));
      when(() => mockItemRepository.getItems(tUserId))
          .thenAnswer((_) async => Right(itemsWithClaim));
      when(() => mockCategoryRepository.getCategories(tUserId))
          .thenAnswer((_) async => Right(tCategories));
      when(() => mockBluetoothRepository.sendOverrideChunked(
        deviceId: any(named: 'deviceId'),
        uid: any(named: 'uid'),
        selectedId: any(named: 'selectedId'),
        items: any(named: 'items'),
        categoryNames: any(named: 'categoryNames'),
      )).thenAnswer((_) async => const Right(OverrideResult(
        status: 'override_complete',
      )));
      when(() => mockUserRepository.updateLastSelectedItem(
        lastSelectedDeviceItemId: any(named: 'lastSelectedDeviceItemId'),
      )).thenAnswer((_) async => const Right(null));
      when(() => mockUserRepository.addPairedDevice(any()))
          .thenAnswer((_) async => const Right(null));

      // act
      final result = await performOverrideUseCase(
        const PerformOverrideParams(deviceId: tDeviceId, deviceInstanceId: tDeviceInstanceId),
      );

      // assert — override succeeds
      expect(result.isRight(), true);

      // Verify that only item-1 was sent (item-2 claimed by other device excluded)
      final captured = verify(() => mockBluetoothRepository.sendOverrideChunked(
        deviceId: any(named: 'deviceId'),
        uid: any(named: 'uid'),
        selectedId: any(named: 'selectedId'),
        items: captureAny(named: 'items'),
        categoryNames: any(named: 'categoryNames'),
      )).captured;
      final sentItems = captured.first as List<Item>;
      expect(sentItems.length, 1);
      expect(sentItems.first.id, 'item-1');
    });

    test('should return OverrideFailure when device returns error', () async {
      // arrange
      when(() => mockConnectivityService.hasInternetConnection())
          .thenAnswer((_) async => true);
      when(() => mockUserRepository.getCurrentUser())
          .thenAnswer((_) async => Right(tUser));
      when(() => mockItemRepository.getItems(tUserId))
          .thenAnswer((_) async => Right(tItems));
      when(() => mockCategoryRepository.getCategories(tUserId))
          .thenAnswer((_) async => Right(tCategories));
      when(() => mockBluetoothRepository.sendOverrideChunked(
        deviceId: any(named: 'deviceId'),
        uid: any(named: 'uid'),
        selectedId: any(named: 'selectedId'),
        items: any(named: 'items'),
        categoryNames: any(named: 'categoryNames'),
      )).thenAnswer((_) async => const Right(OverrideResult(
        status: 'error',
        message: 'missing_chunks',
      )));

      // act
      final result = await performOverrideUseCase(
        const PerformOverrideParams(deviceId: tDeviceId, deviceInstanceId: tDeviceInstanceId),
      );

      // assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) {
          expect(failure, isA<OverrideFailure>());
          expect((failure as OverrideFailure).deviceMessage, 'missing_chunks');
        },
        (_) => fail('Should return failure'),
      );
    });

    test('should retry Firestore update on failure', () async {
      // arrange
      when(() => mockConnectivityService.hasInternetConnection())
          .thenAnswer((_) async => true);
      when(() => mockUserRepository.getCurrentUser())
          .thenAnswer((_) async => Right(tUser));
      when(() => mockItemRepository.getItems(tUserId))
          .thenAnswer((_) async => Right(tItems));
      when(() => mockCategoryRepository.getCategories(tUserId))
          .thenAnswer((_) async => Right(tCategories));
      when(() => mockBluetoothRepository.sendOverrideChunked(
        deviceId: any(named: 'deviceId'),
        uid: any(named: 'uid'),
        selectedId: any(named: 'selectedId'),
        items: any(named: 'items'),
        categoryNames: any(named: 'categoryNames'),
      )).thenAnswer((_) async => const Right(OverrideResult(
        status: 'override_complete',
      )));

      var updateAttempt = 0;
      when(() => mockUserRepository.updateLastSelectedItem(
        lastSelectedDeviceItemId: any(named: 'lastSelectedDeviceItemId'),
      )).thenAnswer((_) async {
        updateAttempt++;
        if (updateAttempt < 3) {
          return const Left(ServerFailure('Network error'));
        }
        return const Right(null);
      });
      when(() => mockUserRepository.addPairedDevice(any()))
          .thenAnswer((_) async => const Right(null));

      // act
      final result = await performOverrideUseCase(
        const PerformOverrideParams(deviceId: tDeviceId, deviceInstanceId: tDeviceInstanceId),
      );

      // assert
      expect(result.isRight(), true);
      // Should have been called 3 times (2 failures, then success)
      verify(() => mockUserRepository.updateLastSelectedItem(
        lastSelectedDeviceItemId: any(named: 'lastSelectedDeviceItemId'),
      )).called(3);
    });

    test('should return FirestoreUpdateFailure after max retries', () async {
      // arrange
      when(() => mockConnectivityService.hasInternetConnection())
          .thenAnswer((_) async => true);
      when(() => mockUserRepository.getCurrentUser())
          .thenAnswer((_) async => Right(tUser));
      when(() => mockItemRepository.getItems(tUserId))
          .thenAnswer((_) async => Right(tItems));
      when(() => mockCategoryRepository.getCategories(tUserId))
          .thenAnswer((_) async => Right(tCategories));
      when(() => mockBluetoothRepository.sendOverrideChunked(
        deviceId: any(named: 'deviceId'),
        uid: any(named: 'uid'),
        selectedId: any(named: 'selectedId'),
        items: any(named: 'items'),
        categoryNames: any(named: 'categoryNames'),
      )).thenAnswer((_) async => const Right(OverrideResult(
        status: 'override_complete',
      )));
      when(() => mockUserRepository.updateLastSelectedItem(
        lastSelectedDeviceItemId: any(named: 'lastSelectedDeviceItemId'),
      )).thenAnswer((_) async => const Left(ServerFailure('Network error')));

      // act
      final result = await performOverrideUseCase(
        const PerformOverrideParams(deviceId: tDeviceId, deviceInstanceId: tDeviceInstanceId),
      );

      // assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<FirestoreUpdateFailure>()),
        (_) => fail('Should return failure'),
      );
      // Should have been called 3 times (all failures)
      verify(() => mockUserRepository.updateLastSelectedItem(
        lastSelectedDeviceItemId: any(named: 'lastSelectedDeviceItemId'),
      )).called(3);
    });
  });
}
