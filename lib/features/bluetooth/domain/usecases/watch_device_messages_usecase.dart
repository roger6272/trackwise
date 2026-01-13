import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../entities/ble_message.dart';
import '../repositories/bluetooth_repository.dart';

/// Parameters for WatchDeviceMessagesUseCase.
class WatchDeviceMessagesParams extends Equatable {
  final String deviceId;

  const WatchDeviceMessagesParams(this.deviceId);

  @override
  List<Object> get props => [deviceId];
}

/// Use case for watching incoming messages from ESP32.
///
/// Subscribes to BLE notifications and emits parsed messages.
/// Messages include prefs updates, real-time events, and logs.
///
/// Note: Does not extend UseCase because it returns Stream, not Future.
@lazySingleton
class WatchDeviceMessagesUseCase {
  final BluetoothRepository repository;

  WatchDeviceMessagesUseCase(this.repository);

  /// Watches messages from the given device.
  ///
  /// Returns:
  /// - Stream<Right(BleMessage)>: Parsed messages from device
  /// - Stream<Left(BluetoothFailure)>: Notification failed or parse error
  Stream<Either<Failure, BleMessage>> call(WatchDeviceMessagesParams params) {
    return repository.watchMessages(params.deviceId);
  }
}
