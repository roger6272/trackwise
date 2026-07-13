import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:traxelos/features/ota/domain/entities/firmware_info.dart';
import 'package:traxelos/features/ota/domain/entities/ota_state.dart' as domain;
import 'package:traxelos/features/ota/domain/usecases/check_for_update.dart';
import 'package:traxelos/features/ota/presentation/bloc/ota_bloc.dart';
import 'package:traxelos/features/ota/presentation/bloc/ota_device_status.dart';
import 'package:traxelos/features/ota/presentation/bloc/ota_event.dart';
import 'package:traxelos/features/ota/presentation/bloc/ota_state.dart';

import '../../helpers/test_fixtures.dart';
import '../../helpers/test_helper.dart';

const _deviceId = 'device-1';

void main() {
  late MockCheckForUpdateUseCase mockCheckForUpdate;
  late MockPerformOtaUpdateUseCase mockPerformOtaUpdate;
  late MockAnalyticsService mockAnalytics;
  late MockConnectivityService mockConnectivity;

  setUpAll(() {
    registerFallbackValue(
      const CheckForUpdateParams(deviceFirmwareVersion: ''),
    );
    registerFallbackValue(testFirmwareInfo);
  });

  setUp(() {
    mockCheckForUpdate = MockCheckForUpdateUseCase();
    mockPerformOtaUpdate = MockPerformOtaUpdateUseCase();
    mockAnalytics = MockAnalyticsService();
    mockConnectivity = MockConnectivityService();

    // Stub analytics methods so they don't throw
    when(() => mockAnalytics.logOtaStarted(
          fromVersion: any(named: 'fromVersion'),
          toVersion: any(named: 'toVersion'),
        )).thenAnswer((_) async {});
    when(() => mockAnalytics.logOtaCompleted(
          fromVersion: any(named: 'fromVersion'),
          toVersion: any(named: 'toVersion'),
          durationSeconds: any(named: 'durationSeconds'),
        )).thenAnswer((_) async {});
    when(() => mockAnalytics.logOtaFailed(
          reason: any(named: 'reason'),
          fromVersion: any(named: 'fromVersion'),
          toVersion: any(named: 'toVersion'),
        )).thenAnswer((_) async {});
    when(() => mockAnalytics.logOtaCancelled(
          fromVersion: any(named: 'fromVersion'),
          toVersion: any(named: 'toVersion'),
          progressPercent: any(named: 'progressPercent'),
        )).thenAnswer((_) async {});

    // Default: connectivity is available
    when(() => mockConnectivity.hasInternetConnection())
        .thenAnswer((_) async => true);

    // Stub abort so cancel handler doesn't throw
    when(() => mockPerformOtaUpdate.abort())
        .thenAnswer((_) async {});
  });

  OtaBloc buildBloc() => OtaBloc(
        mockCheckForUpdate,
        mockPerformOtaUpdate,
        mockAnalytics,
        mockConnectivity,
      );

  test('initial state is empty OtaBlocState', () {
    final bloc = buildBloc();
    expect(bloc.state, const OtaBlocState());
    bloc.close();
  });

  group('CheckForUpdateRequested', () {
    blocTest<OtaBloc, OtaBlocState>(
      'emits device update available when optional update is available',
      build: () {
        when(() => mockCheckForUpdate(any())).thenAnswer(
          (_) async => Right(UpdateAvailable(
            isRequired: false,
            firmwareInfo: testFirmwareInfo,
          )),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(const CheckForUpdateRequested(
        '1.5.0',
        deviceInstanceId: _deviceId,
      )),
      expect: () => [
        OtaBlocState(deviceStatuses: {
          _deviceId: OtaDeviceUpdateAvailable(
            info: testFirmwareInfo,
            isRequired: false,
          ),
        }),
      ],
    );

    blocTest<OtaBloc, OtaBlocState>(
      'emits device update available (isRequired: true) when update is required',
      build: () {
        when(() => mockCheckForUpdate(any())).thenAnswer(
          (_) async => Right(UpdateAvailable(
            isRequired: true,
            firmwareInfo: testFirmwareInfo,
          )),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(const CheckForUpdateRequested(
        '0.5.0',
        deviceInstanceId: _deviceId,
      )),
      expect: () => [
        OtaBlocState(deviceStatuses: {
          _deviceId: OtaDeviceUpdateAvailable(
            info: testFirmwareInfo,
            isRequired: true,
          ),
        }),
      ],
    );

    blocTest<OtaBloc, OtaBlocState>(
      'emits device app update required when app needs updating',
      build: () {
        when(() => mockCheckForUpdate(any())).thenAnswer(
          (_) async =>
              const Right(AppUpdateRequired(minAppVersion: '3.0.0')),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(const CheckForUpdateRequested(
        '1.0.0',
        deviceInstanceId: _deviceId,
      )),
      expect: () => [
        const OtaBlocState(deviceStatuses: {
          _deviceId: OtaDeviceAppUpdateRequired('3.0.0'),
        }),
      ],
    );

    blocTest<OtaBloc, OtaBlocState>(
      'emits device up to date when firmware is current',
      build: () {
        when(() => mockCheckForUpdate(any())).thenAnswer(
          (_) async => const Right(UpToDate()),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(const CheckForUpdateRequested(
        '2.1.0',
        deviceInstanceId: _deviceId,
      )),
      expect: () => [
        const OtaBlocState(deviceStatuses: {
          _deviceId: OtaDeviceUpToDate(),
        }),
      ],
    );

    blocTest<OtaBloc, OtaBlocState>(
      'emits nothing when check fails (silent failure)',
      build: () {
        when(() => mockCheckForUpdate(any())).thenAnswer(
          (_) async =>
              const Right(CheckFailed(reason: 'Network error')),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(const CheckForUpdateRequested(
        '1.0.0',
        deviceInstanceId: _deviceId,
      )),
      expect: () => <OtaBlocState>[],
    );
  });

  group('OtaProgressUpdated', () {
    blocTest<OtaBloc, OtaBlocState>(
      'downloading → transferring → verifying → rebooting state transitions',
      build: () {
        when(() => mockCheckForUpdate(any())).thenAnswer(
          (_) async => Right(UpdateAvailable(
            isRequired: false,
            firmwareInfo: testFirmwareInfo,
          )),
        );
        when(() => mockConnectivity.hasInternetConnection())
            .thenAnswer((_) async => true);
        when(() => mockPerformOtaUpdate.execute(
              firmwareInfo: any(named: 'firmwareInfo'),
              negotiatedMtu: any(named: 'negotiatedMtu'),
            )).thenAnswer((_) => const Stream.empty());
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(const CheckForUpdateRequested(
          '1.0.0',
          deviceInstanceId: _deviceId,
        ));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        bloc.add(StartUpdateRequested(
          deviceInstanceId: _deviceId,
          firmwareInfo: testFirmwareInfo,
          negotiatedMtu: 512,
        ));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        bloc
          ..add(const OtaProgressUpdated(domain.OtaDownloading(0.5)))
          ..add(const OtaProgressUpdated(domain.OtaDownloading(1.0)))
          ..add(const OtaProgressUpdated(domain.OtaTransferring(0.5)))
          ..add(const OtaProgressUpdated(domain.OtaTransferring(1.0)))
          ..add(const OtaProgressUpdated(domain.OtaVerifying()))
          ..add(const OtaProgressUpdated(domain.OtaRebooting()));
      },
      expect: () {
        final deviceStatuses = {
          _deviceId: OtaDeviceUpdateAvailable(
            info: testFirmwareInfo,
            isRequired: false,
          ),
        };
        return [
          OtaBlocState(deviceStatuses: deviceStatuses),
          OtaBlocState(
            deviceStatuses: deviceStatuses,
            activeTransfer: OtaTransferDownloading(
              deviceInstanceId: _deviceId,
              info: testFirmwareInfo,
              progress: 0.0,
            ),
          ),
          OtaBlocState(
            deviceStatuses: deviceStatuses,
            activeTransfer: OtaTransferDownloading(
              deviceInstanceId: _deviceId,
              info: testFirmwareInfo,
              progress: 0.5,
            ),
          ),
          OtaBlocState(
            deviceStatuses: deviceStatuses,
            activeTransfer: OtaTransferDownloading(
              deviceInstanceId: _deviceId,
              info: testFirmwareInfo,
              progress: 1.0,
            ),
          ),
          OtaBlocState(
            deviceStatuses: deviceStatuses,
            activeTransfer: OtaTransferTransferring(
              deviceInstanceId: _deviceId,
              info: testFirmwareInfo,
              progress: 0.5,
            ),
          ),
          OtaBlocState(
            deviceStatuses: deviceStatuses,
            activeTransfer: OtaTransferTransferring(
              deviceInstanceId: _deviceId,
              info: testFirmwareInfo,
              progress: 1.0,
            ),
          ),
          OtaBlocState(
            deviceStatuses: deviceStatuses,
            activeTransfer: OtaTransferVerifying(
              deviceInstanceId: _deviceId,
              info: testFirmwareInfo,
            ),
          ),
          OtaBlocState(
            deviceStatuses: deviceStatuses,
            activeTransfer: OtaTransferRebooting(
              deviceInstanceId: _deviceId,
              info: testFirmwareInfo,
            ),
          ),
        ];
      },
    );

    blocTest<OtaBloc, OtaBlocState>(
      'OtaError from stream emits OtaTransferError',
      build: () {
        when(() => mockCheckForUpdate(any())).thenAnswer(
          (_) async => Right(UpdateAvailable(
            isRequired: false,
            firmwareInfo: testFirmwareInfo,
          )),
        );
        when(() => mockConnectivity.hasInternetConnection())
            .thenAnswer((_) async => true);
        when(() => mockPerformOtaUpdate.execute(
              firmwareInfo: any(named: 'firmwareInfo'),
              negotiatedMtu: any(named: 'negotiatedMtu'),
            )).thenAnswer((_) => const Stream.empty());
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(const CheckForUpdateRequested(
          '1.0.0',
          deviceInstanceId: _deviceId,
        ));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        bloc.add(StartUpdateRequested(
          deviceInstanceId: _deviceId,
          firmwareInfo: testFirmwareInfo,
          negotiatedMtu: 512,
        ));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        bloc.add(
          const OtaProgressUpdated(
            domain.OtaError('Download failed: timeout'),
          ),
        );
      },
      expect: () {
        final deviceStatuses = {
          _deviceId: OtaDeviceUpdateAvailable(
            info: testFirmwareInfo,
            isRequired: false,
          ),
        };
        return [
          OtaBlocState(deviceStatuses: deviceStatuses),
          OtaBlocState(
            deviceStatuses: deviceStatuses,
            activeTransfer: OtaTransferDownloading(
              deviceInstanceId: _deviceId,
              info: testFirmwareInfo,
              progress: 0.0,
            ),
          ),
          OtaBlocState(
            deviceStatuses: deviceStatuses,
            activeTransfer: OtaTransferError(
              deviceInstanceId: _deviceId,
              info: testFirmwareInfo,
              message: 'Download failed: timeout',
            ),
          ),
        ];
      },
    );
  });

  group('CancelUpdateRequested', () {
    blocTest<OtaBloc, OtaBlocState>(
      'restores device to update available and clears active transfer',
      build: () {
        when(() => mockCheckForUpdate(any())).thenAnswer(
          (_) async => Right(UpdateAvailable(
            isRequired: false,
            firmwareInfo: testFirmwareInfo,
          )),
        );
        when(() => mockConnectivity.hasInternetConnection())
            .thenAnswer((_) async => true);
        when(() => mockPerformOtaUpdate.execute(
              firmwareInfo: any(named: 'firmwareInfo'),
              negotiatedMtu: any(named: 'negotiatedMtu'),
            )).thenAnswer((_) => const Stream.empty());
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(const CheckForUpdateRequested(
          '1.0.0',
          deviceInstanceId: _deviceId,
        ));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        bloc.add(StartUpdateRequested(
          deviceInstanceId: _deviceId,
          firmwareInfo: testFirmwareInfo,
          negotiatedMtu: 512,
        ));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        bloc.add(const OtaProgressUpdated(domain.OtaTransferring(0.3)));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        bloc.add(const CancelUpdateRequested());
      },
      expect: () {
        final deviceStatuses = {
          _deviceId: OtaDeviceUpdateAvailable(
            info: testFirmwareInfo,
            isRequired: false,
          ),
        };
        return [
          OtaBlocState(deviceStatuses: deviceStatuses),
          OtaBlocState(
            deviceStatuses: deviceStatuses,
            activeTransfer: OtaTransferDownloading(
              deviceInstanceId: _deviceId,
              info: testFirmwareInfo,
              progress: 0.0,
            ),
          ),
          OtaBlocState(
            deviceStatuses: deviceStatuses,
            activeTransfer: OtaTransferTransferring(
              deviceInstanceId: _deviceId,
              info: testFirmwareInfo,
              progress: 0.3,
            ),
          ),
          // After cancel: device restored to update available, transfer cleared
          OtaBlocState(deviceStatuses: deviceStatuses),
        ];
      },
    );
  });

  group('DismissUpdateBanner', () {
    blocTest<OtaBloc, OtaBlocState>(
      'emits device dismissed when optional update banner is dismissed',
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
        bloc.add(const CheckForUpdateRequested(
          '1.0.0',
          deviceInstanceId: _deviceId,
        ));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        bloc.add(const DismissUpdateBanner(deviceInstanceId: _deviceId));
      },
      expect: () => [
        OtaBlocState(deviceStatuses: {
          _deviceId: OtaDeviceUpdateAvailable(
            info: testFirmwareInfo,
            isRequired: false,
          ),
        }),
        const OtaBlocState(deviceStatuses: {
          _deviceId: OtaDeviceDismissed(),
        }),
      ],
    );
  });

  group('OtaRebootCompleted', () {
    blocTest<OtaBloc, OtaBlocState>(
      'marks device as up to date and sets transfer complete',
      build: () {
        when(() => mockCheckForUpdate(any())).thenAnswer(
          (_) async => Right(UpdateAvailable(
            isRequired: false,
            firmwareInfo: testFirmwareInfo,
          )),
        );
        when(() => mockConnectivity.hasInternetConnection())
            .thenAnswer((_) async => true);
        when(() => mockPerformOtaUpdate.execute(
              firmwareInfo: any(named: 'firmwareInfo'),
              negotiatedMtu: any(named: 'negotiatedMtu'),
            )).thenAnswer((_) => const Stream.empty());
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(const CheckForUpdateRequested(
          '1.0.0',
          deviceInstanceId: _deviceId,
        ));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        bloc.add(StartUpdateRequested(
          deviceInstanceId: _deviceId,
          firmwareInfo: testFirmwareInfo,
          negotiatedMtu: 512,
        ));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        bloc.add(const OtaProgressUpdated(domain.OtaRebooting()));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        bloc.add(const OtaRebootCompleted(
          '2.1.0',
          deviceInstanceId: _deviceId,
        ));
      },
      expect: () {
        final updateAvailableStatuses = {
          _deviceId: OtaDeviceUpdateAvailable(
            info: testFirmwareInfo,
            isRequired: false,
          ),
        };
        return [
          OtaBlocState(deviceStatuses: updateAvailableStatuses),
          OtaBlocState(
            deviceStatuses: updateAvailableStatuses,
            activeTransfer: OtaTransferDownloading(
              deviceInstanceId: _deviceId,
              info: testFirmwareInfo,
              progress: 0.0,
            ),
          ),
          OtaBlocState(
            deviceStatuses: updateAvailableStatuses,
            activeTransfer: OtaTransferRebooting(
              deviceInstanceId: _deviceId,
              info: testFirmwareInfo,
            ),
          ),
          OtaBlocState(
            deviceStatuses: const {
              _deviceId: OtaDeviceUpToDate(),
            },
            activeTransfer: OtaTransferComplete(
              deviceInstanceId: _deviceId,
              info: testFirmwareInfo,
              newVersion: '2.1.0',
            ),
          ),
        ];
      },
    );

    blocTest<OtaBloc, OtaBlocState>(
      'reports FAILURE (not complete) when the device comes back on the OLD '
      'version — the firmware was rolled back',
      // Reconnecting is not proof of success. If the new image boots and crashes
      // before it finishes starting up, the bootloader silently reverts and the
      // device returns on the previous firmware. Without this check the app marks
      // the device up to date and reports "Complete" on an update that was thrown
      // away — the only signal that it happened is the version it reports back.
      build: () {
        when(() => mockCheckForUpdate(any())).thenAnswer(
          (_) async => Right(UpdateAvailable(
            isRequired: false,
            firmwareInfo: testFirmwareInfo, // version 2.1.0
          )),
        );
        when(() => mockConnectivity.hasInternetConnection())
            .thenAnswer((_) async => true);
        when(() => mockPerformOtaUpdate.execute(
              firmwareInfo: any(named: 'firmwareInfo'),
              negotiatedMtu: any(named: 'negotiatedMtu'),
            )).thenAnswer((_) => const Stream.empty());
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(const CheckForUpdateRequested(
          '1.0.0',
          deviceInstanceId: _deviceId,
        ));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        bloc.add(StartUpdateRequested(
          deviceInstanceId: _deviceId,
          firmwareInfo: testFirmwareInfo,
          negotiatedMtu: 100,
        ));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        bloc.add(const OtaProgressUpdated(domain.OtaRebooting()));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        // Rolled back: we installed 2.1.0, but it came back on 1.0.0.
        bloc.add(const OtaRebootCompleted(
          '1.0.0',
          deviceInstanceId: _deviceId,
        ));
      },
      verify: (bloc) {
        final transfer = bloc.state.activeTransfer;
        expect(transfer, isA<OtaTransferError>(),
            reason: 'a rolled-back update must not be reported as complete');
        expect((transfer! as OtaTransferError).message,
            contains('old software'));
        expect(bloc.state.deviceStatuses[_deviceId],
            isA<OtaDeviceUpdateAvailable>(),
            reason: 'the update is still pending — it must stay on offer');
      },
    );
  });

  group('OtaRebootTimedOut', () {
    blocTest<OtaBloc, OtaBlocState>(
      'emits transfer error with timeout message',
      build: () {
        when(() => mockConnectivity.hasInternetConnection())
            .thenAnswer((_) async => true);
        when(() => mockPerformOtaUpdate.execute(
              firmwareInfo: any(named: 'firmwareInfo'),
              negotiatedMtu: any(named: 'negotiatedMtu'),
            )).thenAnswer((_) => const Stream.empty());
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(StartUpdateRequested(
          deviceInstanceId: _deviceId,
          firmwareInfo: testFirmwareInfo,
          negotiatedMtu: 512,
        ));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        bloc.add(const OtaRebootTimedOut());
      },
      expect: () => [
        OtaBlocState(
          activeTransfer: OtaTransferDownloading(
            deviceInstanceId: _deviceId,
            info: testFirmwareInfo,
            progress: 0.0,
          ),
        ),
        OtaBlocState(
          activeTransfer: OtaTransferError(
            deviceInstanceId: _deviceId,
            info: testFirmwareInfo,
            message:
                'Device didn\'t respond after update. Try turning it off and on again.',
          ),
        ),
      ],
    );
  });

  group('StartUpdateRequested', () {
    blocTest<OtaBloc, OtaBlocState>(
      'happy path: emits downloading → transferring → verifying → rebooting',
      build: () {
        when(() => mockConnectivity.hasInternetConnection())
            .thenAnswer((_) async => true);
        when(() => mockPerformOtaUpdate.execute(
              firmwareInfo: any(named: 'firmwareInfo'),
              negotiatedMtu: any(named: 'negotiatedMtu'),
            )).thenAnswer((_) => Stream.fromIterable(const [
              domain.OtaDownloading(0.5),
              domain.OtaTransferring(0.5),
              domain.OtaVerifying(),
              domain.OtaRebooting(),
              domain.OtaComplete(),
            ]));
        return buildBloc();
      },
      act: (bloc) => bloc.add(StartUpdateRequested(
        deviceInstanceId: _deviceId,
        firmwareInfo: testFirmwareInfo,
        negotiatedMtu: 512,
      )),
      wait: const Duration(milliseconds: 100),
      expect: () => [
        OtaBlocState(
          activeTransfer: OtaTransferDownloading(
            deviceInstanceId: _deviceId,
            info: testFirmwareInfo,
            progress: 0.0,
          ),
        ),
        OtaBlocState(
          activeTransfer: OtaTransferDownloading(
            deviceInstanceId: _deviceId,
            info: testFirmwareInfo,
            progress: 0.5,
          ),
        ),
        OtaBlocState(
          activeTransfer: OtaTransferTransferring(
            deviceInstanceId: _deviceId,
            info: testFirmwareInfo,
            progress: 0.5,
          ),
        ),
        OtaBlocState(
          activeTransfer: OtaTransferVerifying(
            deviceInstanceId: _deviceId,
            info: testFirmwareInfo,
          ),
        ),
        OtaBlocState(
          activeTransfer: OtaTransferRebooting(
            deviceInstanceId: _deviceId,
            info: testFirmwareInfo,
          ),
        ),
      ],
      verify: (_) {
        verify(() => mockPerformOtaUpdate.execute(
              firmwareInfo: testFirmwareInfo,
              negotiatedMtu: 512,
            )).called(1);
        verify(() => mockAnalytics.logOtaStarted(
              fromVersion: any(named: 'fromVersion'),
              toVersion: '2.1.0',
            )).called(1);
      },
    );

    blocTest<OtaBloc, OtaBlocState>(
      'emits transfer error when no internet connection',
      build: () {
        when(() => mockConnectivity.hasInternetConnection())
            .thenAnswer((_) async => false);
        return buildBloc();
      },
      act: (bloc) => bloc.add(StartUpdateRequested(
        deviceInstanceId: _deviceId,
        firmwareInfo: testFirmwareInfo,
        negotiatedMtu: 512,
      )),
      expect: () => [
        OtaBlocState(
          activeTransfer: OtaTransferError(
            deviceInstanceId: _deviceId,
            info: testFirmwareInfo,
            message:
                'No internet connection. Connect to Wi-Fi or mobile data and try again.',
          ),
        ),
      ],
      verify: (_) {
        verifyNever(() => mockPerformOtaUpdate.execute(
              firmwareInfo: any(named: 'firmwareInfo'),
              negotiatedMtu: any(named: 'negotiatedMtu'),
            ));
      },
    );

    blocTest<OtaBloc, OtaBlocState>(
      'emits transfer error when use case stream emits OtaError',
      build: () {
        when(() => mockConnectivity.hasInternetConnection())
            .thenAnswer((_) async => true);
        when(() => mockPerformOtaUpdate.execute(
              firmwareInfo: any(named: 'firmwareInfo'),
              negotiatedMtu: any(named: 'negotiatedMtu'),
            )).thenAnswer((_) => Stream.fromIterable(const [
              domain.OtaDownloading(0.5),
              domain.OtaError('Download failed: timeout'),
            ]));
        return buildBloc();
      },
      act: (bloc) => bloc.add(StartUpdateRequested(
        deviceInstanceId: _deviceId,
        firmwareInfo: testFirmwareInfo,
        negotiatedMtu: 512,
      )),
      wait: const Duration(milliseconds: 100),
      expect: () => [
        OtaBlocState(
          activeTransfer: OtaTransferDownloading(
            deviceInstanceId: _deviceId,
            info: testFirmwareInfo,
            progress: 0.0,
          ),
        ),
        OtaBlocState(
          activeTransfer: OtaTransferDownloading(
            deviceInstanceId: _deviceId,
            info: testFirmwareInfo,
            progress: 0.5,
          ),
        ),
        OtaBlocState(
          activeTransfer: OtaTransferError(
            deviceInstanceId: _deviceId,
            info: testFirmwareInfo,
            message: 'Download failed: timeout',
          ),
        ),
      ],
      verify: (_) {
        verify(() => mockAnalytics.logOtaFailed(
              reason: 'Download failed: timeout',
              fromVersion: any(named: 'fromVersion'),
              toVersion: '2.1.0',
            )).called(1);
      },
    );

    blocTest<OtaBloc, OtaBlocState>(
      'ignores second start request while transfer is in progress',
      build: () {
        when(() => mockConnectivity.hasInternetConnection())
            .thenAnswer((_) async => true);
        when(() => mockPerformOtaUpdate.execute(
              firmwareInfo: any(named: 'firmwareInfo'),
              negotiatedMtu: any(named: 'negotiatedMtu'),
            )).thenAnswer((_) => const Stream.empty());
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(StartUpdateRequested(
          deviceInstanceId: _deviceId,
          firmwareInfo: testFirmwareInfo,
          negotiatedMtu: 512,
        ));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        // Second start should be ignored
        bloc.add(StartUpdateRequested(
          deviceInstanceId: 'device-2',
          firmwareInfo: testFirmwareInfo,
          negotiatedMtu: 512,
        ));
      },
      expect: () => [
        OtaBlocState(
          activeTransfer: OtaTransferDownloading(
            deviceInstanceId: _deviceId,
            info: testFirmwareInfo,
            progress: 0.0,
          ),
        ),
      ],
    );
  });

  group('OtaDeviceDisconnected', () {
    blocTest<OtaBloc, OtaBlocState>(
      'removes device from statuses',
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
        bloc.add(const CheckForUpdateRequested(
          '1.0.0',
          deviceInstanceId: _deviceId,
        ));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        bloc.add(const OtaDeviceDisconnected(deviceInstanceId: _deviceId));
      },
      expect: () => [
        OtaBlocState(deviceStatuses: {
          _deviceId: OtaDeviceUpdateAvailable(
            info: testFirmwareInfo,
            isRequired: false,
          ),
        }),
        const OtaBlocState(),
      ],
    );
  });

  group('DismissTransferResult', () {
    blocTest<OtaBloc, OtaBlocState>(
      'clears completed transfer state',
      build: buildBloc,
      seed: () => OtaBlocState(
        activeTransfer: OtaTransferComplete(
          deviceInstanceId: _deviceId,
          info: testFirmwareInfo,
          newVersion: '2.1.0',
        ),
      ),
      act: (bloc) => bloc.add(const DismissTransferResult()),
      expect: () => [const OtaBlocState()],
    );

    blocTest<OtaBloc, OtaBlocState>(
      'clears errored transfer state',
      build: buildBloc,
      seed: () => OtaBlocState(
        activeTransfer: OtaTransferError(
          deviceInstanceId: _deviceId,
          info: testFirmwareInfo,
          message: 'Some error',
        ),
      ),
      act: (bloc) => bloc.add(const DismissTransferResult()),
      expect: () => [const OtaBlocState()],
    );

    blocTest<OtaBloc, OtaBlocState>(
      'does nothing when transfer is actively in progress',
      build: buildBloc,
      seed: () => OtaBlocState(
        activeTransfer: OtaTransferDownloading(
          deviceInstanceId: _deviceId,
          info: testFirmwareInfo,
          progress: 0.5,
        ),
      ),
      act: (bloc) => bloc.add(const DismissTransferResult()),
      expect: () => <OtaBlocState>[],
    );
  });

  group('OtaDeviceDisconnected during transfer', () {
    blocTest<OtaBloc, OtaBlocState>(
      'cancels active transfer with error when device disconnects',
      build: () {
        when(() => mockConnectivity.hasInternetConnection())
            .thenAnswer((_) async => true);
        when(() => mockPerformOtaUpdate.execute(
              firmwareInfo: any(named: 'firmwareInfo'),
              negotiatedMtu: any(named: 'negotiatedMtu'),
            )).thenAnswer((_) => const Stream.empty());
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(StartUpdateRequested(
          deviceInstanceId: _deviceId,
          firmwareInfo: testFirmwareInfo,
          negotiatedMtu: 512,
        ));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        bloc.add(const OtaDeviceDisconnected(deviceInstanceId: _deviceId));
      },
      expect: () => [
        OtaBlocState(
          activeTransfer: OtaTransferDownloading(
            deviceInstanceId: _deviceId,
            info: testFirmwareInfo,
            progress: 0.0,
          ),
        ),
        OtaBlocState(
          activeTransfer: OtaTransferError(
            deviceInstanceId: _deviceId,
            info: testFirmwareInfo,
            message: 'Device disconnected during update.',
          ),
        ),
      ],
    );

    blocTest<OtaBloc, OtaBlocState>(
      'does NOT cancel transfer when device disconnects during reboot (expected)',
      build: buildBloc,
      seed: () => OtaBlocState(
        deviceStatuses: {
          _deviceId: OtaDeviceUpdateAvailable(
            info: testFirmwareInfo,
            isRequired: false,
          ),
        },
        activeTransfer: OtaTransferRebooting(
          deviceInstanceId: _deviceId,
          info: testFirmwareInfo,
        ),
      ),
      act: (bloc) =>
          bloc.add(const OtaDeviceDisconnected(deviceInstanceId: _deviceId)),
      expect: () => [
        // Device removed from statuses, but transfer stays (reboot expected)
        OtaBlocState(
          activeTransfer: OtaTransferRebooting(
            deviceInstanceId: _deviceId,
            info: testFirmwareInfo,
          ),
        ),
      ],
    );
  });

  group('Multi-device tracking', () {
    blocTest<OtaBloc, OtaBlocState>(
      'tracks two devices independently',
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
        bloc.add(const CheckForUpdateRequested(
          '1.0.0',
          deviceInstanceId: 'device-1',
        ));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        bloc.add(const CheckForUpdateRequested(
          '1.0.0',
          deviceInstanceId: 'device-2',
        ));
      },
      expect: () {
        final status = OtaDeviceUpdateAvailable(
          info: testFirmwareInfo,
          isRequired: false,
        );
        return [
          OtaBlocState(deviceStatuses: {'device-1': status}),
          OtaBlocState(deviceStatuses: {
            'device-1': status,
            'device-2': status,
          }),
        ];
      },
    );
  });
}
