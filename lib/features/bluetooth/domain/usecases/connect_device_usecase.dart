import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/bluetooth_repository.dart';

/// Parameters for ConnectDeviceUseCase.
class ConnectDeviceParams extends Equatable {
  final String deviceId;

  const ConnectDeviceParams(this.deviceId);

  @override
  List<Object> get props => [deviceId];
}

/// Use case for connecting to a BLE device.
///
/// Connects to the device and validates that it has the required
/// characteristics for ESP32 communication.
@lazySingleton
class ConnectDeviceUseCase extends UseCase<bool, ConnectDeviceParams> {
  final BluetoothRepository repository;

  ConnectDeviceUseCase(this.repository);

  /// Connects to the specified device.
  ///
  /// Returns:
  /// - Right(true): Connected and device has required characteristics
  /// - Right(false): Connected but missing required characteristics
  /// - Left(BluetoothFailure): Connection failed
  @override
  Future<Either<Failure, bool>> call(ConnectDeviceParams params) async {
    return await repository.connect(params.deviceId);
  }
}
