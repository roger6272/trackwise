import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:trackwise/core/error/failures.dart';
import 'package:trackwise/core/usecases/usecase.dart';
import 'package:trackwise/features/profile/domain/repositories/profile_repository.dart';
import 'package:trackwise/features/profile/domain/usecases/export_user_data_usecase.dart';

class MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  late ExportUserDataUseCase useCase;
  late MockProfileRepository mockRepository;

  setUp(() {
    mockRepository = MockProfileRepository();
    useCase = ExportUserDataUseCase(mockRepository);
  });

  const testJsonData = '{"profile": {"email": "test@example.com"}, "items": []}';

  group('ExportUserDataUseCase', () {
    test('should return JSON string when export is successful', () async {
      // Arrange
      when(() => mockRepository.exportUserData())
          .thenAnswer((_) async => const Right(testJsonData));

      // Act
      final result = await useCase(const NoParams());

      // Assert
      expect(result, const Right(testJsonData));
      verify(() => mockRepository.exportUserData()).called(1);
      verifyNoMoreInteractions(mockRepository);
    });

    test('should return AuthFailure when user is not authenticated', () async {
      // Arrange
      const failure = AuthFailure('Not authenticated');
      when(() => mockRepository.exportUserData())
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase(const NoParams());

      // Assert
      expect(result, const Left(failure));
    });

    test('should return ServerFailure when export fails', () async {
      // Arrange
      const failure = ServerFailure('Export failed');
      when(() => mockRepository.exportUserData())
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase(const NoParams());

      // Assert
      expect(result, const Left(failure));
    });
  });
}
