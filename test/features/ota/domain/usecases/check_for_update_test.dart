import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:traxelos/core/error/failures.dart';
import 'package:traxelos/features/ota/domain/entities/firmware_info.dart';
import 'package:traxelos/features/ota/domain/usecases/check_for_update.dart';

import '../../helpers/test_fixtures.dart';
import '../../helpers/test_helper.dart';

void main() {
  late CheckForUpdateUseCase useCase;
  late MockOtaRepository mockRepository;

  setUp(() {
    mockRepository = MockOtaRepository();
    useCase = CheckForUpdateUseCase(mockRepository);

    // Stub PackageInfo for all tests (app version 2.0.0)
    PackageInfo.setMockInitialValues(
      appName: 'Traxelos',
      packageName: 'com.example.traxelos',
      version: '2.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  group('compareSemver', () {
    test('1.0.0 < 2.0.0 (major version bump)', () {
      expect(CheckForUpdateUseCase.compareSemver('1.0.0', '2.0.0'), isNegative);
    });

    test('1.9.0 < 1.10.0 (numeric, not string comparison)', () {
      expect(
        CheckForUpdateUseCase.compareSemver('1.9.0', '1.10.0'),
        isNegative,
      );
    });

    test('2.0.0 > 1.99.99 (major always wins)', () {
      expect(
        CheckForUpdateUseCase.compareSemver('2.0.0', '1.99.99'),
        isPositive,
      );
    });

    test('1.0.0 == 1.0.0 (equal versions)', () {
      expect(CheckForUpdateUseCase.compareSemver('1.0.0', '1.0.0'), isZero);
    });

    test('0.0.1 < 0.0.2 (patch version)', () {
      expect(
        CheckForUpdateUseCase.compareSemver('0.0.1', '0.0.2'),
        isNegative,
      );
    });
  });

  group('CheckForUpdateUseCase', () {
    test('returns UpdateAvailable(isRequired: false) when newer version exists and device >= min',
        () async {
      when(() => mockRepository.fetchLatestFirmwareInfo())
          .thenAnswer((_) async => Right(testFirmwareInfo));
      when(() => mockRepository.fetchMinFirmwareVersion())
          .thenAnswer((_) async => const Right('1.0.0'));

      final result = await useCase(
        const CheckForUpdateParams(deviceFirmwareVersion: '1.5.0'),
      );

      final checkResult = result.fold((_) => null, (r) => r);
      expect(checkResult, isA<UpdateAvailable>());
      expect((checkResult as UpdateAvailable).isRequired, isFalse);
      expect(checkResult.firmwareInfo, equals(testFirmwareInfo));
    });

    test('returns UpdateAvailable(isRequired: true) when device below min_firmware_version',
        () async {
      when(() => mockRepository.fetchLatestFirmwareInfo())
          .thenAnswer((_) async => Right(testFirmwareInfo));
      when(() => mockRepository.fetchMinFirmwareVersion())
          .thenAnswer((_) async => const Right('2.0.0'));

      final result = await useCase(
        const CheckForUpdateParams(deviceFirmwareVersion: '1.5.0'),
      );

      final checkResult = result.fold((_) => null, (r) => r);
      expect(checkResult, isA<UpdateAvailable>());
      expect((checkResult as UpdateAvailable).isRequired, isTrue);
    });

    test('returns UpToDate when device firmware >= latest version', () async {
      when(() => mockRepository.fetchLatestFirmwareInfo())
          .thenAnswer((_) async => Right(testFirmwareInfo));

      final result = await useCase(
        const CheckForUpdateParams(deviceFirmwareVersion: '2.1.0'),
      );

      final checkResult = result.fold((_) => null, (r) => r);
      expect(checkResult, isA<UpToDate>());
    });

    test('returns AppUpdateRequired when app version below min_app_version',
        () async {
      // Set app version to something old
      PackageInfo.setMockInitialValues(
        appName: 'Traxelos',
        packageName: 'com.example.traxelos',
        version: '0.5.0',
        buildNumber: '1',
        buildSignature: '',
      );

      final firmwareRequiringNewerApp = FirmwareInfo(
        version: '2.1.0',
        filePath: 'firmware/bins/v2.1.0.bin',
        sha256: 'abc123',
        minAppVersion: '1.0.0',
        changelog: 'Update',
        releasedAt: testReleasedAt,
      );

      when(() => mockRepository.fetchLatestFirmwareInfo())
          .thenAnswer((_) async => Right(firmwareRequiringNewerApp));

      final result = await useCase(
        const CheckForUpdateParams(deviceFirmwareVersion: '1.0.0'),
      );

      final checkResult = result.fold((_) => null, (r) => r);
      expect(checkResult, isA<AppUpdateRequired>());
      expect((checkResult as AppUpdateRequired).minAppVersion, '1.0.0');
    });

    test('falls back to hardcoded min version when Remote Config fails',
        () async {
      when(() => mockRepository.fetchLatestFirmwareInfo())
          .thenAnswer((_) async => Right(testFirmwareInfo));
      when(() => mockRepository.fetchMinFirmwareVersion())
          .thenAnswer((_) async => const Left(ServerFailure('Network error')));

      // Device at 0.9.0 should be < fallback '1.0.0' → isRequired: true
      final result = await useCase(
        const CheckForUpdateParams(deviceFirmwareVersion: '0.9.0'),
      );

      final checkResult = result.fold((_) => null, (r) => r);
      expect(checkResult, isA<UpdateAvailable>());
      expect((checkResult as UpdateAvailable).isRequired, isTrue);
    });

    test('returns CheckFailed when Firebase Storage errors', () async {
      when(() => mockRepository.fetchLatestFirmwareInfo()).thenAnswer(
        (_) async => const Left(ServerFailure('Storage unavailable')),
      );

      final result = await useCase(
        const CheckForUpdateParams(deviceFirmwareVersion: '1.0.0'),
      );

      final checkResult = result.fold((_) => null, (r) => r);
      expect(checkResult, isA<CheckFailed>());
      expect(
        (checkResult as CheckFailed).reason,
        'Storage unavailable',
      );
    });
  });
}
