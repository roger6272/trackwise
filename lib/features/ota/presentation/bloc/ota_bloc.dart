import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/connectivity_service.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/ota_state.dart' as domain;
import '../../domain/usecases/check_for_update.dart';
import '../../domain/usecases/perform_ota_update.dart';
import 'ota_device_status.dart';
import 'ota_event.dart';
import 'ota_state.dart';

/// BLoC for managing OTA firmware update lifecycle.
///
/// Handles:
/// - Per-device update awareness (which devices need updates)
/// - Single active OTA transfer (download, transfer, verify, reboot)
/// - Cancel support
/// - Post-reboot verification
@lazySingleton
class OtaBloc extends Bloc<OtaEvent, OtaBlocState> {
  final CheckForUpdateUseCase _checkForUpdate;
  final PerformOtaUpdateUseCase _performOtaUpdate;
  final AnalyticsService _analytics;
  final ConnectivityService _connectivity;

  StreamSubscription<domain.OtaState>? _otaSubscription;
  Timer? _rebootTimer;
  final Map<String, String> _deviceFirmwareVersions = {};
  DateTime? _otaStartTime;

  /// Duration to wait for device reconnect after OTA reboot.
  static const Duration _rebootTimeout = Duration(seconds: 60);

  OtaBloc(
    this._checkForUpdate,
    this._performOtaUpdate,
    this._analytics,
    this._connectivity,
  ) : super(const OtaBlocState()) {
    on<CheckForUpdateRequested>(_onCheckForUpdate);
    on<StartUpdateRequested>(_onStartUpdate);
    on<CancelUpdateRequested>(_onCancelUpdate);
    on<DismissUpdateBanner>(_onDismissBanner);
    on<OtaProgressUpdated>(_onProgressUpdated);
    on<OtaRebootCompleted>(_onRebootCompleted);
    on<OtaRebootTimedOut>(_onRebootTimedOut);
    on<OtaDeviceDisconnected>(_onDeviceDisconnected);
    on<DismissTransferResult>(_onDismissTransferResult);
  }

  Future<void> _onCheckForUpdate(
    CheckForUpdateRequested event,
    Emitter<OtaBlocState> emit,
  ) async {
    final deviceId = event.deviceInstanceId;
    AppLogger.debug(
      'OTA: Checking for update (device: $deviceId, v${event.deviceFirmwareVersion})',
    );
    _deviceFirmwareVersions[deviceId] = event.deviceFirmwareVersion;

    final result = await _checkForUpdate.call(
      CheckForUpdateParams(
        deviceFirmwareVersion: event.deviceFirmwareVersion,
      ),
    );

    result.fold(
      (failure) {
        AppLogger.error('OTA: Update check failed: ${failure.message}');
        // Don't emit error for check failures — silently keep current state
      },
      (checkResult) {
        final updatedStatuses =
            Map<String, OtaDeviceStatus>.from(state.deviceStatuses);

        switch (checkResult) {
          case UpdateAvailable():
            updatedStatuses[deviceId] = OtaDeviceUpdateAvailable(
              info: checkResult.firmwareInfo,
              isRequired: checkResult.isRequired,
            );
            emit(state.copyWith(deviceStatuses: updatedStatuses));
          case AppUpdateRequired():
            updatedStatuses[deviceId] =
                OtaDeviceAppUpdateRequired(checkResult.minAppVersion);
            emit(state.copyWith(deviceStatuses: updatedStatuses));
          case UpToDate():
            AppLogger.debug('OTA: Firmware is up to date ($deviceId)');
            updatedStatuses[deviceId] = const OtaDeviceUpToDate();
            emit(state.copyWith(deviceStatuses: updatedStatuses));
          case CheckFailed():
            AppLogger.debug('OTA: Check failed: ${checkResult.reason}');
            // Don't update device status — don't bother user with check failures
        }
      },
    );
  }

  Future<void> _onStartUpdate(
    StartUpdateRequested event,
    Emitter<OtaBlocState> emit,
  ) async {
    // Only one transfer at a time
    if (state.isTransferInProgress) return;

    // Check internet connectivity before starting
    final hasInternet = await _connectivity.hasInternetConnection();
    if (!hasInternet) {
      emit(state.copyWith(
        activeTransfer: OtaTransferError(
          deviceInstanceId: event.deviceInstanceId,
          info: event.firmwareInfo,
          message:
              'No internet connection. Connect to Wi-Fi or mobile data and try again.',
        ),
      ));
      return;
    }

    final deviceId = event.deviceInstanceId;
    _otaStartTime = DateTime.now();
    _setWakelock(true);

    emit(state.copyWith(
      activeTransfer: OtaTransferDownloading(
        deviceInstanceId: deviceId,
        info: event.firmwareInfo,
        progress: 0.0,
      ),
    ));

    _analytics.logOtaStarted(
      fromVersion: _deviceFirmwareVersions[deviceId] ?? 'unknown',
      toVersion: event.firmwareInfo.version,
    );

    // Start the OTA update stream
    _otaSubscription?.cancel();
    _otaSubscription = _performOtaUpdate
        .execute(
          firmwareInfo: event.firmwareInfo,
          negotiatedMtu: event.negotiatedMtu,
        )
        .listen(
          (otaState) => add(OtaProgressUpdated(otaState)),
          onError: (error) {
            AppLogger.error('OTA: Stream error', error);
            add(OtaProgressUpdated(domain.OtaError('Unexpected error: $error')));
          },
        );
  }

  void _onCancelUpdate(
    CancelUpdateRequested event,
    Emitter<OtaBlocState> emit,
  ) {
    AppLogger.debug('OTA: Update cancelled by user');

    final transfer = state.activeTransfer;
    if (transfer == null) return;

    // Determine progress at cancel time
    double progressPercent = 0.0;
    if (transfer is OtaTransferDownloading) {
      progressPercent = transfer.progress * 100;
    } else if (transfer is OtaTransferTransferring) {
      progressPercent = transfer.progress * 100;
    }

    final deviceId = transfer?.deviceInstanceId;
    final info = transfer?.info;

    _analytics.logOtaCancelled(
      fromVersion: deviceId != null
          ? (_deviceFirmwareVersions[deviceId] ?? 'unknown')
          : 'unknown',
      toVersion: info?.version ?? 'unknown',
      progressPercent: progressPercent,
    );

    _otaSubscription?.cancel();
    _otaSubscription = null;
    _rebootTimer?.cancel();
    _rebootTimer = null;
    _setWakelock(false);

    // Tell the device to exit OTA mode immediately (best-effort)
    _performOtaUpdate.abort();

    // Restore device to update available if we have info
    if (deviceId != null && info != null) {
      // Preserve original isRequired — a required update stays required after cancel
      final previousStatus = state.deviceStatuses[deviceId];
      final wasRequired = previousStatus is OtaDeviceUpdateAvailable &&
          previousStatus.isRequired;

      final updatedStatuses =
          Map<String, OtaDeviceStatus>.from(state.deviceStatuses);
      updatedStatuses[deviceId] = OtaDeviceUpdateAvailable(
        info: info,
        isRequired: wasRequired,
      );
      emit(state.copyWith(
        deviceStatuses: updatedStatuses,
        clearActiveTransfer: true,
      ));
    } else {
      emit(state.copyWith(clearActiveTransfer: true));
    }
  }

  void _onDismissBanner(
    DismissUpdateBanner event,
    Emitter<OtaBlocState> emit,
  ) {
    final updatedStatuses =
        Map<String, OtaDeviceStatus>.from(state.deviceStatuses);
    updatedStatuses[event.deviceInstanceId] = const OtaDeviceDismissed();
    emit(state.copyWith(deviceStatuses: updatedStatuses));
  }

  void _onProgressUpdated(
    OtaProgressUpdated event,
    Emitter<OtaBlocState> emit,
  ) {
    final transfer = state.activeTransfer;
    if (transfer == null) return;

    final deviceId = transfer.deviceInstanceId;
    final info = transfer.info;
    final progress = event.progress;

    switch (progress) {
      case domain.OtaDownloading():
        emit(state.copyWith(
          activeTransfer: OtaTransferDownloading(
            deviceInstanceId: deviceId,
            info: info,
            progress: progress.progress,
          ),
        ));
      case domain.OtaTransferring():
        emit(state.copyWith(
          activeTransfer: OtaTransferTransferring(
            deviceInstanceId: deviceId,
            info: info,
            progress: progress.progress,
          ),
        ));
      case domain.OtaVerifying():
        emit(state.copyWith(
          activeTransfer: OtaTransferVerifying(
            deviceInstanceId: deviceId,
            info: info,
          ),
        ));
      case domain.OtaRebooting():
        emit(state.copyWith(
          activeTransfer: OtaTransferRebooting(
            deviceInstanceId: deviceId,
            info: info,
          ),
        ));
        // Start reboot timeout timer
        _rebootTimer?.cancel();
        _rebootTimer = Timer(_rebootTimeout, () {
          if (!isClosed) {
            add(const OtaRebootTimedOut());
          }
        });
      case domain.OtaComplete():
        // OtaRebooting already started the reboot timer — nothing to do here.
        // Wait for reconnect + version verification via OtaRebootCompleted event.
        break;
      case domain.OtaError():
        _analytics.logOtaFailed(
          reason: progress.message,
          fromVersion: _deviceFirmwareVersions[deviceId] ?? 'unknown',
          toVersion: info.version,
        );
        _setWakelock(false);
        emit(state.copyWith(
          activeTransfer: OtaTransferError(
            deviceInstanceId: deviceId,
            info: info,
            message: progress.message,
          ),
        ));
        _otaSubscription?.cancel();
        _otaSubscription = null;
      default:
        // OtaIdle, OtaChecking, OtaAvailable, OtaRequired — not expected during transfer
        break;
    }
  }

  void _onRebootCompleted(
    OtaRebootCompleted event,
    Emitter<OtaBlocState> emit,
  ) {
    AppLogger.debug('OTA: Reboot completed, new version: ${event.newVersion}');
    _rebootTimer?.cancel();
    _rebootTimer = null;
    _otaSubscription?.cancel();
    _otaSubscription = null;

    final deviceId = event.deviceInstanceId;
    final durationSeconds = _otaStartTime != null
        ? DateTime.now().difference(_otaStartTime!).inSeconds
        : 0;
    final fromVersion = _deviceFirmwareVersions[deviceId] ?? 'unknown';
    final info = state.activeTransfer?.info;

    _setWakelock(false);

    // The device is back — but is it actually running what we installed? Reconnecting
    // is NOT proof of success. If the new image boots and crashes before it finishes
    // starting up, the bootloader silently reverts to the previous firmware and the
    // device comes back on the OLD version. Without this check the app would report
    // "Complete" on an update that was rolled back, and mark the device up to date.
    //
    // This check is only trustworthy because publish_firmware.sh now refuses to ship
    // a binary whose FIRMWARE_VERSION disagrees with the manifest — see the version
    // drift guard there. If those two ever diverge again, this reports false failures.
    if (info != null &&
        CheckForUpdateUseCase.compareSemver(event.newVersion, info.version) < 0) {
      AppLogger.error(
        'OTA: device came back on v${event.newVersion}, expected v${info.version} — '
        'firmware was rolled back or never applied',
      );
      _analytics.logOtaFailed(
        reason: 'rolled_back',
        fromVersion: fromVersion,
        toVersion: info.version,
      );

      // Preserve isRequired — a mandatory update stays mandatory after a rollback.
      final previousStatus = state.deviceStatuses[deviceId];
      final wasRequired = previousStatus is OtaDeviceUpdateAvailable &&
          previousStatus.isRequired;

      final rolledBackStatuses =
          Map<String, OtaDeviceStatus>.from(state.deviceStatuses);
      rolledBackStatuses[deviceId] = OtaDeviceUpdateAvailable(
        info: info,
        isRequired: wasRequired,
      );

      emit(state.copyWith(
        deviceStatuses: rolledBackStatuses,
        activeTransfer: OtaTransferError(
          deviceInstanceId: deviceId,
          info: info,
          message: 'The device restarted on its old software. '
              'The update did not take effect — please try again.',
        ),
      ));
      return;
    }

    _analytics.logOtaCompleted(
      fromVersion: fromVersion,
      toVersion: event.newVersion,
      durationSeconds: durationSeconds,
    );

    final updatedStatuses =
        Map<String, OtaDeviceStatus>.from(state.deviceStatuses);
    updatedStatuses[deviceId] = const OtaDeviceUpToDate();

    if (info != null) {
      emit(state.copyWith(
        deviceStatuses: updatedStatuses,
        activeTransfer: OtaTransferComplete(
          deviceInstanceId: deviceId,
          info: info,
          newVersion: event.newVersion,
        ),
      ));
    } else {
      emit(state.copyWith(
        deviceStatuses: updatedStatuses,
        clearActiveTransfer: true,
      ));
    }
  }

  void _onRebootTimedOut(
    OtaRebootTimedOut event,
    Emitter<OtaBlocState> emit,
  ) {
    AppLogger.debug('OTA: Reboot timed out — device did not reconnect');
    _rebootTimer?.cancel();
    _rebootTimer = null;
    _otaSubscription?.cancel();
    _otaSubscription = null;
    _setWakelock(false);

    final transfer = state.activeTransfer;
    if (transfer == null) return;

    final deviceId = transfer.deviceInstanceId;
    final info = transfer.info;

    _analytics.logOtaFailed(
      reason: 'Reboot timed out — device did not reconnect',
      fromVersion: _deviceFirmwareVersions[deviceId] ?? 'unknown',
      toVersion: info.version,
    );

    emit(state.copyWith(
      activeTransfer: OtaTransferError(
        deviceInstanceId: deviceId,
        info: info,
        message:
            'Device didn\'t respond after update. Try turning it off and on again.',
      ),
    ));
  }

  void _onDeviceDisconnected(
    OtaDeviceDisconnected event,
    Emitter<OtaBlocState> emit,
  ) {
    final deviceId = event.deviceInstanceId;
    AppLogger.debug('OTA: Device disconnected ($deviceId)');

    _deviceFirmwareVersions.remove(deviceId);

    final updatedStatuses =
        Map<String, OtaDeviceStatus>.from(state.deviceStatuses);
    updatedStatuses.remove(deviceId);

    // If the disconnected device has the active transfer, cancel it —
    // UNLESS it's in the rebooting state, where disconnect is expected.
    final transfer = state.activeTransfer;
    if (state.activeDeviceId == deviceId &&
        state.isTransferInProgress &&
        transfer is! OtaTransferRebooting) {
      _otaSubscription?.cancel();
      _otaSubscription = null;
      _rebootTimer?.cancel();
      _rebootTimer = null;
      _setWakelock(false);

      emit(state.copyWith(
        deviceStatuses: updatedStatuses,
        activeTransfer: OtaTransferError(
          deviceInstanceId: deviceId,
          info: transfer!.info,
          message: 'Device disconnected during update.',
        ),
      ));
    } else {
      emit(state.copyWith(deviceStatuses: updatedStatuses));
    }
  }

  void _onDismissTransferResult(
    DismissTransferResult event,
    Emitter<OtaBlocState> emit,
  ) {
    if (state.activeTransfer is OtaTransferComplete ||
        state.activeTransfer is OtaTransferError) {
      emit(state.copyWith(clearActiveTransfer: true));
    }
  }

  void _setWakelock(bool enabled) {
    try {
      final future =
          enabled ? WakelockPlus.enable() : WakelockPlus.disable();
      future.catchError((_) {
        // WakeLock unavailable (e.g., in tests) — non-critical
      });
    } catch (_) {
      // WakeLock unavailable (e.g., in tests) — non-critical
    }
  }

  @override
  Future<void> close() {
    _otaSubscription?.cancel();
    _rebootTimer?.cancel();
    return super.close();
  }
}
