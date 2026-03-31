import 'package:equatable/equatable.dart';

import '../../domain/entities/firmware_info.dart';
import '../../domain/entities/ota_state.dart' as domain;

/// Base class for all OTA BLoC events.
abstract class OtaEvent extends Equatable {
  const OtaEvent();

  @override
  List<Object?> get props => [];
}

/// Triggered on device connect after handshake completes.
class CheckForUpdateRequested extends OtaEvent {
  final String deviceFirmwareVersion;
  final String deviceInstanceId;

  const CheckForUpdateRequested(
    this.deviceFirmwareVersion, {
    required this.deviceInstanceId,
  });

  @override
  List<Object?> get props => [deviceFirmwareVersion, deviceInstanceId];
}

/// User taps "Update Now".
class StartUpdateRequested extends OtaEvent {
  final FirmwareInfo firmwareInfo;
  final int negotiatedMtu;
  final String deviceInstanceId;

  const StartUpdateRequested({
    required this.firmwareInfo,
    required this.negotiatedMtu,
    required this.deviceInstanceId,
  });

  @override
  List<Object?> get props => [firmwareInfo, negotiatedMtu, deviceInstanceId];
}

/// User taps Cancel during update.
class CancelUpdateRequested extends OtaEvent {
  const CancelUpdateRequested();
}

/// User dismisses optional update banner.
class DismissUpdateBanner extends OtaEvent {
  final String deviceInstanceId;

  const DismissUpdateBanner({required this.deviceInstanceId});

  @override
  List<Object?> get props => [deviceInstanceId];
}

/// Progress update from PerformOtaUpdate stream.
class OtaProgressUpdated extends OtaEvent {
  final domain.OtaState progress;

  const OtaProgressUpdated(this.progress);

  @override
  List<Object?> get props => [progress];
}

/// After reconnect + handshake verifies new version.
class OtaRebootCompleted extends OtaEvent {
  final String newVersion;
  final String deviceInstanceId;

  const OtaRebootCompleted(
    this.newVersion, {
    required this.deviceInstanceId,
  });

  @override
  List<Object?> get props => [newVersion, deviceInstanceId];
}

/// Device didn't reconnect within 30s.
class OtaRebootTimedOut extends OtaEvent {
  const OtaRebootTimedOut();
}

/// A device disconnected — remove its OTA tracking state.
class OtaDeviceDisconnected extends OtaEvent {
  final String deviceInstanceId;

  const OtaDeviceDisconnected({required this.deviceInstanceId});

  @override
  List<Object?> get props => [deviceInstanceId];
}
