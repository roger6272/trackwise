import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:trackwise/features/profile/data/models/user_profile_model.dart';
import 'package:trackwise/features/profile/domain/entities/user_profile.dart';

class MockFirebaseUser extends Mock implements firebase.User {}

class MockUserMetadata extends Mock implements firebase.UserMetadata {}

class MockDocumentSnapshot extends Mock implements DocumentSnapshot<Map<String, dynamic>> {}

void main() {
  group('UserProfileModel', () {
    group('fromFirebaseUser', () {
      test('should create UserProfileModel from Firebase User with all fields', () {
        // Arrange
        final mockUser = MockFirebaseUser();
        final mockMetadata = MockUserMetadata();
        final creationTime = DateTime(2024, 1, 1);
        final lastSignInTime = DateTime(2024, 1, 15);

        when(() => mockUser.uid).thenReturn('user_123');
        when(() => mockUser.email).thenReturn('test@example.com');
        when(() => mockUser.displayName).thenReturn('Test User');
        when(() => mockUser.photoURL).thenReturn('https://example.com/photo.jpg');
        when(() => mockUser.metadata).thenReturn(mockMetadata);
        when(() => mockMetadata.creationTime).thenReturn(creationTime);
        when(() => mockMetadata.lastSignInTime).thenReturn(lastSignInTime);

        // Act
        final result = UserProfileModel.fromFirebaseUser(mockUser);

        // Assert
        expect(result.userId, 'user_123');
        expect(result.email, 'test@example.com');
        expect(result.displayName, 'Test User');
        expect(result.photoUrl, 'https://example.com/photo.jpg');
        expect(result.createdAt, creationTime);
        expect(result.lastLogin, lastSignInTime);
      });

      test('should handle null email from Firebase User', () {
        // Arrange
        final mockUser = MockFirebaseUser();
        final mockMetadata = MockUserMetadata();

        when(() => mockUser.uid).thenReturn('user_456');
        when(() => mockUser.email).thenReturn(null);
        when(() => mockUser.displayName).thenReturn(null);
        when(() => mockUser.photoURL).thenReturn(null);
        when(() => mockUser.metadata).thenReturn(mockMetadata);
        when(() => mockMetadata.creationTime).thenReturn(null);
        when(() => mockMetadata.lastSignInTime).thenReturn(null);

        // Act
        final result = UserProfileModel.fromFirebaseUser(mockUser);

        // Assert
        expect(result.userId, 'user_456');
        expect(result.email, '');
        expect(result.displayName, isNull);
        expect(result.photoUrl, isNull);
      });
    });

    group('fromFirestore', () {
      test('should create UserProfileModel from Firestore document', () {
        // Arrange
        final mockDoc = MockDocumentSnapshot();
        when(() => mockDoc.id).thenReturn('user_123');
        when(() => mockDoc.data()).thenReturn({
          'email': 'test@example.com',
          'display_name': 'Test User',
          'photo_url': 'https://example.com/photo.jpg',
          'created_at': 1704067200000, // 2024-01-01
          'last_login': 1705276800000, // 2024-01-15
        });

        // Act
        final result = UserProfileModel.fromFirestore(mockDoc);

        // Assert
        expect(result.userId, 'user_123');
        expect(result.email, 'test@example.com');
        expect(result.displayName, 'Test User');
        expect(result.photoUrl, 'https://example.com/photo.jpg');
      });

      test('should handle missing fields in Firestore document', () {
        // Arrange
        final mockDoc = MockDocumentSnapshot();
        when(() => mockDoc.id).thenReturn('user_789');
        when(() => mockDoc.data()).thenReturn({});

        // Act
        final result = UserProfileModel.fromFirestore(mockDoc);

        // Assert
        expect(result.userId, 'user_789');
        expect(result.email, '');
        expect(result.displayName, isNull);
        expect(result.photoUrl, isNull);
      });

      test('should handle Timestamp type for dates', () {
        // Arrange
        final mockDoc = MockDocumentSnapshot();
        final timestamp = Timestamp.fromDate(DateTime(2024, 1, 1));
        when(() => mockDoc.id).thenReturn('user_123');
        when(() => mockDoc.data()).thenReturn({
          'email': 'test@example.com',
          'created_at': timestamp,
          'last_login': timestamp,
        });

        // Act
        final result = UserProfileModel.fromFirestore(mockDoc);

        // Assert
        expect(result.createdAt, DateTime(2024, 1, 1));
      });
    });

    group('toFirestore', () {
      test('should convert UserProfileModel to Firestore map', () {
        // Arrange
        final model = UserProfileModel(
          userId: 'user_123',
          email: 'test@example.com',
          displayName: 'Test User',
          photoUrl: 'https://example.com/photo.jpg',
          createdAt: DateTime(2024, 1, 1),
          lastLogin: DateTime(2024, 1, 15),
        );

        // Act
        final result = model.toFirestore();

        // Assert
        expect(result['email'], 'test@example.com');
        expect(result['display_name'], 'Test User');
        expect(result['photo_url'], 'https://example.com/photo.jpg');
        expect(result['created_at'], model.createdAt.millisecondsSinceEpoch);
        expect(result['last_login'], model.lastLogin.millisecondsSinceEpoch);
      });
    });

    group('toEntity', () {
      test('should convert UserProfileModel to UserProfile entity', () {
        // Arrange
        final model = UserProfileModel(
          userId: 'user_123',
          email: 'test@example.com',
          displayName: 'Test User',
          photoUrl: 'https://example.com/photo.jpg',
          createdAt: DateTime(2024, 1, 1),
          lastLogin: DateTime(2024, 1, 15),
        );

        // Act
        final result = model.toEntity();

        // Assert
        expect(result, isA<UserProfile>());
        expect(result.userId, model.userId);
        expect(result.email, model.email);
      });
    });

    group('copyWith', () {
      test('should create copy with updated fields', () {
        // Arrange
        final original = UserProfileModel(
          userId: 'user_123',
          email: 'test@example.com',
          displayName: 'Original Name',
          createdAt: DateTime(2024, 1, 1),
          lastLogin: DateTime(2024, 1, 15),
        );

        // Act
        final copy = original.copyWith(displayName: 'New Name');

        // Assert
        expect(copy.displayName, 'New Name');
        expect(copy.userId, original.userId);
        expect(copy.email, original.email);
      });
    });
  });
}
