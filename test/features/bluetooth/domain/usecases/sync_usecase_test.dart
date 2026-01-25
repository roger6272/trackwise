import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:trackwise/core/error/failures.dart';
import 'package:trackwise/core/services/connectivity_service.dart';
import 'package:trackwise/features/auth/domain/entities/user.dart';
import 'package:trackwise/features/auth/domain/repositories/user_repository.dart';
import 'package:trackwise/features/bluetooth/domain/entities/paired_device.dart';
import 'package:trackwise/features/bluetooth/domain/entities/sync_state.dart';
import 'package:trackwise/features/bluetooth/domain/failures/sync_failures.dart';
import 'package:trackwise/features/bluetooth/domain/repositories/bluetooth_repository.dart';
import 'package:trackwise/features/bluetooth/domain/usecases/sync_usecase.dart';
import 'package:trackwise/features/categories/domain/entities/category.dart';
import 'package:trackwise/features/categories/domain/repositories/category_repository.dart';
import 'package:trackwise/features/items/domain/entities/item.dart';
import 'package:trackwise/features/items/domain/repositories/item_repository.dart';

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
      mockItemRepository,
      mockCategoryRepository,
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
  const tSyncSeq = 5;

  final tUser = User(
    id: tUserId,
    email: 'test@test.com',
    syncSequenceNo: tSyncSeq,
    lastSelectedDeviceItemId: 0,
    pairedDevices: const [],
  );

  final tUserWithDevice = User(
    id: tUserId,
    email: 'test@test.com',
    syncSequenceNo: tSyncSeq,
    lastSelectedDeviceItemId: 0,
    pairedDevices: [
      PairedDevice(
        deviceInstanceId: tDeviceInstanceId,
        deviceName: 'Trackwise Device',
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

      test('should return WrongAccountFailure when device paired to another account', () async {
        // arrange
        when(() => mockConnectivityService.hasInternetConnection())
            .thenAnswer((_) async => true);
        when(() => mockUserRepository.getCurrentUser())
            .thenAnswer((_) async => Right(tUser));
        when(() => mockUserRepository.fetchSyncSequenceFromServer())
            .thenAnswer((_) async => const Right(tSyncSeq));
        when(() => mockBluetoothRepository.sendHandshake(
          uid: tUserId,
          syncSeq: tSyncSeq,
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
          syncSequenceNo: tSyncSeq,
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
        when(() => mockUserRepository.fetchSyncSequenceFromServer())
            .thenAnswer((_) async => const Right(tSyncSeq));
        when(() => mockBluetoothRepository.sendHandshake(
          uid: tUserId,
          syncSeq: tSyncSeq,
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

      test('should return SyncConflictFailure when sync_seq mismatch', () async {
        // arrange
        when(() => mockConnectivityService.hasInternetConnection())
            .thenAnswer((_) async => true);
        when(() => mockUserRepository.getCurrentUser())
            .thenAnswer((_) async => Right(tUserWithDevice));
        when(() => mockUserRepository.fetchSyncSequenceFromServer())
            .thenAnswer((_) async => const Right(tSyncSeq));
        when(() => mockBluetoothRepository.sendHandshake(
          uid: tUserId,
          syncSeq: tSyncSeq,
        )).thenAnswer((_) async => const Right(HandshakeResult(
          status: SyncStatus.conflict,
          deviceInstanceId: tDeviceInstanceId,
          deviceSyncSeq: 3,
        )));

        // act
        final result = await performSyncUseCase(
          const PerformSyncParams(deviceId: tDeviceId),
        );

        // assert
        expect(result.isLeft(), true);
        result.fold(
          (failure) {
            expect(failure, isA<SyncConflictFailure>());
            final syncFailure = failure as SyncConflictFailure;
            expect(syncFailure.deviceSyncSeq, 3);
            expect(syncFailure.appSyncSeq, tSyncSeq);
          },
          (_) => fail('Should return failure'),
        );
      });

      test('should add new device to paired list when not already paired', () async {
        // arrange
        when(() => mockConnectivityService.hasInternetConnection())
            .thenAnswer((_) async => true);
        when(() => mockUserRepository.getCurrentUser())
            .thenAnswer((_) async => Right(tUser)); // User has no devices
        when(() => mockUserRepository.fetchSyncSequenceFromServer())
            .thenAnswer((_) async => const Right(tSyncSeq));
        when(() => mockBluetoothRepository.sendHandshake(
          uid: tUserId,
          syncSeq: tSyncSeq,
        )).thenAnswer((_) async => const Right(HandshakeResult(
          status: SyncStatus.inSync,
          deviceInstanceId: tDeviceInstanceId,
        )));
        when(() => mockUserRepository.addPairedDevice(any()))
            .thenAnswer((_) async => const Right(null));
        when(() => mockBluetoothRepository.sendSyncComplete(tSyncSeq + 1))
            .thenAnswer((_) async => const Right(SyncCompleteResult(status: 'seq_updated')));
        when(() => mockUserRepository.updateSyncState(
          syncSequenceNo: any(named: 'syncSequenceNo'),
          lastSelectedDeviceItemId: any(named: 'lastSelectedDeviceItemId'),
        )).thenAnswer((_) async => const Right(null));

        // act
        await performSyncUseCase(
          const PerformSyncParams(deviceId: tDeviceId),
        );

        // assert
        verify(() => mockUserRepository.addPairedDevice(any())).called(1);
      });

      test('should perform normal sync when in_sync status', () async {
        // arrange
        when(() => mockConnectivityService.hasInternetConnection())
            .thenAnswer((_) async => true);
        when(() => mockUserRepository.getCurrentUser())
            .thenAnswer((_) async => Right(tUserWithDevice));
        when(() => mockUserRepository.fetchSyncSequenceFromServer())
            .thenAnswer((_) async => const Right(tSyncSeq));
        when(() => mockBluetoothRepository.sendHandshake(
          uid: tUserId,
          syncSeq: tSyncSeq,
        )).thenAnswer((_) async => const Right(HandshakeResult(
          status: SyncStatus.inSync,
          deviceInstanceId: tDeviceInstanceId,
        )));
        when(() => mockBluetoothRepository.sendSyncComplete(tSyncSeq + 1))
            .thenAnswer((_) async => const Right(SyncCompleteResult(status: 'seq_updated')));
        when(() => mockUserRepository.updateSyncState(
          syncSequenceNo: tSyncSeq + 1,
          lastSelectedDeviceItemId: -1,
        )).thenAnswer((_) async => const Right(null));

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
        verify(() => mockBluetoothRepository.sendSyncComplete(tSyncSeq + 1)).called(1);
        verify(() => mockUserRepository.updateSyncState(
          syncSequenceNo: tSyncSeq + 1,
          lastSelectedDeviceItemId: -1,
        )).called(1);
      });

      test('should return SyncCompleteNotAcknowledgedFailure when device does not ack', () async {
        // arrange
        when(() => mockConnectivityService.hasInternetConnection())
            .thenAnswer((_) async => true);
        when(() => mockUserRepository.getCurrentUser())
            .thenAnswer((_) async => Right(tUserWithDevice));
        when(() => mockUserRepository.fetchSyncSequenceFromServer())
            .thenAnswer((_) async => const Right(tSyncSeq));
        when(() => mockBluetoothRepository.sendHandshake(
          uid: tUserId,
          syncSeq: tSyncSeq,
        )).thenAnswer((_) async => const Right(HandshakeResult(
          status: SyncStatus.inSync,
          deviceInstanceId: tDeviceInstanceId,
        )));
        when(() => mockBluetoothRepository.sendSyncComplete(tSyncSeq + 1))
            .thenAnswer((_) async => const Right(SyncCompleteResult(status: 'error')));

        // act
        final result = await performSyncUseCase(
          const PerformSyncParams(deviceId: tDeviceId),
        );

        // assert
        expect(result.isLeft(), true);
        result.fold(
          (failure) => expect(failure, isA<SyncCompleteNotAcknowledgedFailure>()),
          (_) => fail('Should return failure'),
        );
      });

      test('should retry Firestore update on failure', () async {
        // arrange
        when(() => mockConnectivityService.hasInternetConnection())
            .thenAnswer((_) async => true);
        when(() => mockUserRepository.getCurrentUser())
            .thenAnswer((_) async => Right(tUserWithDevice));
        when(() => mockUserRepository.fetchSyncSequenceFromServer())
            .thenAnswer((_) async => const Right(tSyncSeq));
        when(() => mockBluetoothRepository.sendHandshake(
          uid: tUserId,
          syncSeq: tSyncSeq,
        )).thenAnswer((_) async => const Right(HandshakeResult(
          status: SyncStatus.inSync,
          deviceInstanceId: tDeviceInstanceId,
        )));
        when(() => mockBluetoothRepository.sendSyncComplete(tSyncSeq + 1))
            .thenAnswer((_) async => const Right(SyncCompleteResult(status: 'seq_updated')));

        var updateAttempt = 0;
        when(() => mockUserRepository.updateSyncState(
          syncSequenceNo: any(named: 'syncSequenceNo'),
          lastSelectedDeviceItemId: any(named: 'lastSelectedDeviceItemId'),
        )).thenAnswer((_) async {
          updateAttempt++;
          if (updateAttempt < 2) {
            return const Left(ServerFailure('Network error'));
          }
          return const Right(null);
        });

        // act
        final result = await performSyncUseCase(
          const PerformSyncParams(deviceId: tDeviceId),
        );

        // assert
        expect(result.isRight(), true);
        verify(() => mockUserRepository.updateSyncState(
          syncSequenceNo: any(named: 'syncSequenceNo'),
          lastSelectedDeviceItemId: any(named: 'lastSelectedDeviceItemId'),
        )).called(2); // First failed, second succeeded
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
        const PerformOverrideParams(deviceId: tDeviceId),
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
        const PerformOverrideParams(deviceId: tDeviceId),
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
        syncSeq: tSyncSeq + 1,
        selectedId: tUser.lastSelectedDeviceItemId,
        items: tItems,
        categoryNames: any(named: 'categoryNames'),
      )).thenAnswer((_) async => const Right(OverrideResult(
        status: 'override_complete',
      )));
      when(() => mockUserRepository.updateSyncState(
        syncSequenceNo: tSyncSeq + 1,
        lastSelectedDeviceItemId: tUser.lastSelectedDeviceItemId,
      )).thenAnswer((_) async => const Right(null));

      // act
      final result = await performOverrideUseCase(
        const PerformOverrideParams(deviceId: tDeviceId),
      );

      // assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should succeed'),
        (syncResult) => expect(syncResult.type, SyncResultType.overrideComplete),
      );
      verify(() => mockBluetoothRepository.sendOverrideChunked(
        syncSeq: tSyncSeq + 1,
        selectedId: tUser.lastSelectedDeviceItemId,
        items: tItems,
        categoryNames: any(named: 'categoryNames'),
      )).called(1);
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
        syncSeq: any(named: 'syncSeq'),
        selectedId: any(named: 'selectedId'),
        items: any(named: 'items'),
        categoryNames: any(named: 'categoryNames'),
      )).thenAnswer((_) async => const Right(OverrideResult(
        status: 'error',
        message: 'missing_chunks',
      )));

      // act
      final result = await performOverrideUseCase(
        const PerformOverrideParams(deviceId: tDeviceId),
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
        syncSeq: any(named: 'syncSeq'),
        selectedId: any(named: 'selectedId'),
        items: any(named: 'items'),
        categoryNames: any(named: 'categoryNames'),
      )).thenAnswer((_) async => const Right(OverrideResult(
        status: 'override_complete',
      )));

      var updateAttempt = 0;
      when(() => mockUserRepository.updateSyncState(
        syncSequenceNo: any(named: 'syncSequenceNo'),
        lastSelectedDeviceItemId: any(named: 'lastSelectedDeviceItemId'),
      )).thenAnswer((_) async {
        updateAttempt++;
        if (updateAttempt < 3) {
          return const Left(ServerFailure('Network error'));
        }
        return const Right(null);
      });

      // act
      final result = await performOverrideUseCase(
        const PerformOverrideParams(deviceId: tDeviceId),
      );

      // assert
      expect(result.isRight(), true);
      // Should have been called 3 times (2 failures, then success)
      verify(() => mockUserRepository.updateSyncState(
        syncSequenceNo: any(named: 'syncSequenceNo'),
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
        syncSeq: any(named: 'syncSeq'),
        selectedId: any(named: 'selectedId'),
        items: any(named: 'items'),
        categoryNames: any(named: 'categoryNames'),
      )).thenAnswer((_) async => const Right(OverrideResult(
        status: 'override_complete',
      )));
      when(() => mockUserRepository.updateSyncState(
        syncSequenceNo: any(named: 'syncSequenceNo'),
        lastSelectedDeviceItemId: any(named: 'lastSelectedDeviceItemId'),
      )).thenAnswer((_) async => const Left(ServerFailure('Network error')));

      // act
      final result = await performOverrideUseCase(
        const PerformOverrideParams(deviceId: tDeviceId),
      );

      // assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<FirestoreUpdateFailure>()),
        (_) => fail('Should return failure'),
      );
      // Should have been called 3 times (all failures)
      verify(() => mockUserRepository.updateSyncState(
        syncSequenceNo: any(named: 'syncSequenceNo'),
        lastSelectedDeviceItemId: any(named: 'lastSelectedDeviceItemId'),
      )).called(3);
    });
  });
}
