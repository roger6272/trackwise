import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:trackwise/core/error/exceptions.dart';
import 'package:trackwise/core/error/failures.dart';
import 'package:trackwise/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:trackwise/features/profile/data/models/user_profile_model.dart';
import 'package:trackwise/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:trackwise/features/profile/domain/entities/user_profile.dart';

class MockProfileRemoteDataSource extends Mock implements ProfileRemoteDataSource {}

void main() {
  late ProfileRepositoryImpl repository;
  late MockProfileRemoteDataSource mockDataSource;

  setUp(() {
    mockDataSource = MockProfileRemoteDataSource();
    repository = ProfileRepositoryImpl(dataSource: mockDataSource);
  });

  final testProfileModel = UserProfileModel(
    userId: 'user_123',
    email: 'test@example.com',
    displayName: 'Test User',
    photoUrl: 'https://example.com/photo.jpg',
    createdAt: DateTime(2024, 1, 1),
    lastLogin: DateTime(2024, 1, 15),
  );

  group('getProfile', () {
    test('should return UserProfile when data source call is successful', () async {
      // Arrange
      when(() => mockDataSource.getProfile())
          .thenAnswer((_) async => testProfileModel);

      // Act
      final result = await repository.getProfile();

      // Assert
      expect(result, isA<Right<Failure, UserProfile>>());
      result.fold(
        (failure) => fail('Should not return failure'),
        (profile) {
          expect(profile.userId, testProfileModel.userId);
          expect(profile.email, testProfileModel.email);
        },
      );
      verify(() => mockDataSource.getProfile()).called(1);
    });

    test('should return AuthFailure when user is not authenticated', () async {
      // Arrange
      when(() => mockDataSource.getProfile())
          .thenThrow(AuthException('Not authenticated'));

      // Act
      final result = await repository.getProfile();

      // Assert
      expect(result, isA<Left<Failure, UserProfile>>());
      result.fold(
        (failure) {
          expect(failure, isA<AuthFailure>());
          expect(failure.message, 'Not authenticated');
        },
        (profile) => fail('Should not return profile'),
      );
    });

    test('should return ServerFailure when data source throws ServerException', () async {
      // Arrange
      when(() => mockDataSource.getProfile())
          .thenThrow(ServerException('Server error'));

      // Act
      final result = await repository.getProfile();

      // Assert
      expect(result, isA<Left<Failure, UserProfile>>());
      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (profile) => fail('Should not return profile'),
      );
    });
  });

  group('updateProfile', () {
    test('should return updated UserProfile when update is successful', () async {
      // Arrange
      when(() => mockDataSource.updateProfile(
            displayName: 'New Name',
            photoUrl: null,
          )).thenAnswer((_) async => testProfileModel);

      // Act
      final result = await repository.updateProfile(displayName: 'New Name');

      // Assert
      expect(result, isA<Right<Failure, UserProfile>>());
      verify(() => mockDataSource.updateProfile(
            displayName: 'New Name',
            photoUrl: null,
          )).called(1);
    });

    test('should return AuthFailure when update fails due to auth', () async {
      // Arrange
      when(() => mockDataSource.updateProfile(
            displayName: any(named: 'displayName'),
            photoUrl: any(named: 'photoUrl'),
          )).thenThrow(AuthException('Not authenticated'));

      // Act
      final result = await repository.updateProfile(displayName: 'New Name');

      // Assert
      expect(result, isA<Left<Failure, UserProfile>>());
      result.fold(
        (failure) => expect(failure, isA<AuthFailure>()),
        (profile) => fail('Should not return profile'),
      );
    });
  });

  group('exportUserData', () {
    const testJsonData = '{"profile": {}, "items": []}';

    test('should return JSON string when export is successful', () async {
      // Arrange
      when(() => mockDataSource.exportUserData())
          .thenAnswer((_) async => testJsonData);

      // Act
      final result = await repository.exportUserData();

      // Assert
      expect(result, isA<Right<Failure, String>>());
      result.fold(
        (failure) => fail('Should not return failure'),
        (json) => expect(json, testJsonData),
      );
      verify(() => mockDataSource.exportUserData()).called(1);
    });

    test('should return AuthFailure when export fails due to auth', () async {
      // Arrange
      when(() => mockDataSource.exportUserData())
          .thenThrow(AuthException('Not authenticated'));

      // Act
      final result = await repository.exportUserData();

      // Assert
      expect(result, isA<Left<Failure, String>>());
      result.fold(
        (failure) => expect(failure, isA<AuthFailure>()),
        (json) => fail('Should not return json'),
      );
    });

    test('should return ServerFailure when export fails', () async {
      // Arrange
      when(() => mockDataSource.exportUserData())
          .thenThrow(ServerException('Export failed'));

      // Act
      final result = await repository.exportUserData();

      // Assert
      expect(result, isA<Left<Failure, String>>());
      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (json) => fail('Should not return json'),
      );
    });
  });

  group('deleteAccount', () {
    test('should return void when deletion is successful', () async {
      // Arrange
      when(() => mockDataSource.deleteAccount())
          .thenAnswer((_) async {});

      // Act
      final result = await repository.deleteAccount();

      // Assert
      expect(result, isA<Right<Failure, void>>());
      verify(() => mockDataSource.deleteAccount()).called(1);
    });

    test('should return AuthFailure when deletion fails due to auth', () async {
      // Arrange
      when(() => mockDataSource.deleteAccount())
          .thenThrow(AuthException('Please sign in again'));

      // Act
      final result = await repository.deleteAccount();

      // Assert
      expect(result, isA<Left<Failure, void>>());
      result.fold(
        (failure) {
          expect(failure, isA<AuthFailure>());
          expect(failure.message, contains('sign in'));
        },
        (_) => fail('Should not return success'),
      );
    });

    test('should return ServerFailure when deletion fails', () async {
      // Arrange
      when(() => mockDataSource.deleteAccount())
          .thenThrow(ServerException('Deletion failed'));

      // Act
      final result = await repository.deleteAccount();

      // Assert
      expect(result, isA<Left<Failure, void>>());
      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (_) => fail('Should not return success'),
      );
    });
  });
}
