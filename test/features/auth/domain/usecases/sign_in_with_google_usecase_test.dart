import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:traxelos/core/error/failures.dart';
import 'package:traxelos/core/usecases/usecase.dart';
import 'package:traxelos/features/auth/domain/usecases/sign_in_with_google_usecase.dart';

import '../../helpers/test_helper.dart';
import '../../helpers/test_fixtures.dart';

void main() {
  late SignInWithGoogleUseCase useCase;
  late MockAuthRepository mockRepository;

  setUp(() {
    mockRepository = MockAuthRepository();
    useCase = SignInWithGoogleUseCase(mockRepository);
  });

  group('SignInWithGoogleUseCase', () {
    test('should return user when Google sign in is successful', () async {
      // Arrange
      when(() => mockRepository.signInWithGoogle())
          .thenAnswer((_) async => const Right(testGoogleUser));

      // Act
      final result = await useCase(const NoParams());

      // Assert
      expect(result, const Right(testGoogleUser));
      verify(() => mockRepository.signInWithGoogle()).called(1);
      verifyNoMoreInteractions(mockRepository);
    });

    test('should return AuthFailure when Google sign in is cancelled', () async {
      // Arrange
      const failure = AuthFailure('Google sign-in cancelled');
      when(() => mockRepository.signInWithGoogle())
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase(const NoParams());

      // Assert
      expect(result, const Left(failure));
      verify(() => mockRepository.signInWithGoogle()).called(1);
    });

    test('should return ServerFailure when network error occurs', () async {
      // Arrange
      const failure = ServerFailure('Network error');
      when(() => mockRepository.signInWithGoogle())
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase(const NoParams());

      // Assert
      expect(result, const Left(failure));
    });
  });
}
