import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/bluetooth_repository.dart';

/// Use case for requesting Bluetooth permissions.
///
/// On Android 12+: BLUETOOTH_SCAN, BLUETOOTH_CONNECT
/// Also requests location permission for BLE scanning.
@lazySingleton
class RequestBluetoothPermissionsUseCase extends UseCase<bool, NoParams> {
  final BluetoothRepository repository;

  RequestBluetoothPermissionsUseCase(this.repository);

  /// Requests all required Bluetooth permissions.
  ///
  /// Returns:
  /// - Right(true): All permissions granted
  /// - Right(false): One or more permissions denied
  /// - Left(BluetoothFailure): Permission request failed
  @override
  Future<Either<Failure, bool>> call(NoParams params) async {
    return await repository.requestPermissions();
  }
}
