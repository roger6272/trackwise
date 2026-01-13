import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/bluetooth_repository.dart';

/// Parameters for ClearDeviceLogsUseCase.
class ClearDeviceLogsParams extends Equatable {
  final String deviceId;

  const ClearDeviceLogsParams(this.deviceId);

  @override
  List<Object> get props => [deviceId];
}

/// Use case for clearing logs on the ESP32 device.
///
/// Called after all log pages have been retrieved and processed.
@lazySingleton
class ClearDeviceLogsUseCase extends UseCase<void, ClearDeviceLogsParams> {
  final BluetoothRepository repository;

  ClearDeviceLogsUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(ClearDeviceLogsParams params) async {
    return await repository.clearLogs(params.deviceId);
  }
}
