import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:traxelos/core/error/failures.dart';
import 'package:traxelos/features/auth/data/repositories/user_repository_impl.dart';
import 'package:traxelos/features/auth/domain/entities/user.dart';
import 'package:traxelos/features/bluetooth/domain/entities/paired_device.dart';

// Mocks
class MockFirebaseAuth extends Mock implements firebase.FirebaseAuth {}

class MockFirebaseUser extends Mock implements firebase.User {}

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockCollectionReference<T> extends Mock
    implements CollectionReference<T> {}

class MockDocumentReference<T> extends Mock implements DocumentReference<T> {}

class MockDocumentSnapshot<T> extends Mock implements DocumentSnapshot<T> {}

void main() {
  late UserRepositoryImpl repository;
  late MockFirebaseAuth mockAuth;
  late MockFirebaseFirestore mockFirestore;
  late MockFirebaseUser mockFirebaseUser;
  late MockCollectionReference<Map<String, dynamic>> mockUsersCollection;
  late MockDocumentReference<Map<String, dynamic>> mockUserDocRef;
  late MockDocumentSnapshot<Map<String, dynamic>> mockUserDocSnapshot;

  const testUserId = 'test_user_123';
  const testEmail = 'test@example.com';

  setUpAll(() {
    // Register fallback values for mocktail
    registerFallbackValue(const GetOptions());
    registerFallbackValue(SetOptions(merge: true));
  });

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockFirestore = MockFirebaseFirestore();
    mockFirebaseUser = MockFirebaseUser();
    mockUsersCollection = MockCollectionReference<Map<String, dynamic>>();
    mockUserDocRef = MockDocumentReference<Map<String, dynamic>>();
    mockUserDocSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();

    // Setup common mocks
    when(() => mockAuth.currentUser).thenReturn(mockFirebaseUser);
    when(() => mockFirebaseUser.uid).thenReturn(testUserId);
    when(() => mockFirebaseUser.email).thenReturn(testEmail);
    when(() => mockFirebaseUser.displayName).thenReturn('Test User');
    when(() => mockFirebaseUser.photoURL).thenReturn(null);
    when(() => mockFirebaseUser.emailVerified).thenReturn(true);

    when(() => mockFirestore.collection('users'))
        .thenReturn(mockUsersCollection);
    when(() => mockUsersCollection.doc(testUserId)).thenReturn(mockUserDocRef);

    repository = UserRepositoryImpl(
      firebaseAuth: mockAuth,
      firestore: mockFirestore,
    );
  });

  group('getCurrentUser', () {
    test('should return User with Firestore data when user is authenticated',
        () async {
      // Arrange
      when(() => mockUserDocRef.get())
          .thenAnswer((_) async => mockUserDocSnapshot);
      when(() => mockUserDocSnapshot.exists).thenReturn(true);
      when(() => mockUserDocSnapshot.data()).thenReturn({
        'last_selected_device_item_id': 3,
        'paired_devices': [
          {
            'device_instance_id': 'device-123',
            'device_name': 'My Device',
            'paired_at': Timestamp.fromDate(DateTime(2024, 1, 1)),
          }
        ],
      });

      // Act
      final result = await repository.getCurrentUser();

      // Assert
      expect(result, isA<Right<Failure, User>>());
      result.fold(
        (failure) => fail('Should not return failure'),
        (user) {
          expect(user.id, testUserId);
          expect(user.email, testEmail);
          expect(user.lastSelectedDeviceItemId, 3);
          expect(user.pairedDevices.length, 1);
          expect(user.pairedDevices[0].deviceInstanceId, 'device-123');
          expect(user.pairedDevices[0].deviceName, 'My Device');
        },
      );
    });

    test(
        'should return User with default values when Firestore document does not exist',
        () async {
      // Arrange
      when(() => mockUserDocRef.get())
          .thenAnswer((_) async => mockUserDocSnapshot);
      when(() => mockUserDocSnapshot.exists).thenReturn(false);

      // Act
      final result = await repository.getCurrentUser();

      // Assert
      expect(result, isA<Right<Failure, User>>());
      result.fold(
        (failure) => fail('Should not return failure'),
        (user) {
          expect(user.id, testUserId);
          expect(user.lastSelectedDeviceItemId, -1);
          expect(user.pairedDevices, isEmpty);
        },
      );
    });

    test('should return AuthFailure when not authenticated', () async {
      // Arrange
      when(() => mockAuth.currentUser).thenReturn(null);

      // Act
      final result = await repository.getCurrentUser();

      // Assert
      expect(result, isA<Left<Failure, User>>());
      result.fold(
        (failure) {
          expect(failure, isA<AuthFailure>());
          expect(failure.message, 'Not authenticated');
        },
        (user) => fail('Should not return user'),
      );
    });
  });

  group('updateLastSelectedItem', () {
    test('should update last selected item in Firestore', () async {
      // Arrange
      when(() => mockUserDocRef.set(any(), any()))
          .thenAnswer((_) async => {});

      // Act
      final result = await repository.updateLastSelectedItem(
        lastSelectedDeviceItemId: 5,
      );

      // Assert
      expect(result, isA<Right<Failure, void>>());
      verify(() => mockUserDocRef.set(
            {
              'last_selected_device_item_id': 5,
            },
            any(),
          )).called(1);
    });

    test('should return AuthFailure when not authenticated', () async {
      // Arrange
      when(() => mockAuth.currentUser).thenReturn(null);

      // Act
      final result = await repository.updateLastSelectedItem(
        lastSelectedDeviceItemId: 5,
      );

      // Assert
      expect(result, isA<Left<Failure, void>>());
      result.fold(
        (failure) => expect(failure, isA<AuthFailure>()),
        (_) => fail('Should not succeed'),
      );
    });
  });

  group('addPairedDevice', () {
    final testDevice = PairedDevice(
      deviceInstanceId: 'new-device-123',
      deviceName: 'New Device',
      pairedAt: DateTime(2024, 1, 15),
    );

    // Note: Transaction-based tests require integration testing or more complex
    // mock setup. The following tests verify the auth check and basic error handling.
    // Full transaction behavior should be tested in integration tests.

    test('should return AuthFailure when not authenticated', () async {
      // Arrange
      when(() => mockAuth.currentUser).thenReturn(null);

      // Act
      final result = await repository.addPairedDevice(testDevice);

      // Assert
      expect(result, isA<Left<Failure, void>>());
      result.fold(
        (failure) => expect(failure, isA<AuthFailure>()),
        (_) => fail('Should not succeed'),
      );
    });

    // Note: Testing transaction success/failure requires integration tests
    // since mocking Firestore transactions is complex. The auth check test
    // above verifies the basic error handling path.
  });

  group('removePairedDevice', () {
    test('should remove device from list', () async {
      // Arrange
      when(() => mockUserDocRef.get())
          .thenAnswer((_) async => mockUserDocSnapshot);
      when(() => mockUserDocSnapshot.exists).thenReturn(true);
      when(() => mockUserDocSnapshot.data()).thenReturn({
        'paired_devices': [
          {
            'device_instance_id': 'device-to-remove',
            'device_name': 'Device 1',
            'paired_at': Timestamp.now(),
          },
          {
            'device_instance_id': 'device-to-keep',
            'device_name': 'Device 2',
            'paired_at': Timestamp.now(),
          },
        ],
      });
      when(() => mockUserDocRef.update(any())).thenAnswer((_) async => {});

      // Act
      final result = await repository.removePairedDevice('device-to-remove');

      // Assert
      expect(result, isA<Right<Failure, void>>());
      verify(() => mockUserDocRef.update(any())).called(1);
    });

    test('should return success when document does not exist', () async {
      // Arrange
      when(() => mockUserDocRef.get())
          .thenAnswer((_) async => mockUserDocSnapshot);
      when(() => mockUserDocSnapshot.exists).thenReturn(false);

      // Act
      final result = await repository.removePairedDevice('any-device');

      // Assert
      expect(result, isA<Right<Failure, void>>());
    });

    test('should return AuthFailure when not authenticated', () async {
      // Arrange
      when(() => mockAuth.currentUser).thenReturn(null);

      // Act
      final result = await repository.removePairedDevice('any-device');

      // Assert
      expect(result, isA<Left<Failure, void>>());
      result.fold(
        (failure) => expect(failure, isA<AuthFailure>()),
        (_) => fail('Should not succeed'),
      );
    });
  });

  group('updateDeviceName', () {
    test('should update device name', () async {
      // Arrange
      when(() => mockUserDocRef.get())
          .thenAnswer((_) async => mockUserDocSnapshot);
      when(() => mockUserDocSnapshot.exists).thenReturn(true);
      when(() => mockUserDocSnapshot.data()).thenReturn({
        'paired_devices': [
          {
            'device_instance_id': 'device-123',
            'device_name': 'Old Name',
            'paired_at': Timestamp.now(),
          },
        ],
      });
      when(() => mockUserDocRef.update(any())).thenAnswer((_) async => {});

      // Act
      final result = await repository.updateDeviceName('device-123', 'New Name');

      // Assert
      expect(result, isA<Right<Failure, void>>());
      verify(() => mockUserDocRef.update(any())).called(1);
    });

    test('should return ValidationFailure when device not found', () async {
      // Arrange
      when(() => mockUserDocRef.get())
          .thenAnswer((_) async => mockUserDocSnapshot);
      when(() => mockUserDocSnapshot.exists).thenReturn(true);
      when(() => mockUserDocSnapshot.data()).thenReturn({
        'paired_devices': [],
      });

      // Act
      final result =
          await repository.updateDeviceName('non-existent', 'New Name');

      // Assert
      expect(result, isA<Left<Failure, void>>());
      result.fold(
        (failure) {
          expect(failure, isA<ValidationFailure>());
          expect(failure.message, 'Device not found');
        },
        (_) => fail('Should not succeed'),
      );
    });

    test('should return ValidationFailure when document does not exist',
        () async {
      // Arrange
      when(() => mockUserDocRef.get())
          .thenAnswer((_) async => mockUserDocSnapshot);
      when(() => mockUserDocSnapshot.exists).thenReturn(false);

      // Act
      final result =
          await repository.updateDeviceName('any-device', 'New Name');

      // Assert
      expect(result, isA<Left<Failure, void>>());
      result.fold(
        (failure) => expect(failure, isA<ValidationFailure>()),
        (_) => fail('Should not succeed'),
      );
    });

    test('should return AuthFailure when not authenticated', () async {
      // Arrange
      when(() => mockAuth.currentUser).thenReturn(null);

      // Act
      final result =
          await repository.updateDeviceName('any-device', 'New Name');

      // Assert
      expect(result, isA<Left<Failure, void>>());
      result.fold(
        (failure) => expect(failure, isA<AuthFailure>()),
        (_) => fail('Should not succeed'),
      );
    });
  });
}
