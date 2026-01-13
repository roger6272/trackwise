library;

/// Base exception types for the data layer.
///
/// Exceptions are thrown at the data layer (repositories, data sources)
/// and are caught and converted to Failures at the repository boundary.
///
/// Flow:
/// 1. Data source throws Exception (e.g., ServerException)
/// 2. Repository catches Exception
/// 3. Repository returns Left(Failure) to use case
///
/// Example:
/// ```dart
/// try {
///   final data = await dataSource.getData();
///   return Right(data);
/// } on ServerException catch (e) {
///   return Left(ServerFailure(e.message));
/// }
/// ```

/// Server/Network exception from Firebase or other APIs.
///
/// Thrown when:
/// - Firebase operation fails
/// - Network request times out
/// - API returns error response
class ServerException implements Exception {
  final String message;

  ServerException(this.message);

  @override
  String toString() => 'ServerException: $message';
}

/// Local cache/storage exception.
///
/// Thrown when:
/// - SharedPreferences operation fails
/// - Local database query fails
/// - File read/write fails
class CacheException implements Exception {
  final String message;

  CacheException(this.message);

  @override
  String toString() => 'CacheException: $message';
}

/// Bluetooth operation exception.
///
/// Thrown when:
/// - ESP32 BLE connection fails
/// - Characteristic read/write fails
/// - Device scan fails
/// - Bluetooth adapter unavailable
class BluetoothException implements Exception {
  final String message;

  BluetoothException(this.message);

  @override
  String toString() => 'BluetoothException: $message';
}

/// Authentication exception.
///
/// Thrown when:
/// - Firebase Auth sign in fails
/// - Invalid credentials
/// - User not found
/// - Token refresh fails
class AuthException implements Exception {
  final String message;

  AuthException(this.message);

  @override
  String toString() => 'AuthException: $message';
}
