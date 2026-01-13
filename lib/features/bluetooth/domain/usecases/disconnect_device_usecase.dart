import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/bluetooth_repository.dart';

/// Parameters for DisconnectDeviceUseCase.
class DisconnectDeviceParams extends Equatable {
  final String deviceId;

  const DisconnectDeviceParams(this.deviceId);

  @override
  List<Object> get props => [deviceId];
}

/// Use case for disconnecting from a BLE device.
///
/// Performs graceful disconnect and sets manual disconnect flag
/// to prevent auto-reconnection.
@lazySingleton
class DisconnectDeviceUseCase extends UseCase<void, DisconnectDeviceParams> {
  final BluetoothRepository repository;

  DisconnectDeviceUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(DisconnectDeviceParams params) async {
    return await repository.disconnect(params.deviceId);
  }
}
