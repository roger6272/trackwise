import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/bluetooth_repository.dart';

/// Use case for checking if Bluetooth is enabled.
@lazySingleton
class CheckBluetoothEnabledUseCase extends UseCase<bool, NoParams> {
  final BluetoothRepository repository;

  CheckBluetoothEnabledUseCase(this.repository);

  /// Checks Bluetooth adapter state.
  ///
  /// Returns:
  /// - Right(true): Bluetooth is on
  /// - Right(false): Bluetooth is off
  /// - Left(BluetoothFailure): Failed to check adapter state
  @override
  Future<Either<Failure, bool>> call(NoParams params) async {
    return await repository.isBluetoothEnabled();
  }
}
