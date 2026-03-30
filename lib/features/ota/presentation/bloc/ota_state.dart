import 'package:equatable/equatable.dart';

import '../../domain/entities/firmware_info.dart';

/// States for the OTA BLoC.
///
/// Represents the full lifecycle of a firmware update check and transfer.
abstract class OtaBlocState extends Equatable {
  const OtaBlocState();

  @override
  List<Object?> get props => [];
}

/// Initial state — no update check performed yet.
class OtaInitial extends OtaBlocState {
  const OtaInitial();
}

/// A firmware update is available.
class OtaUpdateAvailable extends OtaBlocState {
  final FirmwareInfo info;
  final bool isRequired;

  const OtaUpdateAvailable({required this.info, required this.isRequired});

  @override
  List<Object?> get props => [info, isRequired];
}

/// The app itself needs updating before firmware can be installed.
class OtaAppUpdateRequired extends OtaBlocState {
  final String minAppVersion;

  const OtaAppUpdateRequired(this.minAppVersion);

  @override
  List<Object?> get props => [minAppVersion];
}

/// Downloading firmware binary.
class OtaBlocDownloading extends OtaBlocState {
  final double progress;
  final FirmwareInfo info;

  const OtaBlocDownloading({required this.progress, required this.info});

  @override
  List<Object?> get props => [progress, info];
}

/// Transferring firmware to device over BLE.
class OtaBlocTransferring extends OtaBlocState {
  final double progress;
  final FirmwareInfo info;

  const OtaBlocTransferring({required this.progress, required this.info});

  @override
  List<Object?> get props => [progress, info];
}

/// Device is verifying the received firmware.
class OtaBlocVerifying extends OtaBlocState {
  final FirmwareInfo info;

  const OtaBlocVerifying({required this.info});

  @override
  List<Object?> get props => [info];
}

/// Device is rebooting with new firmware.
class OtaBlocRebooting extends OtaBlocState {
  final FirmwareInfo info;

  const OtaBlocRebooting({required this.info});

  @override
  List<Object?> get props => [info];
}

/// OTA update completed successfully.
class OtaBlocComplete extends OtaBlocState {
  final String newVersion;

  const OtaBlocComplete(this.newVersion);

  @override
  List<Object?> get props => [newVersion];
}

/// OTA operation failed.
class OtaBlocError extends OtaBlocState {
  final String message;

  const OtaBlocError(this.message);

  @override
  List<Object?> get props => [message];
}

/// User dismissed optional update banner.
class OtaDismissed extends OtaBlocState {
  const OtaDismissed();
}
