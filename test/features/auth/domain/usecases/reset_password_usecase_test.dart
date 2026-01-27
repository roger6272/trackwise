import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:traxelos/core/error/failures.dart';
import 'package:traxelos/features/auth/domain/usecases/reset_password_usecase.dart';

import '../../helpers/test_helper.dart';
import '../../helpers/test_fixtures.dart';

void main() {
  late ResetPasswordUseCase useCase;
  late MockAuthRepository mockRepository;

  setUp(() {
    mockRepository = MockAuthRepository();
    useCase = ResetPasswordUseCase(mockRepository);
  });

  group('ResetPasswordUseCase', () {
    test('should return void when reset password email is sent', () async {
      // Arrange
      when(() => mockRepository.resetPassword(any()))
          .thenAnswer((_) async => const Right(null));

      // Act
      final result = await useCase(const ResetPasswordParams(email: testEmail));

      // Assert
      expect(result, const Right(null));
      verify(() => mockRepository.resetPassword(testEmail)).called(1);
      verifyNoMoreInteractions(mockRepository);
    });

    test('should return AuthFailure when email is not registered', () async {
      // Arrange
      const failure = AuthFailure('Email not found');
      when(() => mockRepository.resetPassword(any()))
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase(const ResetPasswordParams(email: testEmail));

      // Assert
      expect(result, const Left(failure));
      verify(() => mockRepository.resetPassword(testEmail)).called(1);
    });

    test('should return ServerFailure when network error occurs', () async {
      // Arrange
      const failure = ServerFailure('Network error');
      when(() => mockRepository.resetPassword(any()))
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase(const ResetPasswordParams(email: testEmail));

      // Assert
      expect(result, const Left(failure));
    });

    test('should call repository with correct email', () async {
      // Arrange
      const differentEmail = 'different@example.com';
      when(() => mockRepository.resetPassword(any()))
          .thenAnswer((_) async => const Right(null));

      // Act
      await useCase(const ResetPasswordParams(email: differentEmail));

      // Assert
      verify(() => mockRepository.resetPassword(differentEmail)).called(1);
    });
  });

  group('ResetPasswordParams', () {
    test('should have correct props for equality', () {
      const params1 = ResetPasswordParams(email: 'a@b.com');
      const params2 = ResetPasswordParams(email: 'a@b.com');
      const params3 = ResetPasswordParams(email: 'x@y.com');

      expect(params1, equals(params2));
      expect(params1, isNot(equals(params3)));
    });
  });
}
