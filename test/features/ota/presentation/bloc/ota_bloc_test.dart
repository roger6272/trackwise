import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:traxelos/features/ota/domain/entities/firmware_info.dart';
import 'package:traxelos/features/ota/domain/entities/ota_state.dart' as domain;
import 'package:traxelos/features/ota/domain/usecases/check_for_update.dart';
import 'package:traxelos/features/ota/presentation/bloc/ota_bloc.dart';
import 'package:traxelos/features/ota/presentation/bloc/ota_event.dart';
import 'package:traxelos/features/ota/presentation/bloc/ota_state.dart';

import '../../helpers/test_fixtures.dart';
import '../../helpers/test_helper.dart';

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
  });

  OtaBloc buildBloc() => OtaBloc(
        mockCheckForUpdate,
        mockPerformOtaUpdate,
        mockAnalytics,
        mockConnectivity,
      );

  test('initial state is OtaInitial', () {
    final bloc = buildBloc();
    expect(bloc.state, const OtaInitial());
    bloc.close();
  });

  group('CheckForUpdateRequested', () {
    blocTest<OtaBloc, OtaBlocState>(
      'emits OtaUpdateAvailable when optional update is available',
      build: () {
        when(() => mockCheckForUpdate(any())).thenAnswer(
          (_) async => Right(UpdateAvailable(
            isRequired: false,
            firmwareInfo: testFirmwareInfo,
          )),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(const CheckForUpdateRequested('1.5.0')),
      expect: () => [
        OtaUpdateAvailable(info: testFirmwareInfo, isRequired: false),
      ],
    );

    blocTest<OtaBloc, OtaBlocState>(
      'emits OtaUpdateAvailable(isRequired: true) when update is required',
      build: () {
        when(() => mockCheckForUpdate(any())).thenAnswer(
          (_) async => Right(UpdateAvailable(
            isRequired: true,
            firmwareInfo: testFirmwareInfo,
          )),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(const CheckForUpdateRequested('0.5.0')),
      expect: () => [
        OtaUpdateAvailable(info: testFirmwareInfo, isRequired: true),
      ],
    );

    blocTest<OtaBloc, OtaBlocState>(
      'emits OtaAppUpdateRequired when app needs updating',
      build: () {
        when(() => mockCheckForUpdate(any())).thenAnswer(
          (_) async =>
              const Right(AppUpdateRequired(minAppVersion: '3.0.0')),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(const CheckForUpdateRequested('1.0.0')),
      expect: () => [const OtaAppUpdateRequired('3.0.0')],
    );

    blocTest<OtaBloc, OtaBlocState>(
      'emits nothing when device is up to date',
      build: () {
        when(() => mockCheckForUpdate(any())).thenAnswer(
          (_) async => const Right(UpToDate()),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(const CheckForUpdateRequested('2.1.0')),
      expect: () => <OtaBlocState>[],
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
      act: (bloc) => bloc.add(const CheckForUpdateRequested('1.0.0')),
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
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(const CheckForUpdateRequested('1.0.0'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        bloc
          ..add(const OtaProgressUpdated(domain.OtaDownloading(0.5)))
          ..add(const OtaProgressUpdated(domain.OtaDownloading(1.0)))
          ..add(const OtaProgressUpdated(domain.OtaTransferring(0.5)))
          ..add(const OtaProgressUpdated(domain.OtaTransferring(1.0)))
          ..add(const OtaProgressUpdated(domain.OtaVerifying()))
          ..add(const OtaProgressUpdated(domain.OtaRebooting()));
      },
      expect: () => [
        OtaUpdateAvailable(info: testFirmwareInfo, isRequired: false),
        OtaBlocDownloading(progress: 0.5, info: testFirmwareInfo),
        OtaBlocDownloading(progress: 1.0, info: testFirmwareInfo),
        OtaBlocTransferring(progress: 0.5, info: testFirmwareInfo),
        OtaBlocTransferring(progress: 1.0, info: testFirmwareInfo),
        OtaBlocVerifying(info: testFirmwareInfo),
        OtaBlocRebooting(info: testFirmwareInfo),
      ],
    );

    blocTest<OtaBloc, OtaBlocState>(
      'OtaError from stream emits OtaBlocError',
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
        bloc.add(const CheckForUpdateRequested('1.0.0'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        bloc.add(
          const OtaProgressUpdated(domain.OtaError('Download failed: timeout')),
        );
      },
      expect: () => [
        OtaUpdateAvailable(info: testFirmwareInfo, isRequired: false),
        const OtaBlocError('Download failed: timeout'),
      ],
    );
  });

  group('CancelUpdateRequested', () {
    blocTest<OtaBloc, OtaBlocState>(
      'returns to OtaUpdateAvailable when cancelled during transfer',
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
        bloc.add(const CheckForUpdateRequested('1.0.0'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        bloc.add(const OtaProgressUpdated(domain.OtaTransferring(0.3)));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        bloc.add(const CancelUpdateRequested());
      },
      expect: () => [
        OtaUpdateAvailable(info: testFirmwareInfo, isRequired: false),
        OtaBlocTransferring(progress: 0.3, info: testFirmwareInfo),
        OtaUpdateAvailable(info: testFirmwareInfo, isRequired: false),
      ],
    );
  });

  group('DismissUpdateBanner', () {
    blocTest<OtaBloc, OtaBlocState>(
      'emits OtaDismissed when optional update banner is dismissed',
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
        bloc.add(const CheckForUpdateRequested('1.0.0'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        bloc.add(const DismissUpdateBanner());
      },
      expect: () => [
        OtaUpdateAvailable(info: testFirmwareInfo, isRequired: false),
        const OtaDismissed(),
      ],
    );
  });

  group('OtaRebootCompleted', () {
    blocTest<OtaBloc, OtaBlocState>(
      'emits OtaBlocComplete with new version',
      build: buildBloc,
      act: (bloc) => bloc.add(const OtaRebootCompleted('2.1.0')),
      expect: () => [const OtaBlocComplete('2.1.0')],
    );
  });

  group('OtaRebootTimedOut', () {
    blocTest<OtaBloc, OtaBlocState>(
      'emits OtaBlocError with timeout message',
      build: buildBloc,
      act: (bloc) => bloc.add(const OtaRebootTimedOut()),
      expect: () => [
        const OtaBlocError(
          'Device didn\'t respond after update. Try turning it off and on again.',
        ),
      ],
    );
  });

  group('StartUpdateRequested', () {
    blocTest<OtaBloc, OtaBlocState>(
      'happy path: emits downloading → transferring → verifying → rebooting → rebooting (complete)',
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
        firmwareInfo: testFirmwareInfo,
        negotiatedMtu: 512,
      )),
      wait: const Duration(milliseconds: 100),
      expect: () => [
        OtaBlocDownloading(progress: 0.0, info: testFirmwareInfo),
        OtaBlocDownloading(progress: 0.5, info: testFirmwareInfo),
        OtaBlocTransferring(progress: 0.5, info: testFirmwareInfo),
        OtaBlocVerifying(info: testFirmwareInfo),
        // OtaRebooting and OtaComplete both emit OtaBlocRebooting;
        // bloc deduplicates consecutive equal states
        OtaBlocRebooting(info: testFirmwareInfo),
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
      'emits OtaBlocError when no internet connection',
      build: () {
        when(() => mockConnectivity.hasInternetConnection())
            .thenAnswer((_) async => false);
        return buildBloc();
      },
      act: (bloc) => bloc.add(StartUpdateRequested(
        firmwareInfo: testFirmwareInfo,
        negotiatedMtu: 512,
      )),
      expect: () => [
        const OtaBlocError(
          'No internet connection. Connect to Wi-Fi or mobile data and try again.',
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
      'emits OtaBlocError when use case stream emits OtaError',
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
        firmwareInfo: testFirmwareInfo,
        negotiatedMtu: 512,
      )),
      wait: const Duration(milliseconds: 100),
      expect: () => [
        OtaBlocDownloading(progress: 0.0, info: testFirmwareInfo),
        OtaBlocDownloading(progress: 0.5, info: testFirmwareInfo),
        const OtaBlocError('Download failed: timeout'),
      ],
      verify: (_) {
        verify(() => mockAnalytics.logOtaFailed(
              reason: 'Download failed: timeout',
              fromVersion: any(named: 'fromVersion'),
              toVersion: '2.1.0',
            )).called(1);
      },
    );
  });
}
