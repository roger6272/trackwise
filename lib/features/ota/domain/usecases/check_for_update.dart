import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/logger.dart';
import '../entities/firmware_info.dart';
import '../repositories/ota_repository.dart';

/// Parameters for [CheckForUpdateUseCase].
class CheckForUpdateParams extends Equatable {
  /// Current firmware version reported by the device (e.g., "1.5.0").
  final String deviceFirmwareVersion;

  const CheckForUpdateParams({required this.deviceFirmwareVersion});

  @override
  List<Object?> get props => [deviceFirmwareVersion];
}

/// Result of checking for a firmware update.
sealed class UpdateCheckResult extends Equatable {
  const UpdateCheckResult();

  @override
  List<Object?> get props => [];
}

/// A firmware update is available.
class UpdateAvailable extends UpdateCheckResult {
  /// Whether this update is optional or required.
  final bool isRequired;

  /// Metadata about the available firmware.
  final FirmwareInfo firmwareInfo;

  const UpdateAvailable({required this.isRequired, required this.firmwareInfo});

  @override
  List<Object?> get props => [isRequired, firmwareInfo];
}

/// The app itself needs to be updated before firmware can be installed.
class AppUpdateRequired extends UpdateCheckResult {
  /// The minimum app version required by the firmware.
  final String minAppVersion;

  const AppUpdateRequired({required this.minAppVersion});

  @override
  List<Object?> get props => [minAppVersion];
}

/// Device firmware is already up to date.
class UpToDate extends UpdateCheckResult {
  const UpToDate();
}

/// Update check failed.
class CheckFailed extends UpdateCheckResult {
  final String reason;

  const CheckFailed({required this.reason});

  @override
  List<Object?> get props => [reason];
}

/// Use case for checking if a firmware update is available.
///
/// Compares:
/// 1. Device firmware version against latest available from Firebase Storage
/// 2. Device firmware version against min_firmware_version from Remote Config
/// 3. Current app version against min_app_version from latest.json
///
/// Returns:
/// - [UpdateAvailable] with isRequired=true if device < min_firmware_version
/// - [UpdateAvailable] with isRequired=false if device < latest version
/// - [AppUpdateRequired] if app version < min_app_version from latest.json
/// - [UpToDate] if device firmware is already at or above latest version
/// - [CheckFailed] if the check could not be completed
@lazySingleton
class CheckForUpdateUseCase extends UseCase<UpdateCheckResult, CheckForUpdateParams> {
  final OtaRepository _repository;

  CheckForUpdateUseCase(this._repository);

  @override
  Future<Either<Failure, UpdateCheckResult>> call(CheckForUpdateParams params) async {
    final deviceVersion = params.deviceFirmwareVersion;

    AppLogger.debug('Checking for firmware update (device: v$deviceVersion)');

    // Fetch latest firmware info
    final infoResult = await _repository.fetchLatestFirmwareInfo();
    if (infoResult.isLeft()) {
      return Right(CheckFailed(
        reason: infoResult.fold((f) => f.message, (_) => 'Unknown error'),
      ));
    }

    final firmwareInfo = infoResult.fold((_) => null, (info) => info)!;

    // Check if app version meets minimum requirement
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final appVersion = packageInfo.version;

      if (compareSemver(appVersion, firmwareInfo.minAppVersion) < 0) {
        AppLogger.debug(
            'App version $appVersion < min_app_version ${firmwareInfo.minAppVersion}');
        return Right(AppUpdateRequired(minAppVersion: firmwareInfo.minAppVersion));
      }
    } catch (e) {
      AppLogger.error('Failed to get app version', e);
      // Continue with update check — better to allow update than block on app version check failure
    }

    // Check if device is already up to date
    final latestVersion = firmwareInfo.version;
    if (compareSemver(deviceVersion, latestVersion) >= 0) {
      AppLogger.debug('Firmware is up to date (device: v$deviceVersion, latest: v$latestVersion)');
      return const Right(UpToDate());
    }

    // Firmware update is available — check if required
    final minResult = await _repository.fetchMinFirmwareVersion();
    final minFirmwareVersion = minResult.fold(
      (_) => '1.0.0', // Fallback on failure
      (version) => version,
    );

    final isRequired = compareSemver(deviceVersion, minFirmwareVersion) < 0;
    AppLogger.debug(
      'Update available: v$deviceVersion → v$latestVersion '
      '(required: $isRequired, min: v$minFirmwareVersion)',
    );

    return Right(UpdateAvailable(
      isRequired: isRequired,
      firmwareInfo: firmwareInfo,
    ));
  }

  /// Compares two semver version strings.
  ///
  /// Returns:
  /// - negative if [a] < [b]
  /// - zero if [a] == [b]
  /// - positive if [a] > [b]
  ///
  /// Handles edge cases like "1.9.0" vs "1.10.0" correctly by parsing
  /// each component as an integer.
  static int compareSemver(String a, String b) {
    final aParts = _parseSemver(a);
    final bParts = _parseSemver(b);

    for (int i = 0; i < 3; i++) {
      final diff = aParts[i] - bParts[i];
      if (diff != 0) return diff;
    }
    return 0;
  }

  /// Parses a semver string into [major, minor, patch].
  ///
  /// Handles malformed versions by defaulting missing/invalid parts to 0.
  static List<int> _parseSemver(String version) {
    final parts = version.split('.');
    return [
      parts.isNotEmpty ? (int.tryParse(parts[0]) ?? 0) : 0,
      parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
      parts.length > 2 ? (int.tryParse(parts[2]) ?? 0) : 0,
    ];
  }
}
