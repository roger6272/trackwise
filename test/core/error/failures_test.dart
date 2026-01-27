import 'package:flutter_test/flutter_test.dart';
import 'package:traxelos/core/error/failures.dart';

/// Unit tests for Failure classes.
///
/// These tests verify that Failures use Equatable correctly for value equality.
void main() {
  group('Failures -', () {
    group('ServerFailure', () {
      test('should have correct message', () {
        // arrange
        const message = 'Server error occurred';
        const failure = ServerFailure(message);

        // assert
        expect(failure.message, message);
      });

      test('should be equal when messages are the same', () {
        // arrange
        const failure1 = ServerFailure('Error');
        const failure2 = ServerFailure('Error');

        // assert
        expect(failure1, failure2);
      });

      test('should not be equal when messages are different', () {
        // arrange
        const failure1 = ServerFailure('Error 1');
        const failure2 = ServerFailure('Error 2');

        // assert
        expect(failure1, isNot(failure2));
      });

      test('props should contain message', () {
        // arrange
        const failure = ServerFailure('Error');

        // assert
        expect(failure.props, ['Error']);
      });
    });

    group('CacheFailure', () {
      test('should have correct message', () {
        // arrange
        const message = 'Cache error occurred';
        const failure = CacheFailure(message);

        // assert
        expect(failure.message, message);
      });

      test('should be equal when messages are the same', () {
        // arrange
        const failure1 = CacheFailure('Error');
        const failure2 = CacheFailure('Error');

        // assert
        expect(failure1, failure2);
      });

      test('should not be equal when messages are different', () {
        // arrange
        const failure1 = CacheFailure('Error 1');
        const failure2 = CacheFailure('Error 2');

        // assert
        expect(failure1, isNot(failure2));
      });

      test('props should contain message', () {
        // arrange
        const failure = CacheFailure('Error');

        // assert
        expect(failure.props, ['Error']);
      });
    });

    group('BluetoothFailure', () {
      test('should have correct message', () {
        // arrange
        const message = 'Bluetooth connection failed';
        const failure = BluetoothFailure(message);

        // assert
        expect(failure.message, message);
      });

      test('should be equal when messages are the same', () {
        // arrange
        const failure1 = BluetoothFailure('Error');
        const failure2 = BluetoothFailure('Error');

        // assert
        expect(failure1, failure2);
      });

      test('should not be equal when messages are different', () {
        // arrange
        const failure1 = BluetoothFailure('Error 1');
        const failure2 = BluetoothFailure('Error 2');

        // assert
        expect(failure1, isNot(failure2));
      });

      test('props should contain message', () {
        // arrange
        const failure = BluetoothFailure('Error');

        // assert
        expect(failure.props, ['Error']);
      });
    });

    group('AuthFailure', () {
      test('should have correct message', () {
        // arrange
        const message = 'Authentication failed';
        const failure = AuthFailure(message);

        // assert
        expect(failure.message, message);
      });

      test('should be equal when messages are the same', () {
        // arrange
        const failure1 = AuthFailure('Error');
        const failure2 = AuthFailure('Error');

        // assert
        expect(failure1, failure2);
      });

      test('should not be equal when messages are different', () {
        // arrange
        const failure1 = AuthFailure('Error 1');
        const failure2 = AuthFailure('Error 2');

        // assert
        expect(failure1, isNot(failure2));
      });

      test('props should contain message', () {
        // arrange
        const failure = AuthFailure('Error');

        // assert
        expect(failure.props, ['Error']);
      });
    });

    group('ValidationFailure', () {
      test('should have correct message', () {
        // arrange
        const message = 'Validation failed';
        const failure = ValidationFailure(message);

        // assert
        expect(failure.message, message);
      });

      test('should be equal when messages are the same', () {
        // arrange
        const failure1 = ValidationFailure('Error');
        const failure2 = ValidationFailure('Error');

        // assert
        expect(failure1, failure2);
      });

      test('should not be equal when messages are different', () {
        // arrange
        const failure1 = ValidationFailure('Error 1');
        const failure2 = ValidationFailure('Error 2');

        // assert
        expect(failure1, isNot(failure2));
      });

      test('props should contain message', () {
        // arrange
        const failure = ValidationFailure('Error');

        // assert
        expect(failure.props, ['Error']);
      });
    });

    group('Failure type comparison', () {
      test('different failure types with same message should not be equal', () {
        // arrange
        const serverFailure = ServerFailure('Error');
        const cacheFailure = CacheFailure('Error');

        // assert
        expect(serverFailure, isNot(cacheFailure));
      });

      test('should be able to use Failures in collections', () {
        // arrange
        const failure1 = ServerFailure('Error 1');
        const failure2 = CacheFailure('Error 2');
        const failure3 = BluetoothFailure('Error 3');

        // act
        final failures = [failure1, failure2, failure3];

        // assert
        expect(failures.length, 3);
        expect(failures.contains(failure1), true);
        expect(failures.contains(const ServerFailure('Error 1')), true);
        expect(failures.contains(const ServerFailure('Different')), false);
      });
    });
  });
}
