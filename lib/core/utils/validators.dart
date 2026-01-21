import 'constants.dart';

/// Input validation utilities for forms and user input.
///
/// All validators return:
/// - null if validation passes
/// - String error message if validation fails
///
/// Usage in forms:
/// ```dart
/// TextFormField(
///   validator: Validators.validateItemName,
///   // ...
/// )
/// ```
class Validators {
  // Private constructor to prevent instantiation
  Validators._();

  /// Validate item name.
  ///
  /// Rules:
  /// - Required (not null or empty)
  /// - Maximum 30 characters
  static String? validateItemName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Item name is required';
    }
    if (value.length > AppConstants.maxItemNameLength) {
      return 'Item name must be ${AppConstants.maxItemNameLength} characters or less';
    }
    return null;
  }

  /// Validate category name.
  ///
  /// Rules:
  /// - Required (not null or empty)
  /// - Maximum 30 characters
  static String? validateCategoryName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Category name is required';
    }
    if (value.length > AppConstants.maxCategoryNameLength) {
      return 'Category name must be ${AppConstants.maxCategoryNameLength} characters or less';
    }
    return null;
  }

  /// Validate email address.
  ///
  /// Rules:
  /// - Required (not null or empty)
  /// - Must match email regex pattern
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }

    // Email regex: username@domain.tld
    // Allows letters, numbers, dots, hyphens, underscores, and + in local part
    // Disallows consecutive dots, leading/trailing dots
    // Requires @ followed by domain with at least one dot
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9_%+\-]+(\.[a-zA-Z0-9_%+\-]+)*@[a-zA-Z0-9\-]+(\.[a-zA-Z0-9\-]+)*\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(value)) {
      return 'Invalid email format';
    }

    return null;
  }

  /// Validate password.
  ///
  /// Rules:
  /// - Required (not null or empty)
  /// - Minimum 6 characters
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  /// Validate increment value for items.
  ///
  /// Rules:
  /// - Required (not null)
  /// - Between 1 and 100
  static String? validateIncrementValue(int? value) {
    if (value == null) {
      return 'Increment value is required';
    }
    if (value < AppConstants.minIncrementValue ||
        value > AppConstants.maxIncrementValue) {
      return 'Increment must be between ${AppConstants.minIncrementValue} and ${AppConstants.maxIncrementValue}';
    }
    return null;
  }

  /// Validate reminder value for items.
  ///
  /// Rules:
  /// - Required (not null)
  /// - Between 0 and 1000
  static String? validateReminderValue(int? value) {
    if (value == null) {
      return 'Reminder value is required';
    }
    if (value < AppConstants.minReminderValue ||
        value > AppConstants.maxReminderValue) {
      return 'Reminder value must be between ${AppConstants.minReminderValue} and ${AppConstants.maxReminderValue}';
    }
    return null;
  }

  /// Validate that a string is not empty.
  ///
  /// Generic validator for required text fields.
  static String? validateRequired(String? value, {String fieldName = 'Field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Validate string length.
  ///
  /// Generic validator for text length constraints.
  static String? validateLength(
    String? value, {
    int? minLength,
    int? maxLength,
    String fieldName = 'Field',
  }) {
    if (value == null) {
      return null; // Use validateRequired for null checks
    }

    if (minLength != null && value.length < minLength) {
      return '$fieldName must be at least $minLength characters';
    }

    if (maxLength != null && value.length > maxLength) {
      return '$fieldName must be $maxLength characters or less';
    }

    return null;
  }

  /// Validate numeric range.
  ///
  /// Generic validator for numeric input constraints.
  static String? validateRange(
    int? value, {
    required int min,
    required int max,
    String fieldName = 'Value',
  }) {
    if (value == null) {
      return '$fieldName is required';
    }

    if (value < min || value > max) {
      return '$fieldName must be between $min and $max';
    }

    return null;
  }
}
