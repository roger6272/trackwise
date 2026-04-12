import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:traxelos/core/error/exceptions.dart';
import 'package:traxelos/core/error/failures.dart';
import 'package:traxelos/features/auth/data/datasources/auth_firebase_datasource.dart';
import 'package:traxelos/features/auth/data/models/user_model.dart';
import 'package:traxelos/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:traxelos/features/auth/domain/entities/user.dart';

class MockAuthFirebaseDataSource extends Mock implements AuthFirebaseDataSource {}

void main() {
  late AuthRepositoryImpl repository;
  late MockAuthFirebaseDataSource mockDataSource;

  setUp(() {
    mockDataSource = MockAuthFirebaseDataSource();
    repository = AuthRepositoryImpl(dataSource: mockDataSource);
  });

  const testUserModel = UserModel(
    id: 'user_123',
    email: 'test@example.com',
    displayName: 'Test User',
    photoUrl: 'https://example.com/photo.jpg',
    emailVerified: true,
  );

  const testEmail = 'test@example.com';
  const testPassword = 'password123';

  group('signInWithEmail', () {
    test('should return User when sign in is successful', () async {
      // Arrange
      when(() => mockDataSource.signInWithEmail(testEmail, testPassword))
          .thenAnswer((_) async => testUserModel);

      // Act
      final result = await repository.signInWithEmail(testEmail, testPassword);

      // Assert
      expect(result, isA<Right<Failure, User>>());
      result.fold(
        (failure) => fail('Should not return failure'),
        (user) {
          expect(user.id, testUserModel.id);
          expect(user.email, testUserModel.email);
        },
      );
      verify(() => mockDataSource.signInWithEmail(testEmail, testPassword)).called(1);
    });

    test('should return AuthFailure when sign in fails', () async {
      // Arrange
      when(() => mockDataSource.signInWithEmail(testEmail, testPassword))
          .thenThrow(AuthException('Invalid credentials'));

      // Act
      final result = await repository.signInWithEmail(testEmail, testPassword);

      // Assert
      expect(result, isA<Left<Failure, User>>());
      result.fold(
        (failure) {
          expect(failure, isA<AuthFailure>());
          expect(failure.message, 'Invalid credentials');
        },
        (user) => fail('Should not return user'),
      );
    });

    test('should return AuthFailure when unexpected exception occurs', () async {
      // Arrange - simulate a Firestore exception escaping the datasource
      when(() => mockDataSource.signInWithEmail(testEmail, testPassword))
          .thenThrow(Exception('Firestore permission denied'));

      // Act
      final result = await repository.signInWithEmail(testEmail, testPassword);

      // Assert
      expect(result, isA<Left<Failure, User>>());
      result.fold(
        (failure) {
          expect(failure, isA<AuthFailure>());
          expect(failure.message, contains('Sign in failed'));
        },
        (user) => fail('Should not return user'),
      );
    });
  });

  group('signInWithGoogle', () {
    test('should return User when Google sign in is successful', () async {
      // Arrange
      when(() => mockDataSource.signInWithGoogle())
          .thenAnswer((_) async => testUserModel);

      // Act
      final result = await repository.signInWithGoogle();

      // Assert
      expect(result, isA<Right<Failure, User>>());
      result.fold(
        (failure) => fail('Should not return failure'),
        (user) => expect(user.id, testUserModel.id),
      );
      verify(() => mockDataSource.signInWithGoogle()).called(1);
    });

    test('should return AuthFailure when Google sign in fails', () async {
      // Arrange
      when(() => mockDataSource.signInWithGoogle())
          .thenThrow(AuthException('Google sign-in cancelled'));

      // Act
      final result = await repository.signInWithGoogle();

      // Assert
      expect(result, isA<Left<Failure, User>>());
      result.fold(
        (failure) => expect(failure.message, 'Google sign-in cancelled'),
        (user) => fail('Should not return user'),
      );
    });

    test('should return AuthFailure when unexpected exception occurs', () async {
      when(() => mockDataSource.signInWithGoogle())
          .thenThrow(Exception('Firestore timeout'));

      final result = await repository.signInWithGoogle();

      expect(result, isA<Left<Failure, User>>());
      result.fold(
        (failure) => expect(failure.message, contains('Google sign-in failed')),
        (user) => fail('Should not return user'),
      );
    });
  });

  group('signInWithApple', () {
    test('should return User when Apple sign in is successful', () async {
      // Arrange
      when(() => mockDataSource.signInWithApple())
          .thenAnswer((_) async => testUserModel);

      // Act
      final result = await repository.signInWithApple();

      // Assert
      expect(result, isA<Right<Failure, User>>());
      result.fold(
        (failure) => fail('Should not return failure'),
        (user) => expect(user.id, testUserModel.id),
      );
      verify(() => mockDataSource.signInWithApple()).called(1);
    });

    test('should return AuthFailure when Apple sign in fails', () async {
      // Arrange
      when(() => mockDataSource.signInWithApple())
          .thenThrow(AuthException('Apple sign-in cancelled'));

      // Act
      final result = await repository.signInWithApple();

      // Assert
      expect(result, isA<Left<Failure, User>>());
      result.fold(
        (failure) => expect(failure.message, 'Apple sign-in cancelled'),
        (user) => fail('Should not return user'),
      );
    });
  });

  group('signUp', () {
    test('should return User when sign up is successful', () async {
      // Arrange
      when(() => mockDataSource.signUp(testEmail, testPassword))
          .thenAnswer((_) async => testUserModel);

      // Act
      final result = await repository.signUp(testEmail, testPassword);

      // Assert
      expect(result, isA<Right<Failure, User>>());
      result.fold(
        (failure) => fail('Should not return failure'),
        (user) => expect(user.email, testUserModel.email),
      );
      verify(() => mockDataSource.signUp(testEmail, testPassword)).called(1);
    });

    test('should return AuthFailure when sign up fails', () async {
      // Arrange
      when(() => mockDataSource.signUp(testEmail, testPassword))
          .thenThrow(AuthException('Email already in use'));

      // Act
      final result = await repository.signUp(testEmail, testPassword);

      // Assert
      expect(result, isA<Left<Failure, User>>());
      result.fold(
        (failure) => expect(failure.message, 'Email already in use'),
        (user) => fail('Should not return user'),
      );
    });
  });

  group('signOut', () {
    test('should return void when sign out is successful', () async {
      // Arrange
      when(() => mockDataSource.signOut()).thenAnswer((_) async {});

      // Act
      final result = await repository.signOut();

      // Assert
      expect(result, isA<Right<Failure, void>>());
      verify(() => mockDataSource.signOut()).called(1);
    });

    test('should return AuthFailure when sign out fails', () async {
      // Arrange
      when(() => mockDataSource.signOut())
          .thenThrow(AuthException('Sign out failed'));

      // Act
      final result = await repository.signOut();

      // Assert
      expect(result, isA<Left<Failure, void>>());
      result.fold(
        (failure) => expect(failure.message, 'Sign out failed'),
        (_) => fail('Should not return success'),
      );
    });
  });

  group('resetPassword', () {
    test('should return void when reset password is successful', () async {
      // Arrange
      when(() => mockDataSource.resetPassword(testEmail))
          .thenAnswer((_) async {});

      // Act
      final result = await repository.resetPassword(testEmail);

      // Assert
      expect(result, isA<Right<Failure, void>>());
      verify(() => mockDataSource.resetPassword(testEmail)).called(1);
    });

    test('should return AuthFailure when reset password fails', () async {
      // Arrange
      when(() => mockDataSource.resetPassword(testEmail))
          .thenThrow(AuthException('User not found'));

      // Act
      final result = await repository.resetPassword(testEmail);

      // Assert
      expect(result, isA<Left<Failure, void>>());
      result.fold(
        (failure) => expect(failure.message, 'User not found'),
        (_) => fail('Should not return success'),
      );
    });
  });

  group('currentUser', () {
    test('should return User when user is logged in', () {
      // Arrange
      when(() => mockDataSource.currentUser).thenReturn(testUserModel);

      // Act
      final result = repository.currentUser;

      // Assert
      expect(result, isA<User>());
      expect(result?.id, testUserModel.id);
      verify(() => mockDataSource.currentUser).called(1);
    });

    test('should return null when no user is logged in', () {
      // Arrange
      when(() => mockDataSource.currentUser).thenReturn(null);

      // Act
      final result = repository.currentUser;

      // Assert
      expect(result, isNull);
    });
  });

  group('watchAuthState', () {
    test('should emit User when auth state changes to logged in', () {
      // Arrange
      when(() => mockDataSource.watchAuthState())
          .thenAnswer((_) => Stream.value(testUserModel));

      // Act
      final result = repository.watchAuthState();

      // Assert
      expect(result, emitsInOrder([isA<User>()]));
    });

    test('should emit null when auth state changes to logged out', () {
      // Arrange
      when(() => mockDataSource.watchAuthState())
          .thenAnswer((_) => Stream.value(null));

      // Act
      final result = repository.watchAuthState();

      // Assert
      expect(result, emitsInOrder([isNull]));
    });

    test('should emit multiple auth state changes', () {
      // Arrange
      when(() => mockDataSource.watchAuthState()).thenAnswer(
        (_) => Stream.fromIterable([null, testUserModel, null]),
      );

      // Act
      final result = repository.watchAuthState();

      // Assert
      expect(result, emitsInOrder([isNull, isA<User>(), isNull]));
    });
  });
}
