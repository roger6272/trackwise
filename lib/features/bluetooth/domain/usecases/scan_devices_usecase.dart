import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../entities/ble_device.dart';
import '../repositories/bluetooth_repository.dart';

/// Parameters for ScanDevicesUseCase.
class ScanDevicesParams extends Equatable {
  final Duration timeout;

  const ScanDevicesParams({
    this.timeout = const Duration(seconds: 15),
  });

  @override
  List<Object> get props => [timeout];
}

/// Use case for scanning for nearby BLE devices.
///
/// Returns a stream that emits the list of discovered devices
/// as they are found. Stream completes when timeout expires.
///
/// Note: Does not extend UseCase because it returns Stream, not Future.
@lazySingleton
class ScanDevicesUseCase {
  final BluetoothRepository repository;

  ScanDevicesUseCase(this.repository);

  /// Starts scanning for BLE devices.
  ///
  /// Returns:
  /// - Stream<Right(List<BleDevice>)>: Discovered devices (updates as found)
  /// - Stream<Left(BluetoothFailure)>: Scan failed
  Stream<Either<Failure, List<BleDevice>>> call(ScanDevicesParams params) {
    return repository.scanDevices(timeout: params.timeout);
  }
}
