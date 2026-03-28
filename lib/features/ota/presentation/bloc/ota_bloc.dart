import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/connectivity_service.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/firmware_info.dart';
import '../../domain/entities/ota_state.dart' as domain;
import '../../domain/usecases/check_for_update.dart';
import '../../domain/usecases/perform_ota_update.dart';
import 'ota_event.dart';
import 'ota_state.dart';

/// BLoC for managing OTA firmware update lifecycle.
///
/// Handles:
/// - Checking for available firmware updates after device connect
/// - Download, transfer, verify, reboot flow via PerformOtaUpdate
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
  FirmwareInfo? _currentFirmwareInfo;
  String? _deviceFirmwareVersion;
  DateTime? _otaStartTime;

  /// Duration to wait for device reconnect after OTA reboot.
  static const Duration _rebootTimeout = Duration(seconds: 30);

  OtaBloc(
    this._checkForUpdate,
    this._performOtaUpdate,
    this._analytics,
    this._connectivity,
  ) : super(const OtaInitial()) {
    on<CheckForUpdateRequested>(_onCheckForUpdate);
    on<StartUpdateRequested>(_onStartUpdate);
    on<CancelUpdateRequested>(_onCancelUpdate);
    on<DismissUpdateBanner>(_onDismissBanner);
    on<OtaProgressUpdated>(_onProgressUpdated);
    on<OtaRebootCompleted>(_onRebootCompleted);
    on<OtaRebootTimedOut>(_onRebootTimedOut);
  }

  Future<void> _onCheckForUpdate(
    CheckForUpdateRequested event,
    Emitter<OtaBlocState> emit,
  ) async {
    AppLogger.debug('OTA: Checking for update (device: v${event.deviceFirmwareVersion})');
    _deviceFirmwareVersion = event.deviceFirmwareVersion;

    final result = await _checkForUpdate.call(
      CheckForUpdateParams(deviceFirmwareVersion: event.deviceFirmwareVersion),
    );

    result.fold(
      (failure) {
        AppLogger.error('OTA: Update check failed: ${failure.message}');
        // Don't emit error for check failures — silently stay in initial state
      },
      (checkResult) {
        switch (checkResult) {
          case UpdateAvailable():
            _currentFirmwareInfo = checkResult.firmwareInfo;
            emit(OtaUpdateAvailable(
              info: checkResult.firmwareInfo,
              isRequired: checkResult.isRequired,
            ));
          case AppUpdateRequired():
            emit(OtaAppUpdateRequired(checkResult.minAppVersion));
          case UpToDate():
            AppLogger.debug('OTA: Firmware is up to date');
            // Stay in initial state — no banner needed
          case CheckFailed():
            AppLogger.debug('OTA: Check failed: ${checkResult.reason}');
            // Stay in initial state — don't bother user with check failures
        }
      },
    );
  }

  Future<void> _onStartUpdate(
    StartUpdateRequested event,
    Emitter<OtaBlocState> emit,
  ) async {
    // Check internet connectivity before starting
    final hasInternet = await _connectivity.hasInternetConnection();
    if (!hasInternet) {
      emit(const OtaBlocError('No internet connection. Connect to Wi-Fi or mobile data and try again.'));
      return;
    }

    _currentFirmwareInfo = event.firmwareInfo;
    _otaStartTime = DateTime.now();
    emit(OtaBlocDownloading(progress: 0.0, info: event.firmwareInfo));

    _analytics.logOtaStarted(
      fromVersion: _deviceFirmwareVersion ?? 'unknown',
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

    // Determine progress at cancel time
    double progressPercent = 0.0;
    final s = state;
    if (s is OtaBlocDownloading) {
      progressPercent = s.progress * 100;
    } else if (s is OtaBlocTransferring) {
      progressPercent = s.progress * 100;
    }

    _analytics.logOtaCancelled(
      fromVersion: _deviceFirmwareVersion ?? 'unknown',
      toVersion: _currentFirmwareInfo?.version ?? 'unknown',
      progressPercent: progressPercent,
    );

    _otaSubscription?.cancel();
    _otaSubscription = null;
    _rebootTimer?.cancel();
    _rebootTimer = null;

    // Return to update available state if we have firmware info
    if (_currentFirmwareInfo != null) {
      emit(OtaUpdateAvailable(
        info: _currentFirmwareInfo!,
        isRequired: false, // If they can cancel, it's not required
      ));
    } else {
      emit(const OtaInitial());
    }
  }

  void _onDismissBanner(
    DismissUpdateBanner event,
    Emitter<OtaBlocState> emit,
  ) {
    emit(const OtaDismissed());
  }

  void _onProgressUpdated(
    OtaProgressUpdated event,
    Emitter<OtaBlocState> emit,
  ) {
    final info = _currentFirmwareInfo;
    if (info == null) return;

    final progress = event.progress;

    switch (progress) {
      case domain.OtaDownloading():
        emit(OtaBlocDownloading(progress: progress.progress, info: info));
      case domain.OtaTransferring():
        emit(OtaBlocTransferring(progress: progress.progress, info: info));
      case domain.OtaVerifying():
        emit(OtaBlocVerifying(info: info));
      case domain.OtaRebooting():
        emit(OtaBlocRebooting(info: info));
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
          fromVersion: _deviceFirmwareVersion ?? 'unknown',
          toVersion: info.version,
        );
        emit(OtaBlocError(progress.message));
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

    final durationSeconds = _otaStartTime != null
        ? DateTime.now().difference(_otaStartTime!).inSeconds
        : 0;
    _analytics.logOtaCompleted(
      fromVersion: _deviceFirmwareVersion ?? 'unknown',
      toVersion: event.newVersion,
      durationSeconds: durationSeconds,
    );

    emit(OtaBlocComplete(event.newVersion));
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

    _analytics.logOtaFailed(
      reason: 'Reboot timed out — device did not reconnect',
      fromVersion: _deviceFirmwareVersion ?? 'unknown',
      toVersion: _currentFirmwareInfo?.version ?? 'unknown',
    );

    emit(const OtaBlocError(
      'Device didn\'t respond after update. Try turning it off and on again.',
    ));
  }

  /// Whether an OTA transfer is actively in progress (download, transfer, verify, reboot).
  bool get isTransferInProgress {
    final s = state;
    return s is OtaBlocDownloading ||
        s is OtaBlocTransferring ||
        s is OtaBlocVerifying ||
        s is OtaBlocRebooting;
  }

  @override
  Future<void> close() {
    _otaSubscription?.cancel();
    _rebootTimer?.cancel();
    return super.close();
  }
}
