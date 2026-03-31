# Multi-Device OTA Awareness Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make the OTA system aware of all connected devices' firmware versions, showing per-device update banners while keeping transfers sequential (one at a time).

**Architecture:** The singleton `OtaBloc` gains a `Map<String, OtaDeviceStatus>` to track each connected device's update status independently. The `UpdateBanner` becomes a list of per-device banners. Transfer remains single-threaded — starting an update on one device locks the others. Events gain a `deviceInstanceId` field to route checks/updates to the right device.

**Tech Stack:** Flutter BLoC, Equatable, mocktail (tests)

---

### Task 1: Add `OtaDeviceStatus` model and update `OtaBloc` state

**Files:**
- Create: `lib/features/ota/presentation/bloc/ota_device_status.dart`
- Modify: `lib/features/ota/presentation/bloc/ota_state.dart`
- Modify: `lib/features/ota/presentation/bloc/ota_event.dart`
- Modify: `lib/features/ota/presentation/bloc/ota_bloc.dart`
- Modify: `test/features/ota/presentation/bloc/ota_bloc_test.dart`

This is the core data model change. Currently the bloc has a single flat state (`OtaUpdateAvailable`, `OtaBlocTransferring`, etc.). We need to split this into:
- **Per-device awareness**: which devices need updates (keyed by `deviceInstanceId`)
- **Active transfer state**: which device (if any) is currently being updated, and its progress

#### Step 1: Create `OtaDeviceStatus`

Create `lib/features/ota/presentation/bloc/ota_device_status.dart`:

```dart
import 'package:equatable/equatable.dart';

import '../../domain/entities/firmware_info.dart';

/// Per-device OTA status — tracks whether a specific device needs a firmware update.
///
/// This is separate from the transfer state: a device can be "update available"
/// while another device is actively being updated.
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

  const OtaDeviceUpdateAvailable({required this.info, required this.isRequired});

  @override
  List<Object?> get props => [info, isRequired];
}

/// This device's app version is too old to install the firmware.
class OtaDeviceAppUpdateRequired extends OtaDeviceStatus {
  final String minAppVersion;

  const OtaDeviceAppUpdateRequired(this.minAppVersion);

  @override
  List<Object?> get props => [minAppVersion];
}

/// User dismissed the update banner for this device.
class OtaDeviceDismissed extends OtaDeviceStatus {
  const OtaDeviceDismissed();
}
```

#### Step 2: Add `deviceInstanceId` to OTA events

Modify `lib/features/ota/presentation/bloc/ota_event.dart`:

- Add `deviceInstanceId` to `CheckForUpdateRequested`
- Add `deviceInstanceId` to `StartUpdateRequested`
- Add `deviceInstanceId` to `DismissUpdateBanner`
- Add `deviceInstanceId` to `OtaRebootCompleted`
- Add new event `OtaDeviceDisconnected` (to clean up device tracking)
- Add new event `DismissTransferResult` (to clear completed/errored transfer state)

```dart
class CheckForUpdateRequested extends OtaEvent {
  final String deviceInstanceId;
  final String deviceFirmwareVersion;

  const CheckForUpdateRequested(this.deviceFirmwareVersion, {required this.deviceInstanceId});

  @override
  List<Object?> get props => [deviceInstanceId, deviceFirmwareVersion];
}

class StartUpdateRequested extends OtaEvent {
  final String deviceInstanceId;
  final FirmwareInfo firmwareInfo;
  final int negotiatedMtu;

  const StartUpdateRequested({
    required this.deviceInstanceId,
    required this.firmwareInfo,
    required this.negotiatedMtu,
  });

  @override
  List<Object?> get props => [deviceInstanceId, firmwareInfo, negotiatedMtu];
}

class DismissUpdateBanner extends OtaEvent {
  final String deviceInstanceId;

  const DismissUpdateBanner({required this.deviceInstanceId});

  @override
  List<Object?> get props => [deviceInstanceId];
}

class OtaRebootCompleted extends OtaEvent {
  final String deviceInstanceId;
  final String newVersion;

  const OtaRebootCompleted(this.newVersion, {required this.deviceInstanceId});

  @override
  List<Object?> get props => [deviceInstanceId, newVersion];
}

/// Clean up device tracking when a device disconnects.
class OtaDeviceDisconnected extends OtaEvent {
  final String deviceInstanceId;

  const OtaDeviceDisconnected({required this.deviceInstanceId});

  @override
  List<Object?> get props => [deviceInstanceId];
}

/// Clear the completed/errored transfer result so new transfers can start.
class DismissTransferResult extends OtaEvent {
  const DismissTransferResult();
}
```

Keep `CancelUpdateRequested`, `OtaProgressUpdated`, and `OtaRebootTimedOut` as-is (they operate on the single active transfer).

#### Step 3: Redesign `OtaBlocState`

Modify `lib/features/ota/presentation/bloc/ota_state.dart` to a single state class with two dimensions:

```dart
import 'package:equatable/equatable.dart';

import '../../domain/entities/firmware_info.dart';
import 'ota_device_status.dart';

/// OTA bloc state — tracks per-device update awareness + active transfer.
///
/// Two independent dimensions:
/// - [deviceStatuses]: which devices need updates (keyed by deviceInstanceId)
/// - [activeTransfer]: progress of the single active firmware transfer (if any)
class OtaBlocState extends Equatable {
  /// Per-device OTA awareness. Key = deviceInstanceId.
  final Map<String, OtaDeviceStatus> deviceStatuses;

  /// Active transfer state, or null if no transfer is in progress.
  final OtaTransferState? activeTransfer;

  const OtaBlocState({
    this.deviceStatuses = const {},
    this.activeTransfer = null,
  });

  /// Whether any device has an available update (not dismissed).
  bool get hasAvailableUpdates => deviceStatuses.values.any(
        (s) => s is OtaDeviceUpdateAvailable,
      );

  /// Number of devices with available updates (not dismissed).
  int get availableUpdateCount => deviceStatuses.values
      .where((s) => s is OtaDeviceUpdateAvailable)
      .length;

  /// Whether a transfer is actively in progress (downloading, transferring,
  /// verifying, or rebooting). Complete and error states are NOT "in progress"
  /// — they are terminal results that can be dismissed.
  bool get isTransferActive {
    final t = activeTransfer;
    return t != null && t is! OtaTransferComplete && t is! OtaTransferError;
  }

  /// The deviceInstanceId currently being updated, or null.
  String? get activeDeviceId => activeTransfer?.deviceInstanceId;

  OtaBlocState copyWith({
    Map<String, OtaDeviceStatus>? deviceStatuses,
    OtaTransferState? activeTransfer,
    bool clearActiveTransfer = false,
  }) {
    return OtaBlocState(
      deviceStatuses: deviceStatuses ?? this.deviceStatuses,
      activeTransfer: clearActiveTransfer ? null : (activeTransfer ?? this.activeTransfer),
    );
  }

  @override
  List<Object?> get props => [deviceStatuses, activeTransfer];
}

/// State of a single active OTA firmware transfer.
sealed class OtaTransferState extends Equatable {
  final String deviceInstanceId;
  final FirmwareInfo info;

  const OtaTransferState({required this.deviceInstanceId, required this.info});

  @override
  List<Object?> get props => [deviceInstanceId, info];
}

class OtaTransferDownloading extends OtaTransferState {
  final double progress;

  const OtaTransferDownloading({
    required super.deviceInstanceId,
    required super.info,
    required this.progress,
  });

  @override
  List<Object?> get props => [deviceInstanceId, info, progress];
}

class OtaTransferTransferring extends OtaTransferState {
  final double progress;

  const OtaTransferTransferring({
    required super.deviceInstanceId,
    required super.info,
    required this.progress,
  });

  @override
  List<Object?> get props => [deviceInstanceId, info, progress];
}

class OtaTransferVerifying extends OtaTransferState {
  const OtaTransferVerifying({required super.deviceInstanceId, required super.info});
}

class OtaTransferRebooting extends OtaTransferState {
  const OtaTransferRebooting({required super.deviceInstanceId, required super.info});
}

class OtaTransferComplete extends OtaTransferState {
  final String newVersion;

  const OtaTransferComplete({
    required super.deviceInstanceId,
    required super.info,
    required this.newVersion,
  });

  @override
  List<Object?> get props => [deviceInstanceId, info, newVersion];
}

class OtaTransferError extends OtaTransferState {
  final String message;

  const OtaTransferError({
    required super.deviceInstanceId,
    required super.info,
    required this.message,
  });

  @override
  List<Object?> get props => [deviceInstanceId, info, message];
}
```

#### Step 4: Rewrite `OtaBloc` handlers

Modify `lib/features/ota/presentation/bloc/ota_bloc.dart`:

Key changes:
- `_onCheckForUpdate`: store result in `deviceStatuses[event.deviceInstanceId]`. Track `UpToDate` in the map (accurate status tracking). Don't add entry for `CheckFailed` (silent failure).
- `_onStartUpdate`: guard with `if (state.isTransferActive) return;`. Set `activeTransfer`. Use `event.deviceInstanceId`.
- `_onProgressUpdated`: get `deviceId` and `info` from `state.activeTransfer`. Guard with `if (transfer == null) return;`.
- `_onCancelUpdate`: get device info from `state.activeTransfer`. Restore device to `OtaDeviceUpdateAvailable`. Clear active transfer.
- `_onDismissBanner`: set `deviceStatuses[event.deviceInstanceId]` to `OtaDeviceDismissed`
- `_onRebootCompleted`: mark device as `OtaDeviceUpToDate`, set `activeTransfer` to `OtaTransferComplete`, use `event.deviceInstanceId`
- `_onRebootTimedOut`: get device info from `state.activeTransfer`. Guard with null check.
- New `_onDeviceDisconnected`: remove device from `deviceStatuses`. If that device has the active transfer, cancel it (cancel subscription, clear timers, clear wakelock, clear activeTransfer).
- New `_onDismissTransferResult`: clear `activeTransfer` if it's `OtaTransferComplete` or `OtaTransferError`.
- `_deviceFirmwareVersion` becomes `final Map<String, String> _deviceFirmwareVersions = {}`
- Remove the `isTransferInProgress` getter (use `state.isTransferActive` instead)
- Remove redundant `_currentFirmwareInfo` field — use `state.activeTransfer?.info` instead

```dart
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
    AppLogger.debug('OTA: Checking for update (device $deviceId: v${event.deviceFirmwareVersion})');
    _deviceFirmwareVersions[deviceId] = event.deviceFirmwareVersion;

    final result = await _checkForUpdate.call(
      CheckForUpdateParams(deviceFirmwareVersion: event.deviceFirmwareVersion),
    );

    result.fold(
      (failure) {
        AppLogger.error('OTA: Update check failed for $deviceId: ${failure.message}');
      },
      (checkResult) {
        final updatedStatuses = Map<String, OtaDeviceStatus>.from(state.deviceStatuses);
        switch (checkResult) {
          case UpdateAvailable():
            updatedStatuses[deviceId] = OtaDeviceUpdateAvailable(
              info: checkResult.firmwareInfo,
              isRequired: checkResult.isRequired,
            );
            emit(state.copyWith(deviceStatuses: updatedStatuses));
          case AppUpdateRequired():
            updatedStatuses[deviceId] = OtaDeviceAppUpdateRequired(checkResult.minAppVersion);
            emit(state.copyWith(deviceStatuses: updatedStatuses));
          case UpToDate():
            AppLogger.debug('OTA: Device $deviceId is up to date');
            updatedStatuses[deviceId] = const OtaDeviceUpToDate();
          case CheckFailed():
            AppLogger.debug('OTA: Check failed for $deviceId: ${checkResult.reason}');
            // Don't add to map — silent failure, same as current behavior
        }
        emit(state.copyWith(deviceStatuses: updatedStatuses));
      },
    );
  }

  Future<void> _onStartUpdate(
    StartUpdateRequested event,
    Emitter<OtaBlocState> emit,
  ) async {
    if (state.isTransferActive) {
      AppLogger.debug('OTA: Transfer already in progress, ignoring start request');
      return;
    }

    final hasInternet = await _connectivity.hasInternetConnection();
    if (!hasInternet) {
      emit(state.copyWith(
        activeTransfer: OtaTransferError(
          deviceInstanceId: event.deviceInstanceId,
          info: event.firmwareInfo,
          message: 'No internet connection. Connect to Wi-Fi or mobile data and try again.',
        ),
      ));
      return;
    }

    _otaStartTime = DateTime.now();
    _setWakelock(true);

    emit(state.copyWith(
      activeTransfer: OtaTransferDownloading(
        deviceInstanceId: event.deviceInstanceId,
        info: event.firmwareInfo,
        progress: 0.0,
      ),
    ));

    final fromVersion = _deviceFirmwareVersions[event.deviceInstanceId] ?? 'unknown';
    _analytics.logOtaStarted(
      fromVersion: fromVersion,
      toVersion: event.firmwareInfo.version,
    );

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

    double progressPercent = 0.0;
    if (transfer is OtaTransferDownloading) {
      progressPercent = transfer.progress * 100;
    } else if (transfer is OtaTransferTransferring) {
      progressPercent = transfer.progress * 100;
    }

    _analytics.logOtaCancelled(
      fromVersion: _deviceFirmwareVersions[transfer.deviceInstanceId] ?? 'unknown',
      toVersion: transfer.info.version,
      progressPercent: progressPercent,
    );

    _otaSubscription?.cancel();
    _otaSubscription = null;
    _rebootTimer?.cancel();
    _rebootTimer = null;
    _setWakelock(false);

    // Restore device status to update-available
    final updatedStatuses = Map<String, OtaDeviceStatus>.from(state.deviceStatuses);
    updatedStatuses[transfer.deviceInstanceId] = OtaDeviceUpdateAvailable(
      info: transfer.info,
      isRequired: false,
    );

    emit(state.copyWith(
      deviceStatuses: updatedStatuses,
      clearActiveTransfer: true,
    ));
  }

  void _onDismissBanner(
    DismissUpdateBanner event,
    Emitter<OtaBlocState> emit,
  ) {
    final updatedStatuses = Map<String, OtaDeviceStatus>.from(state.deviceStatuses);
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
            deviceInstanceId: deviceId, info: info, progress: progress.progress,
          ),
        ));
      case domain.OtaTransferring():
        emit(state.copyWith(
          activeTransfer: OtaTransferTransferring(
            deviceInstanceId: deviceId, info: info, progress: progress.progress,
          ),
        ));
      case domain.OtaVerifying():
        emit(state.copyWith(
          activeTransfer: OtaTransferVerifying(deviceInstanceId: deviceId, info: info),
        ));
      case domain.OtaRebooting():
        emit(state.copyWith(
          activeTransfer: OtaTransferRebooting(deviceInstanceId: deviceId, info: info),
        ));
        _rebootTimer?.cancel();
        _rebootTimer = Timer(_rebootTimeout, () {
          if (!isClosed) add(const OtaRebootTimedOut());
        });
      case domain.OtaComplete():
        break; // Wait for OtaRebootCompleted
      case domain.OtaError():
        final fromVersion = _deviceFirmwareVersions[deviceId] ?? 'unknown';
        _analytics.logOtaFailed(
          reason: progress.message,
          fromVersion: fromVersion,
          toVersion: info.version,
        );
        _setWakelock(false);
        emit(state.copyWith(
          activeTransfer: OtaTransferError(
            deviceInstanceId: deviceId, info: info, message: progress.message,
          ),
        ));
        _otaSubscription?.cancel();
        _otaSubscription = null;
      default:
        break;
    }
  }

  void _onRebootCompleted(
    OtaRebootCompleted event,
    Emitter<OtaBlocState> emit,
  ) {
    AppLogger.debug('OTA: Reboot completed for ${event.deviceInstanceId}, new version: ${event.newVersion}');
    _rebootTimer?.cancel();
    _rebootTimer = null;
    _otaSubscription?.cancel();
    _otaSubscription = null;

    final deviceId = event.deviceInstanceId;
    final fromVersion = _deviceFirmwareVersions[deviceId] ?? 'unknown';
    final durationSeconds = _otaStartTime != null
        ? DateTime.now().difference(_otaStartTime!).inSeconds
        : 0;
    _analytics.logOtaCompleted(
      fromVersion: fromVersion,
      toVersion: event.newVersion,
      durationSeconds: durationSeconds,
    );

    _setWakelock(false);

    // Mark device as up-to-date
    final updatedStatuses = Map<String, OtaDeviceStatus>.from(state.deviceStatuses);
    updatedStatuses[deviceId] = const OtaDeviceUpToDate();
    _deviceFirmwareVersions[deviceId] = event.newVersion;

    final transfer = state.activeTransfer;
    emit(state.copyWith(
      deviceStatuses: updatedStatuses,
      activeTransfer: transfer != null
          ? OtaTransferComplete(
              deviceInstanceId: deviceId,
              info: transfer.info,
              newVersion: event.newVersion,
            )
          : null,
    ));
  }

  void _onRebootTimedOut(
    OtaRebootTimedOut event,
    Emitter<OtaBlocState> emit,
  ) {
    final transfer = state.activeTransfer;
    if (transfer == null) return;

    AppLogger.debug('OTA: Reboot timed out — device did not reconnect');
    _rebootTimer?.cancel();
    _rebootTimer = null;
    _otaSubscription?.cancel();
    _otaSubscription = null;
    _setWakelock(false);

    _analytics.logOtaFailed(
      reason: 'Reboot timed out — device did not reconnect',
      fromVersion: _deviceFirmwareVersions[transfer.deviceInstanceId] ?? 'unknown',
      toVersion: transfer.info.version,
    );

    emit(state.copyWith(
      activeTransfer: OtaTransferError(
        deviceInstanceId: transfer.deviceInstanceId,
        info: transfer.info,
        message: 'Device didn\'t respond after update. Try turning it off and on again.',
      ),
    ));
  }

  void _onDeviceDisconnected(
    OtaDeviceDisconnected event,
    Emitter<OtaBlocState> emit,
  ) {
    final updatedStatuses = Map<String, OtaDeviceStatus>.from(state.deviceStatuses);
    updatedStatuses.remove(event.deviceInstanceId);
    _deviceFirmwareVersions.remove(event.deviceInstanceId);

    // If the disconnected device has the active transfer, cancel it —
    // UNLESS it's in the rebooting state, where disconnect is expected behavior.
    final transfer = state.activeTransfer;
    if (state.activeDeviceId == event.deviceInstanceId &&
        state.isTransferActive &&
        transfer is! OtaTransferRebooting) {
      _otaSubscription?.cancel();
      _otaSubscription = null;
      _rebootTimer?.cancel();
      _rebootTimer = null;
      _setWakelock(false);

      emit(state.copyWith(
        deviceStatuses: updatedStatuses,
        activeTransfer: OtaTransferError(
          deviceInstanceId: event.deviceInstanceId,
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
      if (enabled) {
        WakelockPlus.enable();
      } else {
        WakelockPlus.disable();
      }
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
```

#### Step 5: Update all existing OTA bloc tests

Modify `test/features/ota/presentation/bloc/ota_bloc_test.dart`:

All tests need updating because:
- Initial state changes from `OtaInitial()` to `OtaBlocState()`
- Events now require `deviceInstanceId`
- Expected states change to the new composite structure

Example — update the first test:

```dart
test('initial state is empty OtaBlocState', () {
  final bloc = buildBloc();
  expect(bloc.state, const OtaBlocState());
  bloc.close();
});
```

Example — update `CheckForUpdateRequested` test:

```dart
blocTest<OtaBloc, OtaBlocState>(
  'emits device status update when optional update is available',
  build: () {
    when(() => mockCheckForUpdate(any())).thenAnswer(
      (_) async => Right(UpdateAvailable(
        isRequired: false,
        firmwareInfo: testFirmwareInfo,
      )),
    );
    return buildBloc();
  },
  act: (bloc) => bloc.add(const CheckForUpdateRequested('1.5.0', deviceInstanceId: 'device-1')),
  expect: () => [
    OtaBlocState(deviceStatuses: {
      'device-1': OtaDeviceUpdateAvailable(info: testFirmwareInfo, isRequired: false),
    }),
  ],
);
```

Add a new multi-device awareness test:

```dart
blocTest<OtaBloc, OtaBlocState>(
  'tracks update status for multiple devices independently',
  build: () {
    when(() => mockCheckForUpdate(any())).thenAnswer(
      (_) async => Right(UpdateAvailable(
        isRequired: false,
        firmwareInfo: testFirmwareInfo,
      )),
    );
    return buildBloc();
  },
  act: (bloc) async {
    bloc.add(const CheckForUpdateRequested('1.5.0', deviceInstanceId: 'device-1'));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    bloc.add(const CheckForUpdateRequested('1.5.0', deviceInstanceId: 'device-2'));
  },
  expect: () => [
    OtaBlocState(deviceStatuses: {
      'device-1': OtaDeviceUpdateAvailable(info: testFirmwareInfo, isRequired: false),
    }),
    OtaBlocState(deviceStatuses: {
      'device-1': OtaDeviceUpdateAvailable(info: testFirmwareInfo, isRequired: false),
      'device-2': OtaDeviceUpdateAvailable(info: testFirmwareInfo, isRequired: false),
    }),
  ],
);
```

Add a test that starting a transfer while one is active is ignored:

```dart
blocTest<OtaBloc, OtaBlocState>(
  'ignores second StartUpdateRequested while transfer is active',
  build: () {
    when(() => mockConnectivity.hasInternetConnection()).thenAnswer((_) async => true);
    when(() => mockPerformOtaUpdate.execute(
          firmwareInfo: any(named: 'firmwareInfo'),
          negotiatedMtu: any(named: 'negotiatedMtu'),
        )).thenAnswer((_) => const Stream.empty());
    return buildBloc();
  },
  act: (bloc) async {
    bloc.add(StartUpdateRequested(
      deviceInstanceId: 'device-1',
      firmwareInfo: testFirmwareInfo,
      negotiatedMtu: 512,
    ));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    bloc.add(StartUpdateRequested(
      deviceInstanceId: 'device-2',
      firmwareInfo: testFirmwareInfo,
      negotiatedMtu: 512,
    ));
  },
  expect: () => [
    // Only device-1 starts
    OtaBlocState(activeTransfer: OtaTransferDownloading(
      deviceInstanceId: 'device-1', info: testFirmwareInfo, progress: 0.0,
    )),
  ],
);
```

Add a test for `DismissTransferResult`:

```dart
blocTest<OtaBloc, OtaBlocState>(
  'DismissTransferResult clears completed transfer, allowing new transfers',
  build: buildBloc,
  seed: () => OtaBlocState(
    activeTransfer: OtaTransferComplete(
      deviceInstanceId: 'device-1',
      info: testFirmwareInfo,
      newVersion: '2.1.0',
    ),
  ),
  act: (bloc) => bloc.add(const DismissTransferResult()),
  expect: () => [const OtaBlocState()],
);
```

Add a test for device disconnect during active transfer:

```dart
blocTest<OtaBloc, OtaBlocState>(
  'device disconnect during active transfer cancels it with error',
  build: () {
    when(() => mockConnectivity.hasInternetConnection()).thenAnswer((_) async => true);
    when(() => mockPerformOtaUpdate.execute(
          firmwareInfo: any(named: 'firmwareInfo'),
          negotiatedMtu: any(named: 'negotiatedMtu'),
        )).thenAnswer((_) => const Stream.empty());
    return buildBloc();
  },
  act: (bloc) async {
    bloc.add(StartUpdateRequested(
      deviceInstanceId: 'device-1',
      firmwareInfo: testFirmwareInfo,
      negotiatedMtu: 512,
    ));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    bloc.add(const OtaDeviceDisconnected(deviceInstanceId: 'device-1'));
  },
  expect: () => [
    OtaBlocState(activeTransfer: OtaTransferDownloading(
      deviceInstanceId: 'device-1', info: testFirmwareInfo, progress: 0.0,
    )),
    OtaBlocState(activeTransfer: OtaTransferError(
      deviceInstanceId: 'device-1', info: testFirmwareInfo,
      message: 'Device disconnected during update.',
    )),
  ],
);
```

#### Step 6: Run tests to verify

Run: `flutter test test/features/ota/`

Expected: All tests pass.

#### Step 7: Commit

```bash
git add lib/features/ota/presentation/bloc/ test/features/ota/
git commit -m "refactor: multi-device OTA awareness in OtaBloc

Track per-device firmware update status via Map<deviceId, OtaDeviceStatus>
while keeping transfers sequential (one at a time). Events now carry
deviceInstanceId for routing."
```

---

### Task 2: Update `UpdateBanner` widget for per-device banners

**Files:**
- Modify: `lib/features/ota/presentation/widgets/update_banner.dart`
- Modify: `lib/features/bluetooth/presentation/pages/bluetooth_page.dart`

Now the banner needs to render per-device status from the new state shape.

#### Step 1: Rewrite `UpdateBanner` to iterate device statuses

The `UpdateBanner` should now accept `connectedDevices` (so it can look up MTUs) and `pairedDevices` (to look up device names), then render one banner per device that has an available update, plus show active transfer state.

```dart
class UpdateBanner extends StatelessWidget {
  /// Connected devices map — used to get MTU values.
  final Map<String, DeviceConnectionState> connectedDevices;
  /// Paired devices list — used to get device names.
  final List<PairedDevice> pairedDevices;

  const UpdateBanner({
    super.key,
    required this.connectedDevices,
    required this.pairedDevices,
  });

  String _deviceName(String deviceInstanceId) {
    final paired = pairedDevices.where((d) => d.deviceInstanceId == deviceInstanceId).firstOrNull;
    return paired?.deviceName ?? 'Device';
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OtaBloc, OtaBlocState>(
      builder: (context, state) {
        final widgets = <Widget>[];

        // Active transfer banner (if any)
        final transfer = state.activeTransfer;
        if (transfer != null) {
          widgets.add(_buildTransferBanner(context, transfer));
        }

        // Per-device update-available banners (skip the device being updated)
        for (final entry in state.deviceStatuses.entries) {
          if (entry.key == state.activeDeviceId) continue;
          final status = entry.value;
          final name = _deviceName(entry.key);
          final deviceState = connectedDevices[entry.key];
          final mtu = deviceState?.negotiatedMtu ?? BluetoothConstants.defaultMtuLimit;

          if (status is OtaDeviceUpdateAvailable) {
            widgets.add(_UpdateAvailableBanner(
              deviceInstanceId: entry.key,
              deviceName: name,
              state: status,
              negotiatedMtu: mtu,
            ));
          } else if (status is OtaDeviceAppUpdateRequired) {
            widgets.add(_AppUpdateBanner(
              deviceName: name,
              state: status,
            ));
          }
        }

        if (widgets.isEmpty) return const SizedBox.shrink();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: widgets,
        );
      },
    );
  }

  Widget _buildTransferBanner(BuildContext context, OtaTransferState transfer) {
    final name = _deviceName(transfer.deviceInstanceId);
    return switch (transfer) {
      OtaTransferDownloading() => _TransferProgressBanner(
          label: '$name: Downloading firmware...',
          progress: transfer.progress,
        ),
      OtaTransferTransferring() => _TransferProgressBanner(
          label: '$name: Transferring to device...',
          progress: transfer.progress,
          showWarning: true,
        ),
      OtaTransferVerifying() => _TransferProgressBanner(
          label: '$name: Verifying firmware...',
          progress: null,
          showWarning: true,
        ),
      OtaTransferRebooting() => _TransferProgressBanner(
          label: '$name: Device is rebooting...',
          progress: null,
        ),
      OtaTransferComplete() => _CompleteBanner(
          deviceName: name,
          newVersion: transfer.newVersion,
        ),
      OtaTransferError() => _ErrorBanner(message: transfer.message),
    };
  }
}
```

Update `_UpdateAvailableBanner` to accept `deviceInstanceId` and `deviceName`, and include the device name in the banner text (e.g., "Traxelos One: Firmware v2.1.0 available"). When tapped, pass the `deviceInstanceId` to the progress sheet. The `DismissUpdateBanner` event needs the `deviceInstanceId`.

Update `_CompleteBanner` to show device name (e.g., "Traxelos One updated to v2.1.0").

Add `DismissTransferResult` dispatch to clear the transfer state from the banner. The `UpdateBanner` widget needs a `BlocListener` (in addition to the `BlocBuilder`) that auto-clears completed/errored transfers after a delay:

```dart
return BlocListener<OtaBloc, OtaBlocState>(
  listenWhen: (prev, curr) => prev.activeTransfer != curr.activeTransfer,
  listener: (context, state) {
    // Auto-clear complete/error banners after 5 seconds
    if (state.activeTransfer is OtaTransferComplete ||
        state.activeTransfer is OtaTransferError) {
      Future.delayed(const Duration(seconds: 5), () {
        if (context.mounted) {
          context.read<OtaBloc>().add(const DismissTransferResult());
        }
      });
    }
  },
  child: BlocBuilder<OtaBloc, OtaBlocState>(
    builder: (context, state) {
      // ... existing builder code
    },
  ),
);
```

Alternatively, `_ErrorBanner` can add a tap-to-dismiss that dispatches `DismissTransferResult()` immediately.

#### Step 2: Update `bluetooth_page.dart` — banner construction

In `_buildBanners`, change the OTA banner section:

```dart
// OTA update banner (shown when connected devices have firmware updates)
if (state.isConnected) {
  banners.add(UpdateBanner(
    connectedDevices: state.connectedDevices,
    pairedDevices: state.pairedDevices,
  ));
}
```

#### Step 3: Update `bluetooth_page.dart` — OTA check loop

Remove `break; // Check for first connected device only` — check ALL connected devices:

```dart
// Trigger OTA update check when a device's firmware version becomes available
for (final entry in state.connectedDevices.entries) {
  final deviceState = entry.value;
  if (deviceState.firmwareVersion != null &&
      deviceState.syncStatus == DeviceSyncStatus.synced &&
      !_otaCheckedDevices.contains(entry.key)) {
    _otaCheckedDevices.add(entry.key);
    final bluetoothBloc = context.read<BluetoothBloc>();
    if (bluetoothBloc.isAwaitingOtaReboot(entry.key)) {
      context.read<OtaBloc>().add(
        ota_events.OtaRebootCompleted(
          deviceState.firmwareVersion!,
          deviceInstanceId: entry.key,
        ),
      );
      bluetoothBloc.add(
        SetOtaRebootFlag(deviceInstanceId: entry.key, awaiting: false),
      );
    } else {
      context.read<OtaBloc>().add(
        ota_events.CheckForUpdateRequested(
          deviceState.firmwareVersion!,
          deviceInstanceId: entry.key,
        ),
      );
    }
    // No break — check ALL connected devices
  }
}
```

#### Step 4: Update `bluetooth_page.dart` — OtaBloc listener for reboot flag

The `BlocListener<OtaBloc, OtaBlocState>` needs updating since state shape changed. Set reboot flag only for the device being updated. Use `listenWhen` to only fire when `activeTransfer` changes:

```dart
BlocListener<OtaBloc, OtaBlocState>(
  listenWhen: (prev, curr) => prev.activeTransfer != curr.activeTransfer,
  listener: (context, otaState) {
    final transfer = otaState.activeTransfer;
    if (transfer is OtaTransferRebooting) {
      context.read<BluetoothBloc>().add(
        SetOtaRebootFlag(deviceInstanceId: transfer.deviceInstanceId, awaiting: true),
      );
    }
    // Clear reboot flag on error/cancel (transfer cleared or errored)
    if (transfer == null || transfer is OtaTransferError) {
      final bluetoothBloc = context.read<BluetoothBloc>();
      final btState = bluetoothBloc.state;
      for (final deviceId in btState.connectedDevices.keys) {
        if (bluetoothBloc.isAwaitingOtaReboot(deviceId)) {
          bluetoothBloc.add(
            SetOtaRebootFlag(deviceInstanceId: deviceId, awaiting: false),
          );
        }
      }
    }
  },
  // ...
),
```

#### Step 5: Add `OtaDeviceDisconnected` event on device disconnect

In the `_otaCheckedDevices` cleanup section, also notify OtaBloc:

```dart
// Clean up OTA check tracking for disconnected devices
final disconnected = _otaCheckedDevices.where(
    (id) => !state.connectedDevices.containsKey(id)).toList();
for (final id in disconnected) {
  _otaCheckedDevices.remove(id);
  context.read<OtaBloc>().add(ota_events.OtaDeviceDisconnected(deviceInstanceId: id));
}
```

#### Step 6: Run tests and build

Run: `flutter test && flutter build apk --debug`

Expected: All tests pass, app builds successfully.

#### Step 7: Commit

```bash
git add lib/features/ota/presentation/widgets/update_banner.dart lib/features/bluetooth/presentation/pages/bluetooth_page.dart
git commit -m "feat: per-device OTA update banners

Show individual update banners for each connected device that needs a
firmware update. Check all connected devices, not just the first."
```

---

### Task 3: Update `OtaProgressSheet` for device context

**Files:**
- Modify: `lib/features/ota/presentation/widgets/ota_progress_sheet.dart`
- Modify: `lib/features/ota/presentation/widgets/update_banner.dart` (wire up new param)

#### Step 1: Add `deviceInstanceId` and `deviceName` to `OtaProgressSheet`

The progress sheet needs to know which device it's updating, and send the `deviceInstanceId` in `StartUpdateRequested`:

```dart
class OtaProgressSheet extends StatelessWidget {
  final String deviceInstanceId;
  final String deviceName;
  final FirmwareInfo firmwareInfo;
  final int negotiatedMtu;

  const OtaProgressSheet({
    super.key,
    required this.deviceInstanceId,
    required this.deviceName,
    required this.firmwareInfo,
    required this.negotiatedMtu,
  });
```

Update the "Update Now" button:

```dart
context.read<OtaBloc>().add(StartUpdateRequested(
  deviceInstanceId: deviceInstanceId,
  firmwareInfo: firmwareInfo,
  negotiatedMtu: negotiatedMtu,
));
```

Update the title to include device name: `'Firmware Update — $deviceName'`

#### Step 2: Update `_buildContent` and `_buildActions` for new state shape

The builder/listener now uses `OtaBlocState` which has `activeTransfer`. Rewrite the switch statements to match on `OtaTransferState?`:

```dart
BlocConsumer<OtaBloc, OtaBlocState>(
  listener: (context, state) {
    // Auto-dismiss on complete after delay, then clear transfer result
    if (state.activeTransfer is OtaTransferComplete) {
      Future.delayed(const Duration(seconds: 3), () {
        if (context.mounted) {
          context.read<OtaBloc>().add(const DismissTransferResult());
          Navigator.of(context).pop();
        }
      });
    }
  },
  builder: (context, state) {
    final transfer = state.activeTransfer;
    // ... use transfer for content and actions
  },
)
```

`_buildContent(context, transfer)` where `transfer` is `OtaTransferState?`:

```dart
Widget _buildContent(BuildContext context, OtaTransferState? transfer) {
  final brightness = Theme.of(context).brightness;
  final primaryColor = AppColors.primaryAdaptive(brightness);
  final secondaryText = AppColors.secondaryText(brightness);

  if (transfer == null) {
    // Pre-update: show step list
    return _StepList(currentStep: -1, secondaryText: secondaryText, primaryColor: primaryColor);
  }

  return switch (transfer) {
    OtaTransferDownloading() => _StepList(
        currentStep: 0,
        progress: transfer.progress,
        secondaryText: secondaryText,
        primaryColor: primaryColor,
      ),
    OtaTransferTransferring() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepList(
            currentStep: 1,
            progress: transfer.progress,
            secondaryText: secondaryText,
            primaryColor: primaryColor,
          ),
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.warningText(brightness)),
            const SizedBox(width: 6),
            Expanded(child: Text(
              'Don\'t turn off your device',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.warningText(brightness), fontStyle: FontStyle.italic,
              ),
            )),
          ]),
        ],
      ),
    OtaTransferVerifying() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepList(currentStep: 2, secondaryText: secondaryText, primaryColor: primaryColor),
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.warningText(brightness)),
            const SizedBox(width: 6),
            Expanded(child: Text(
              'Don\'t turn off your device',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.warningText(brightness), fontStyle: FontStyle.italic,
              ),
            )),
          ]),
        ],
      ),
    OtaTransferRebooting() => _StepList(
        currentStep: 3, secondaryText: secondaryText, primaryColor: primaryColor,
      ),
    OtaTransferComplete() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, size: 48, color: AppColors.success),
          const SizedBox(height: 12),
          Text('Update complete!',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.success, fontWeight: FontWeight.w600,
            )),
          const SizedBox(height: 4),
          Text('Firmware updated to v${transfer.newVersion}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: secondaryText,
            )),
        ],
      ),
    OtaTransferError() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          Text('Update failed',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.error, fontWeight: FontWeight.w600,
            )),
          const SizedBox(height: 4),
          Text(transfer.message, textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: secondaryText,
            )),
        ],
      ),
  };
}
```

`_buildActions(context, transfer)` follows the same pattern:

```dart
Widget _buildActions(BuildContext context, OtaTransferState? transfer) {
  if (transfer == null) {
    // Pre-update: show Later / Update Now buttons
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Later', style: TextStyle(color: AppColors.secondaryText(Theme.of(context).brightness))),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: () {
            context.read<OtaBloc>().add(StartUpdateRequested(
              deviceInstanceId: deviceInstanceId,
              firmwareInfo: firmwareInfo,
              negotiatedMtu: negotiatedMtu,
            ));
          },
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          child: const Text('Update Now', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  return switch (transfer) {
    OtaTransferDownloading() || OtaTransferTransferring() => Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => _showCancelConfirmation(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    OtaTransferVerifying() || OtaTransferRebooting() => const SizedBox.shrink(),
    OtaTransferComplete() => Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FilledButton(
            onPressed: () {
              context.read<OtaBloc>().add(const DismissTransferResult());
              Navigator.of(context).pop();
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Done', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    OtaTransferError() => Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FilledButton(
            onPressed: () {
              context.read<OtaBloc>().add(const DismissTransferResult());
              Navigator.of(context).pop();
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Dismiss', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
  };
}
```

#### Step 3: Wire `deviceInstanceId` and `deviceName` from banner

In `update_banner.dart`, update `_showProgressSheet` in `_UpdateAvailableBanner`:

```dart
void _showProgressSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    builder: (_) => BlocProvider.value(
      value: context.read<OtaBloc>(),
      child: OtaProgressSheet(
        deviceInstanceId: deviceInstanceId,
        deviceName: deviceName,
        firmwareInfo: state.info,
        negotiatedMtu: negotiatedMtu,
      ),
    ),
  );
}
```

#### Step 4: Run tests and build

Run: `flutter test && flutter build apk --debug`

Expected: All tests pass, app builds successfully.

#### Step 5: Commit

```bash
git add lib/features/ota/presentation/widgets/
git commit -m "feat: OtaProgressSheet shows device name and routes to correct device"
```

---

### Task 4: Final verification and cleanup

**Files:**
- Verify: all OTA-related imports compile
- Verify: `flutter test` passes (~728+ tests)
- Verify: `flutter build apk --debug` succeeds

#### Step 1: Search for any remaining references to old state classes

Search for `OtaInitial`, `OtaUpdateAvailable`, `OtaAppUpdateRequired`, `OtaBlocDownloading`, `OtaBlocTransferring`, `OtaBlocVerifying`, `OtaBlocRebooting`, `OtaBlocComplete`, `OtaBlocError`, `OtaDismissed` across the codebase. Any remaining references outside of the OTA feature's own files need updating.

Common places to check:
- `bluetooth_page.dart` (already updated in Task 2)
- Any other BlocListener/BlocBuilder for OtaBloc elsewhere

#### Step 2: Run full test suite

Run: `flutter test`

Expected: All tests pass.

#### Step 3: Verify build

Run: `flutter build apk --debug`

Expected: Build succeeds.

#### Step 4: Commit any remaining fixes

```bash
git add lib/features/ota/ test/features/ota/
git commit -m "fix: resolve remaining references to old OTA state classes"
```
