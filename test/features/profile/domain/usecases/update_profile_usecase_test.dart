import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:trackwise/core/error/failures.dart';
import 'package:trackwise/features/profile/domain/entities/user_profile.dart';
import 'package:trackwise/features/profile/domain/repositories/profile_repository.dart';
import 'package:trackwise/features/profile/domain/usecases/update_profile_usecase.dart';

class MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  late UpdateProfileUseCase useCase;
  late MockProfileRepository mockRepository;

  setUp(() {
    mockRepository = MockProfileRepository();
    useCase = UpdateProfileUseCase(mockRepository);
  });

  final testProfile = UserProfile(
    userId: 'user_123',
    email: 'test@example.com',
    displayName: 'Updated Name',
    photoUrl: 'https://example.com/new_photo.jpg',
    createdAt: DateTime(2024, 1, 1),
    lastLogin: DateTime(2024, 1, 15),
  );

  group('UpdateProfileUseCase', () {
    test('should return updated UserProfile when update is successful', () async {
      // Arrange
      const params = UpdateProfileParams(
        displayName: 'Updated Name',
        photoUrl: 'https://example.com/new_photo.jpg',
      );
      when(() => mockRepository.updateProfile(
            displayName: params.displayName,
            photoUrl: params.photoUrl,
          )).thenAnswer((_) async => Right(testProfile));

      // Act
      final result = await useCase(params);

      // Assert
      expect(result, Right(testProfile));
      verify(() => mockRepository.updateProfile(
            displayName: params.displayName,
            photoUrl: params.photoUrl,
          )).called(1);
    });

    test('should return AuthFailure when user is not authenticated', () async {
      // Arrange
      const params = UpdateProfileParams(displayName: 'New Name');
      const failure = AuthFailure('Not authenticated');
      when(() => mockRepository.updateProfile(
            displayName: params.displayName,
            photoUrl: params.photoUrl,
          )).thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase(params);

      // Assert
      expect(result, const Left(failure));
    });

    test('should return ServerFailure when update fails', () async {
      // Arrange
      const params = UpdateProfileParams(displayName: 'New Name');
      const failure = ServerFailure('Update failed');
      when(() => mockRepository.updateProfile(
            displayName: params.displayName,
            photoUrl: params.photoUrl,
          )).thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase(params);

      // Assert
      expect(result, const Left(failure));
    });

    test('UpdateProfileParams should have correct props', () {
      // Arrange
      const params1 = UpdateProfileParams(displayName: 'Name');
      const params2 = UpdateProfileParams(displayName: 'Name');
      const params3 = UpdateProfileParams(displayName: 'Other');

      // Assert
      expect(params1, equals(params2));
      expect(params1, isNot(equals(params3)));
    });
  });
}
