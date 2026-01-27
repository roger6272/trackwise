import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:traxelos/core/error/failures.dart';
import 'package:traxelos/core/usecases/usecase.dart';
import 'package:traxelos/features/auth/domain/usecases/sign_out_usecase.dart';

import '../../helpers/test_helper.dart';

void main() {
  late SignOutUseCase useCase;
  late MockAuthRepository mockRepository;

  setUp(() {
    mockRepository = MockAuthRepository();
    useCase = SignOutUseCase(mockRepository);
  });

  group('SignOutUseCase', () {
    test('should return void when sign out is successful', () async {
      // Arrange
      when(() => mockRepository.signOut())
          .thenAnswer((_) async => const Right(null));

      // Act
      final result = await useCase(const NoParams());

      // Assert
      expect(result, const Right(null));
      verify(() => mockRepository.signOut()).called(1);
      verifyNoMoreInteractions(mockRepository);
    });

    test('should return ServerFailure when sign out fails', () async {
      // Arrange
      const failure = ServerFailure('Sign out failed');
      when(() => mockRepository.signOut())
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase(const NoParams());

      // Assert
      expect(result, const Left(failure));
      verify(() => mockRepository.signOut()).called(1);
    });
  });
}
