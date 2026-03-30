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

  const CheckForUpdateRequested(this.deviceFirmwareVersion);

  @override
  List<Object?> get props => [deviceFirmwareVersion];
}

/// User taps "Update Now".
class StartUpdateRequested extends OtaEvent {
  final FirmwareInfo firmwareInfo;
  final int negotiatedMtu;

  const StartUpdateRequested({
    required this.firmwareInfo,
    required this.negotiatedMtu,
  });

  @override
  List<Object?> get props => [firmwareInfo, negotiatedMtu];
}

/// User taps Cancel during update.
class CancelUpdateRequested extends OtaEvent {
  const CancelUpdateRequested();
}

/// User dismisses optional update banner.
class DismissUpdateBanner extends OtaEvent {
  const DismissUpdateBanner();
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

  const OtaRebootCompleted(this.newVersion);

  @override
  List<Object?> get props => [newVersion];
}

/// Device didn't reconnect within 30s.
class OtaRebootTimedOut extends OtaEvent {
  const OtaRebootTimedOut();
}
