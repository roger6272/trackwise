import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../entities/ble_connection_state.dart';
import '../repositories/bluetooth_repository.dart';

/// Parameters for WatchConnectionStateUseCase.
class WatchConnectionStateParams extends Equatable {
  final String deviceId;

  const WatchConnectionStateParams(this.deviceId);

  @override
  List<Object> get props => [deviceId];
}

/// Use case for watching connection state changes.
///
/// Returns a stream that emits whenever the connection state changes.
/// Used for auto-reconnect logic and UI updates.
///
/// Note: Does not extend UseCase because it returns Stream, not Future.
@lazySingleton
class WatchConnectionStateUseCase {
  final BluetoothRepository repository;

  WatchConnectionStateUseCase(this.repository);

  /// Watches connection state for the given device.
  ///
  /// Returns:
  /// - Stream<Right(BleConnectionState)>: Connection state updates
  /// - Stream<Left(BluetoothFailure)>: Failed to monitor connection
  Stream<Either<Failure, BleConnectionState>> call(
    WatchConnectionStateParams params,
  ) {
    return repository.watchConnectionState(params.deviceId);
  }
}
