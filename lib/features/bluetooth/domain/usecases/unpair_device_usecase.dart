import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/bluetooth_repository.dart';

/// Parameters for UnpairDeviceUseCase.
class UnpairDeviceParams extends Equatable {
  final String deviceId;

  const UnpairDeviceParams(this.deviceId);

  @override
  List<Object> get props => [deviceId];
}

/// Use case for unpairing the device from the current account.
///
/// Clears pairing data (UID) on the device so it can be paired to another account.
/// Should be called AFTER clearing items and logs during account deletion.
@lazySingleton
class UnpairDeviceUseCase extends UseCase<void, UnpairDeviceParams> {
  final BluetoothRepository repository;

  UnpairDeviceUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(UnpairDeviceParams params) async {
    return await repository.unpairDevice(params.deviceId);
  }
}
