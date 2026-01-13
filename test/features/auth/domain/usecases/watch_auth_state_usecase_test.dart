import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:trackwise/features/auth/domain/usecases/watch_auth_state_usecase.dart';

import '../../helpers/test_helper.dart';
import '../../helpers/test_fixtures.dart';

void main() {
  late WatchAuthStateUseCase useCase;
  late MockAuthRepository mockRepository;

  setUp(() {
    mockRepository = MockAuthRepository();
    useCase = WatchAuthStateUseCase(mockRepository);
  });

  group('WatchAuthStateUseCase', () {
    test('should return stream of users from repository', () async {
      // Arrange
      when(() => mockRepository.watchAuthState())
          .thenAnswer((_) => Stream.value(testUser));

      // Act
      final result = useCase();

      // Assert
      expect(result, emitsInOrder([testUser]));
      verify(() => mockRepository.watchAuthState()).called(1);
    });

    test('should emit null when user signs out', () async {
      // Arrange
      when(() => mockRepository.watchAuthState())
          .thenAnswer((_) => Stream.value(null));

      // Act
      final result = useCase();

      // Assert
      expect(result, emitsInOrder([null]));
    });

    test('should emit multiple auth state changes', () async {
      // Arrange
      when(() => mockRepository.watchAuthState()).thenAnswer(
        (_) => Stream.fromIterable([null, testUser, null]),
      );

      // Act
      final result = useCase();

      // Assert
      expect(result, emitsInOrder([null, testUser, null]));
    });

    test('should return current user from repository', () {
      // Arrange
      when(() => mockRepository.currentUser).thenReturn(testUser);

      // Act
      final result = useCase.currentUser;

      // Assert
      expect(result, testUser);
      verify(() => mockRepository.currentUser).called(1);
    });

    test('should return null when no user is authenticated', () {
      // Arrange
      when(() => mockRepository.currentUser).thenReturn(null);

      // Act
      final result = useCase.currentUser;

      // Assert
      expect(result, isNull);
    });
  });
}
