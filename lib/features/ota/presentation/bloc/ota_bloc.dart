import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

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
@injectable
class OtaBloc extends Bloc<OtaEvent, OtaBlocState> {
  final CheckForUpdateUseCase _checkForUpdate;
  final PerformOtaUpdateUseCase _performOtaUpdate;

  StreamSubscription<domain.OtaState>? _otaSubscription;
  Timer? _rebootTimer;
  FirmwareInfo? _currentFirmwareInfo;

  /// Duration to wait for device reconnect after OTA reboot.
  static const Duration _rebootTimeout = Duration(seconds: 30);

  OtaBloc(this._checkForUpdate, this._performOtaUpdate)
      : super(const OtaInitial()) {
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
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.every((r) => r == ConnectivityResult.none)) {
      emit(const OtaBlocError('No internet connection. Connect to Wi-Fi or mobile data and try again.'));
      return;
    }

    _currentFirmwareInfo = event.firmwareInfo;
    emit(OtaBlocDownloading(progress: 0.0, info: event.firmwareInfo));

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
        // Use case stream completed — device is rebooting.
        // Wait for reconnect + version verification via OtaRebootCompleted event.
        emit(OtaBlocRebooting(info: info));
        _rebootTimer?.cancel();
        _rebootTimer = Timer(_rebootTimeout, () {
          if (!isClosed) {
            add(const OtaRebootTimedOut());
          }
        });
      case domain.OtaError():
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
