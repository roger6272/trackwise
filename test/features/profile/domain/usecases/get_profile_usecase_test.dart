import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:traxelos/core/error/failures.dart';
import 'package:traxelos/core/usecases/usecase.dart';
import 'package:traxelos/features/profile/domain/entities/user_profile.dart';
import 'package:traxelos/features/profile/domain/repositories/profile_repository.dart';
import 'package:traxelos/features/profile/domain/usecases/get_profile_usecase.dart';

class MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  late GetProfileUseCase useCase;
  late MockProfileRepository mockRepository;

  setUp(() {
    mockRepository = MockProfileRepository();
    useCase = GetProfileUseCase(mockRepository);
  });

  final testProfile = UserProfile(
    userId: 'user_123',
    email: 'test@example.com',
    displayName: 'Test User',
    photoUrl: 'https://example.com/photo.jpg',
    createdAt: DateTime(2024, 1, 1),
    lastLogin: DateTime(2024, 1, 15),
  );

  group('GetProfileUseCase', () {
    test('should return UserProfile when repository call is successful', () async {
      // Arrange
      when(() => mockRepository.getProfile())
          .thenAnswer((_) async => Right(testProfile));

      // Act
      final result = await useCase(const NoParams());

      // Assert
      expect(result, Right(testProfile));
      verify(() => mockRepository.getProfile()).called(1);
      verifyNoMoreInteractions(mockRepository);
    });

    test('should return AuthFailure when user is not authenticated', () async {
      // Arrange
      const failure = AuthFailure('Not authenticated');
      when(() => mockRepository.getProfile())
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase(const NoParams());

      // Assert
      expect(result, const Left(failure));
      verify(() => mockRepository.getProfile()).called(1);
    });

    test('should return ServerFailure when repository call fails', () async {
      // Arrange
      const failure = ServerFailure('Server error');
      when(() => mockRepository.getProfile())
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase(const NoParams());

      // Assert
      expect(result, const Left(failure));
    });
  });
}
