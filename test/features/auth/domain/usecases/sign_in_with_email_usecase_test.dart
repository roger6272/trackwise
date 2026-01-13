import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:trackwise/core/error/failures.dart';
import 'package:trackwise/features/auth/domain/usecases/sign_in_with_email_usecase.dart';

import '../../helpers/test_helper.dart';
import '../../helpers/test_fixtures.dart';

void main() {
  late SignInWithEmailUseCase useCase;
  late MockAuthRepository mockRepository;

  setUp(() {
    mockRepository = MockAuthRepository();
    useCase = SignInWithEmailUseCase(mockRepository);
  });

  group('SignInWithEmailUseCase', () {
    test('should return user when sign in is successful', () async {
      // Arrange
      when(() => mockRepository.signInWithEmail(any(), any()))
          .thenAnswer((_) async => const Right(testUser));

      // Act
      final result = await useCase(
        const SignInWithEmailParams(email: testEmail, password: testPassword),
      );

      // Assert
      expect(result, const Right(testUser));
      verify(() => mockRepository.signInWithEmail(testEmail, testPassword))
          .called(1);
      verifyNoMoreInteractions(mockRepository);
    });

    test('should return AuthFailure when credentials are invalid', () async {
      // Arrange
      const failure = AuthFailure('Invalid credentials');
      when(() => mockRepository.signInWithEmail(any(), any()))
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase(
        const SignInWithEmailParams(email: testEmail, password: testPassword),
      );

      // Assert
      expect(result, const Left(failure));
      verify(() => mockRepository.signInWithEmail(testEmail, testPassword))
          .called(1);
    });

    test('should return ServerFailure when network error occurs', () async {
      // Arrange
      const failure = ServerFailure('Network error');
      when(() => mockRepository.signInWithEmail(any(), any()))
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase(
        const SignInWithEmailParams(email: testEmail, password: testPassword),
      );

      // Assert
      expect(result, const Left(failure));
    });

    test('should call repository with correct email and password', () async {
      // Arrange
      const email = 'different@example.com';
      const password = 'differentPassword';
      when(() => mockRepository.signInWithEmail(any(), any()))
          .thenAnswer((_) async => const Right(testUser));

      // Act
      await useCase(const SignInWithEmailParams(email: email, password: password));

      // Assert
      verify(() => mockRepository.signInWithEmail(email, password)).called(1);
    });
  });

  group('SignInWithEmailParams', () {
    test('should have correct props for equality', () {
      const params1 = SignInWithEmailParams(email: 'a@b.com', password: 'pass');
      const params2 = SignInWithEmailParams(email: 'a@b.com', password: 'pass');
      const params3 = SignInWithEmailParams(email: 'x@y.com', password: 'pass');

      expect(params1, equals(params2));
      expect(params1, isNot(equals(params3)));
    });
  });
}
