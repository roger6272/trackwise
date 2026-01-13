import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:trackwise/core/error/failures.dart';
import 'package:trackwise/core/usecases/usecase.dart';
import 'package:trackwise/features/profile/domain/repositories/profile_repository.dart';
import 'package:trackwise/features/profile/domain/usecases/delete_account_usecase.dart';

class MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  late DeleteAccountUseCase useCase;
  late MockProfileRepository mockRepository;

  setUp(() {
    mockRepository = MockProfileRepository();
    useCase = DeleteAccountUseCase(mockRepository);
  });

  group('DeleteAccountUseCase', () {
    test('should return void when account deletion is successful', () async {
      // Arrange
      when(() => mockRepository.deleteAccount())
          .thenAnswer((_) async => const Right(null));

      // Act
      final result = await useCase(const NoParams());

      // Assert
      expect(result, const Right(null));
      verify(() => mockRepository.deleteAccount()).called(1);
      verifyNoMoreInteractions(mockRepository);
    });

    test('should return AuthFailure when user is not authenticated', () async {
      // Arrange
      const failure = AuthFailure('Not authenticated');
      when(() => mockRepository.deleteAccount())
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase(const NoParams());

      // Assert
      expect(result, const Left(failure));
    });

    test('should return AuthFailure when re-authentication is required', () async {
      // Arrange
      const failure = AuthFailure('Please sign in again to delete your account');
      when(() => mockRepository.deleteAccount())
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase(const NoParams());

      // Assert
      expect(result, const Left(failure));
    });

    test('should return ServerFailure when deletion fails', () async {
      // Arrange
      const failure = ServerFailure('Deletion failed');
      when(() => mockRepository.deleteAccount())
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase(const NoParams());

      // Assert
      expect(result, const Left(failure));
    });
  });
}
