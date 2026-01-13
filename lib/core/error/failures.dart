import 'package:equatable/equatable.dart';

/// Base class for all failures in the application.
///
/// Failures represent errors at the domain/business logic level.
/// They are returned from repositories and use cases using Either<Failure, T>.
///
/// All Failures use Equatable for value equality comparisons.
abstract class Failure extends Equatable {
  final String message;

  const Failure(this.message);

  @override
  List<Object> get props => [message];

  @override
  String toString() => '$runtimeType: $message';
}

/// Server/Network failure from Firebase or other APIs.
///
/// Examples:
/// - Firebase Firestore operation failed
/// - Network timeout
/// - Server returned error status code
class ServerFailure extends Failure {
  const ServerFailure(String message) : super(message);
}

/// Local cache/storage failure.
///
/// Examples:
/// - SharedPreferences read/write failed
/// - Local database operation failed
/// - File system error
class CacheFailure extends Failure {
  const CacheFailure(String message) : super(message);
}

/// Bluetooth operation failure.
///
/// Examples:
/// - ESP32 connection failed
/// - BLE characteristic read/write failed
/// - Device not found during scan
/// - Bluetooth adapter not available
class BluetoothFailure extends Failure {
  const BluetoothFailure(String message) : super(message);
}

/// Authentication failure.
///
/// Examples:
/// - Login failed (wrong credentials)
/// - User not authenticated
/// - Token expired
/// - Firebase Auth error
class AuthFailure extends Failure {
  const AuthFailure(String message) : super(message);
}

/// Validation failure for user input.
///
/// Examples:
/// - Empty required field
/// - Invalid email format
/// - Value out of allowed range
/// - String too long/short
class ValidationFailure extends Failure {
  const ValidationFailure(String message) : super(message);
}
