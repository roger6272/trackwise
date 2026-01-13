import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/bluetooth_repository.dart';

/// Valid data types that can be requested from device.
enum DeviceDataType {
  /// Item preferences/status update
  prefs,

  /// Historical event logs
  logs,
}

/// Parameters for RequestDeviceDataUseCase.
class RequestDeviceDataParams extends Equatable {
  final String deviceId;
  final DeviceDataType type;
  final int page;

  const RequestDeviceDataParams({
    required this.deviceId,
    required this.type,
    this.page = 0,
  });

  /// Converts type to string for BLE command.
  String get typeString => type == DeviceDataType.prefs ? 'prefs' : 'logs';

  @override
  List<Object> get props => [deviceId, type, page];
}

/// Use case for requesting data from ESP32 device.
///
/// Requests either preferences (item status) or logs (historical events).
/// Response arrives via NOTIFY characteristic (watchMessages stream).
@lazySingleton
class RequestDeviceDataUseCase extends UseCase<void, RequestDeviceDataParams> {
  final BluetoothRepository repository;

  RequestDeviceDataUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(RequestDeviceDataParams params) async {
    // Validate page number
    if (params.page < 0) {
      return const Left(ValidationFailure('Page number cannot be negative'));
    }

    return await repository.requestData(
      params.deviceId,
      params.typeString,
      params.page,
    );
  }
}
