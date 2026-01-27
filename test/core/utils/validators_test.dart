import 'package:flutter_test/flutter_test.dart';
import 'package:traxelos/core/utils/validators.dart';
import 'package:traxelos/core/utils/constants.dart';

/// Unit tests for Validators class.
///
/// These tests verify input validation logic for forms and user input.
void main() {
  group('Validators -', () {
    group('validateItemName', () {
      test('should return null for valid item name', () {
        // arrange
        const validName = 'Test Item';

        // act
        final result = Validators.validateItemName(validName);

        // assert
        expect(result, null);
      });

      test('should return error message when item name is null', () {
        // act
        final result = Validators.validateItemName(null);

        // assert
        expect(result, 'Item name is required');
      });

      test('should return error message when item name is empty', () {
        // act
        final result = Validators.validateItemName('');

        // assert
        expect(result, 'Item name is required');
      });

      test('should return error message when item name is only whitespace', () {
        // act
        final result = Validators.validateItemName('   ');

        // assert
        expect(result, 'Item name is required');
      });

      test('should return error message when item name exceeds max length', () {
        // arrange
        final longName = 'a' * (AppConstants.maxItemNameLength + 1);

        // act
        final result = Validators.validateItemName(longName);

        // assert
        expect(
          result,
          'Item name must be ${AppConstants.maxItemNameLength} characters or less',
        );
      });

      test('should return null for item name at max length', () {
        // arrange
        final maxLengthName = 'a' * AppConstants.maxItemNameLength;

        // act
        final result = Validators.validateItemName(maxLengthName);

        // assert
        expect(result, null);
      });
    });

    group('validateEmail', () {
      test('should return null for valid email', () {
        // arrange
        const validEmail = 'test@example.com';

        // act
        final result = Validators.validateEmail(validEmail);

        // assert
        expect(result, null);
      });

      test('should return error message when email is null', () {
        // act
        final result = Validators.validateEmail(null);

        // assert
        expect(result, 'Email is required');
      });

      test('should return error message when email is empty', () {
        // act
        final result = Validators.validateEmail('');

        // assert
        expect(result, 'Email is required');
      });

      test('should return error message for invalid email format', () {
        // arrange
        const invalidEmails = [
          'notanemail',
          '@example.com',
          'test@',
          'test@.com',
          'test..test@example.com',
        ];

        for (final email in invalidEmails) {
          // act
          final result = Validators.validateEmail(email);

          // assert
          expect(result, 'Invalid email format', reason: 'Failed for: $email');
        }
      });

      test('should return null for various valid email formats', () {
        // arrange
        const validEmails = [
          'test@example.com',
          'user.name@example.com',
          'user+tag@example.co.uk',
          'test_user@sub.example.com',
        ];

        for (final email in validEmails) {
          // act
          final result = Validators.validateEmail(email);

          // assert
          expect(result, null, reason: 'Failed for: $email');
        }
      });
    });

    group('validatePassword', () {
      test('should return null for valid password', () {
        // arrange
        const validPassword = 'password123';

        // act
        final result = Validators.validatePassword(validPassword);

        // assert
        expect(result, null);
      });

      test('should return error message when password is null', () {
        // act
        final result = Validators.validatePassword(null);

        // assert
        expect(result, 'Password is required');
      });

      test('should return error message when password is empty', () {
        // act
        final result = Validators.validatePassword('');

        // assert
        expect(result, 'Password is required');
      });

      test('should return error message when password is less than 6 characters', () {
        // act
        final result = Validators.validatePassword('12345');

        // assert
        expect(result, 'Password must be at least 6 characters');
      });

      test('should return null for password with exactly 6 characters', () {
        // act
        final result = Validators.validatePassword('123456');

        // assert
        expect(result, null);
      });
    });

    group('validateIncrementValue', () {
      test('should return null for valid increment value', () {
        // act
        final result = Validators.validateIncrementValue(1);

        // assert
        expect(result, null);
      });

      test('should return error message when increment value is null', () {
        // act
        final result = Validators.validateIncrementValue(null);

        // assert
        expect(result, 'Increment value is required');
      });

      test('should return error message when increment value is below minimum', () {
        // arrange
        final belowMin = AppConstants.minIncrementValue - 1;

        // act
        final result = Validators.validateIncrementValue(belowMin);

        // assert
        expect(
          result,
          'Increment must be between ${AppConstants.minIncrementValue} and ${AppConstants.maxIncrementValue}',
        );
      });

      test('should return error message when increment value is above maximum', () {
        // arrange
        final aboveMax = AppConstants.maxIncrementValue + 1;

        // act
        final result = Validators.validateIncrementValue(aboveMax);

        // assert
        expect(
          result,
          'Increment must be between ${AppConstants.minIncrementValue} and ${AppConstants.maxIncrementValue}',
        );
      });

      test('should return null for minimum valid increment value', () {
        // act
        final result =
            Validators.validateIncrementValue(AppConstants.minIncrementValue);

        // assert
        expect(result, null);
      });

      test('should return null for maximum valid increment value', () {
        // act
        final result =
            Validators.validateIncrementValue(AppConstants.maxIncrementValue);

        // assert
        expect(result, null);
      });
    });

    group('validateReminderValue', () {
      test('should return null for valid reminder value', () {
        // act
        final result = Validators.validateReminderValue(50);

        // assert
        expect(result, null);
      });

      test('should return error message when reminder value is null', () {
        // act
        final result = Validators.validateReminderValue(null);

        // assert
        expect(result, 'Reminder value is required');
      });

      test('should return error message when reminder value is below minimum', () {
        // arrange
        final belowMin = AppConstants.minReminderValue - 1;

        // act
        final result = Validators.validateReminderValue(belowMin);

        // assert
        expect(
          result,
          'Reminder value must be between ${AppConstants.minReminderValue} and ${AppConstants.maxReminderValue}',
        );
      });

      test('should return error message when reminder value is above maximum', () {
        // arrange
        final aboveMax = AppConstants.maxReminderValue + 1;

        // act
        final result = Validators.validateReminderValue(aboveMax);

        // assert
        expect(
          result,
          'Reminder value must be between ${AppConstants.minReminderValue} and ${AppConstants.maxReminderValue}',
        );
      });

      test('should return null for minimum valid reminder value', () {
        // act
        final result =
            Validators.validateReminderValue(AppConstants.minReminderValue);

        // assert
        expect(result, null);
      });

      test('should return null for maximum valid reminder value', () {
        // act
        final result =
            Validators.validateReminderValue(AppConstants.maxReminderValue);

        // assert
        expect(result, null);
      });
    });

    group('validateRequired', () {
      test('should return null for non-empty string', () {
        // act
        final result = Validators.validateRequired('test');

        // assert
        expect(result, null);
      });

      test('should return error message when value is null', () {
        // act
        final result = Validators.validateRequired(null);

        // assert
        expect(result, 'Field is required');
      });

      test('should return error message when value is empty', () {
        // act
        final result = Validators.validateRequired('');

        // assert
        expect(result, 'Field is required');
      });

      test('should use custom field name in error message', () {
        // act
        final result = Validators.validateRequired(null, fieldName: 'Username');

        // assert
        expect(result, 'Username is required');
      });
    });

    group('validateLength', () {
      test('should return null for string within bounds', () {
        // act
        final result = Validators.validateLength(
          'test',
          minLength: 2,
          maxLength: 10,
        );

        // assert
        expect(result, null);
      });

      test('should return error when string is too short', () {
        // act
        final result = Validators.validateLength(
          'a',
          minLength: 2,
        );

        // assert
        expect(result, 'Field must be at least 2 characters');
      });

      test('should return error when string is too long', () {
        // act
        final result = Validators.validateLength(
          'toolongstring',
          maxLength: 5,
        );

        // assert
        expect(result, 'Field must be 5 characters or less');
      });

      test('should use custom field name in error message', () {
        // act
        final result = Validators.validateLength(
          'a',
          minLength: 2,
          fieldName: 'Username',
        );

        // assert
        expect(result, 'Username must be at least 2 characters');
      });

      test('should return null for null value when no minLength specified', () {
        // act
        final result = Validators.validateLength(null);

        // assert
        expect(result, null);
      });
    });

    group('validateRange', () {
      test('should return null for value within range', () {
        // act
        final result = Validators.validateRange(5, min: 1, max: 10);

        // assert
        expect(result, null);
      });

      test('should return error when value is null', () {
        // act
        final result = Validators.validateRange(null, min: 1, max: 10);

        // assert
        expect(result, 'Value is required');
      });

      test('should return error when value is below minimum', () {
        // act
        final result = Validators.validateRange(0, min: 1, max: 10);

        // assert
        expect(result, 'Value must be between 1 and 10');
      });

      test('should return error when value is above maximum', () {
        // act
        final result = Validators.validateRange(11, min: 1, max: 10);

        // assert
        expect(result, 'Value must be between 1 and 10');
      });

      test('should use custom field name in error message', () {
        // act
        final result = Validators.validateRange(
          null,
          min: 1,
          max: 10,
          fieldName: 'Age',
        );

        // assert
        expect(result, 'Age is required');
      });

      test('should return null for value at minimum bound', () {
        // act
        final result = Validators.validateRange(1, min: 1, max: 10);

        // assert
        expect(result, null);
      });

      test('should return null for value at maximum bound', () {
        // act
        final result = Validators.validateRange(10, min: 1, max: 10);

        // assert
        expect(result, null);
      });
    });
  });
}
