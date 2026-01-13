import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/bluetooth_repository.dart';

/// Parameters for SendTimeSyncUseCase.
class SendTimeSyncParams extends Equatable {
  final String deviceId;

  const SendTimeSyncParams(this.deviceId);

  @override
  List<Object> get props => [deviceId];
}

/// Use case for syncing device clock with current time.
///
/// Sends UTC time and timezone offset to ESP32 for accurate timestamps.
@lazySingleton
class SendTimeSyncUseCase extends UseCase<void, SendTimeSyncParams> {
  final BluetoothRepository repository;

  SendTimeSyncUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(SendTimeSyncParams params) async {
    return await repository.sendTimeSync(params.deviceId);
  }
}
