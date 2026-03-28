import 'package:equatable/equatable.dart';

/// Represents the current state of an OTA firmware update process.
sealed class OtaState extends Equatable {
  const OtaState();

  @override
  List<Object?> get props => [];
}

/// No OTA operation in progress.
class OtaIdle extends OtaState {
  const OtaIdle();
}

/// Checking for available firmware updates.
class OtaChecking extends OtaState {
  const OtaChecking();
}

/// A newer firmware version is available (optional update).
class OtaAvailable extends OtaState {
  const OtaAvailable();
}

/// Device firmware is below minimum required version (forced update).
class OtaRequired extends OtaState {
  const OtaRequired();
}

/// Downloading firmware binary from Firebase Storage.
class OtaDownloading extends OtaState {
  /// Download progress from 0.0 to 1.0.
  final double progress;

  const OtaDownloading(this.progress);

  @override
  List<Object?> get props => [progress];
}

/// Transferring firmware binary to device over BLE.
class OtaTransferring extends OtaState {
  /// Transfer progress from 0.0 to 1.0.
  final double progress;

  const OtaTransferring(this.progress);

  @override
  List<Object?> get props => [progress];
}

/// Device is verifying the received firmware (SHA256 check).
class OtaVerifying extends OtaState {
  const OtaVerifying();
}

/// Device is rebooting with the new firmware.
class OtaRebooting extends OtaState {
  const OtaRebooting();
}

/// OTA update completed successfully.
class OtaComplete extends OtaState {
  const OtaComplete();
}

/// OTA operation failed.
class OtaError extends OtaState {
  final String message;

  const OtaError(this.message);

  @override
  List<Object?> get props => [message];
}
