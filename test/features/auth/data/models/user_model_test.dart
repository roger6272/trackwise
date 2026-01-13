import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;

import 'package:trackwise/features/auth/data/models/user_model.dart';
import 'package:trackwise/features/auth/domain/entities/user.dart';

class MockFirebaseUser extends Mock implements firebase.User {}

void main() {
  group('UserModel', () {
    group('fromFirebaseUser', () {
      test('should create UserModel from Firebase User with all fields', () {
        // Arrange
        final mockFirebaseUser = MockFirebaseUser();
        when(() => mockFirebaseUser.uid).thenReturn('user_123');
        when(() => mockFirebaseUser.email).thenReturn('test@example.com');
        when(() => mockFirebaseUser.displayName).thenReturn('Test User');
        when(() => mockFirebaseUser.photoURL).thenReturn('https://example.com/photo.jpg');
        when(() => mockFirebaseUser.emailVerified).thenReturn(true);

        // Act
        final result = UserModel.fromFirebaseUser(mockFirebaseUser);

        // Assert
        expect(result.id, 'user_123');
        expect(result.email, 'test@example.com');
        expect(result.displayName, 'Test User');
        expect(result.photoUrl, 'https://example.com/photo.jpg');
        expect(result.emailVerified, true);
      });

      test('should create UserModel with empty email when Firebase email is null', () {
        // Arrange
        final mockFirebaseUser = MockFirebaseUser();
        when(() => mockFirebaseUser.uid).thenReturn('user_456');
        when(() => mockFirebaseUser.email).thenReturn(null);
        when(() => mockFirebaseUser.displayName).thenReturn(null);
        when(() => mockFirebaseUser.photoURL).thenReturn(null);
        when(() => mockFirebaseUser.emailVerified).thenReturn(false);

        // Act
        final result = UserModel.fromFirebaseUser(mockFirebaseUser);

        // Assert
        expect(result.id, 'user_456');
        expect(result.email, '');
        expect(result.displayName, isNull);
        expect(result.photoUrl, isNull);
        expect(result.emailVerified, false);
      });

      test('should handle Firebase User with partial data', () {
        // Arrange
        final mockFirebaseUser = MockFirebaseUser();
        when(() => mockFirebaseUser.uid).thenReturn('partial_user');
        when(() => mockFirebaseUser.email).thenReturn('partial@example.com');
        when(() => mockFirebaseUser.displayName).thenReturn(null);
        when(() => mockFirebaseUser.photoURL).thenReturn('https://photo.url');
        when(() => mockFirebaseUser.emailVerified).thenReturn(true);

        // Act
        final result = UserModel.fromFirebaseUser(mockFirebaseUser);

        // Assert
        expect(result.id, 'partial_user');
        expect(result.email, 'partial@example.com');
        expect(result.displayName, isNull);
        expect(result.photoUrl, 'https://photo.url');
        expect(result.emailVerified, true);
      });
    });

    group('toEntity', () {
      test('should convert UserModel to User entity with all fields', () {
        // Arrange
        const userModel = UserModel(
          id: 'user_123',
          email: 'test@example.com',
          displayName: 'Test User',
          photoUrl: 'https://example.com/photo.jpg',
          emailVerified: true,
        );

        // Act
        final result = userModel.toEntity();

        // Assert
        expect(result, isA<User>());
        expect(result.id, 'user_123');
        expect(result.email, 'test@example.com');
        expect(result.displayName, 'Test User');
        expect(result.photoUrl, 'https://example.com/photo.jpg');
        expect(result.emailVerified, true);
      });

      test('should convert UserModel to User entity with minimal fields', () {
        // Arrange
        const userModel = UserModel(
          id: 'minimal_user',
          email: 'minimal@example.com',
        );

        // Act
        final result = userModel.toEntity();

        // Assert
        expect(result, isA<User>());
        expect(result.id, 'minimal_user');
        expect(result.email, 'minimal@example.com');
        expect(result.displayName, isNull);
        expect(result.photoUrl, isNull);
        expect(result.emailVerified, false);
      });
    });

    group('inheritance', () {
      test('UserModel should be a subtype of User', () {
        // Arrange
        const userModel = UserModel(
          id: 'user_123',
          email: 'test@example.com',
        );

        // Assert
        expect(userModel, isA<User>());
      });
    });
  });
}
