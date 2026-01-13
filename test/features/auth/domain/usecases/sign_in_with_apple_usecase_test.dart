import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:trackwise/core/error/failures.dart';
import 'package:trackwise/core/usecases/usecase.dart';
import 'package:trackwise/features/auth/domain/usecases/sign_in_with_apple_usecase.dart';

import '../../helpers/test_helper.dart';
import '../../helpers/test_fixtures.dart';

void main() {
  late SignInWithAppleUseCase useCase;
  late MockAuthRepository mockRepository;

  setUp(() {
    mockRepository = MockAuthRepository();
    useCase = SignInWithAppleUseCase(mockRepository);
  });

  group('SignInWithAppleUseCase', () {
    test('should return user when Apple sign in is successful', () async {
      // Arrange
      when(() => mockRepository.signInWithApple())
          .thenAnswer((_) async => const Right(testAppleUser));

      // Act
      final result = await useCase(const NoParams());

      // Assert
      expect(result, const Right(testAppleUser));
      verify(() => mockRepository.signInWithApple()).called(1);
      verifyNoMoreInteractions(mockRepository);
    });

    test('should return AuthFailure when Apple sign in is cancelled', () async {
      // Arrange
      const failure = AuthFailure('Apple sign-in cancelled');
      when(() => mockRepository.signInWithApple())
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase(const NoParams());

      // Assert
      expect(result, const Left(failure));
      verify(() => mockRepository.signInWithApple()).called(1);
    });

    test('should return ServerFailure when network error occurs', () async {
      // Arrange
      const failure = ServerFailure('Network error');
      when(() => mockRepository.signInWithApple())
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase(const NoParams());

      // Assert
      expect(result, const Left(failure));
    });
  });
}
