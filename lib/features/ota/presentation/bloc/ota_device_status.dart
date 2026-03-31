import 'package:equatable/equatable.dart';

import '../../domain/entities/firmware_info.dart';

/// Per-device OTA awareness status.
///
/// Tracks whether each connected device needs an update, independent of
/// whether a transfer is actively in progress.
sealed class OtaDeviceStatus extends Equatable {
  const OtaDeviceStatus();

  @override
  List<Object?> get props => [];
}

/// Device firmware is up to date — no action needed.
class OtaDeviceUpToDate extends OtaDeviceStatus {
  const OtaDeviceUpToDate();
}

/// A firmware update is available for this device.
class OtaDeviceUpdateAvailable extends OtaDeviceStatus {
  final FirmwareInfo info;
  final bool isRequired;

  const OtaDeviceUpdateAvailable({
    required this.info,
    required this.isRequired,
  });

  @override
  List<Object?> get props => [info, isRequired];
}

/// The app itself needs updating before this device's firmware can be installed.
class OtaDeviceAppUpdateRequired extends OtaDeviceStatus {
  final String minAppVersion;

  const OtaDeviceAppUpdateRequired(this.minAppVersion);

  @override
  List<Object?> get props => [minAppVersion];
}

/// User dismissed the optional update banner for this device.
class OtaDeviceDismissed extends OtaDeviceStatus {
  const OtaDeviceDismissed();
}
