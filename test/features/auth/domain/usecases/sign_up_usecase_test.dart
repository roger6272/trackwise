import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:traxelos/core/error/failures.dart';
import 'package:traxelos/features/auth/domain/usecases/sign_up_usecase.dart';

import '../../helpers/test_helper.dart';
import '../../helpers/test_fixtures.dart';

void main() {
  late SignUpUseCase useCase;
  late MockAuthRepository mockRepository;

  setUp(() {
    mockRepository = MockAuthRepository();
    useCase = SignUpUseCase(mockRepository);
  });

  group('SignUpUseCase', () {
    test('should return user when sign up is successful', () async {
      // Arrange
      when(() => mockRepository.signUp(any(), any()))
          .thenAnswer((_) async => const Right(testUser));

      // Act
      final result = await useCase(
        const SignUpParams(email: testEmail, password: testPassword),
      );

      // Assert
      expect(result, const Right(testUser));
      verify(() => mockRepository.signUp(testEmail, testPassword)).called(1);
      verifyNoMoreInteractions(mockRepository);
    });

    test('should return AuthFailure when email already exists', () async {
      // Arrange
      const failure = AuthFailure('Email already in use');
      when(() => mockRepository.signUp(any(), any()))
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase(
        const SignUpParams(email: testEmail, password: testPassword),
      );

      // Assert
      expect(result, const Left(failure));
      verify(() => mockRepository.signUp(testEmail, testPassword)).called(1);
    });

    test('should return AuthFailure when password is weak', () async {
      // Arrange
      const failure = AuthFailure('Password is too weak');
      when(() => mockRepository.signUp(any(), any()))
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase(
        const SignUpParams(email: testEmail, password: testWeakPassword),
      );

      // Assert
      expect(result, const Left(failure));
    });

    test('should return ServerFailure when network error occurs', () async {
      // Arrange
      const failure = ServerFailure('Network error');
      when(() => mockRepository.signUp(any(), any()))
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase(
        const SignUpParams(email: testEmail, password: testPassword),
      );

      // Assert
      expect(result, const Left(failure));
    });
  });

  group('SignUpParams', () {
    test('should have correct props for equality', () {
      const params1 = SignUpParams(email: 'a@b.com', password: 'pass');
      const params2 = SignUpParams(email: 'a@b.com', password: 'pass');
      const params3 = SignUpParams(email: 'x@y.com', password: 'pass');

      expect(params1, equals(params2));
      expect(params1, isNot(equals(params3)));
    });
  });
}
