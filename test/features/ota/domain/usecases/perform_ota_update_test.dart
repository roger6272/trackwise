import 'dart:async';
import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:traxelos/core/error/failures.dart';
import 'package:traxelos/core/utils/bluetooth_constants.dart';
import 'package:traxelos/features/ota/domain/entities/ota_state.dart';
import 'package:traxelos/features/ota/domain/usecases/perform_ota_update.dart';

import '../../helpers/test_fixtures.dart';
import '../../helpers/test_helper.dart';

void main() {
  late PerformOtaUpdateUseCase useCase;
  late MockOtaRepository mockRepository;

  setUp(() {
    mockRepository = MockOtaRepository();
    useCase = PerformOtaUpdateUseCase(mockRepository);

    // Register fallback values for mocktail
    registerFallbackValue(Uint8List(0));
  });

  group('PerformOtaUpdateUseCase', () {
    const testMtu = 100;
    final testChunkSize = testMtu - BluetoothConstants.attOverhead;

    test('emits OtaError when download fails', () async {
      when(() => mockRepository.downloadFirmwareBinary(
            any(),
            onProgress: any(named: 'onProgress'),
          )).thenAnswer(
        (_) async => const Left(ServerFailure('Network error')),
      );

      final states = await useCase
          .execute(firmwareInfo: testFirmwareInfo, negotiatedMtu: testMtu)
          .toList();

      expect(states.last, isA<OtaError>());
      expect((states.last as OtaError).message, contains('Download failed'));
    });

    test('emits OtaError when device rejects ota_start (low battery)',
        () async {
      final binaryData = Uint8List(200);
      when(() => mockRepository.downloadFirmwareBinary(
            any(),
            onProgress: any(named: 'onProgress'),
          )).thenAnswer((_) async => Right(binaryData));

      when(() => mockRepository.sendOtaStart(
            expectedSize: any(named: 'expectedSize'),
            expectedHash: any(named: 'expectedHash'),
            version: any(named: 'version'),
          )).thenAnswer((_) async => const Right(null));

      // Device responds with error instead of ota_ready
      when(() => mockRepository.listenForOtaNotifications()).thenAnswer(
        (_) => Stream.fromIterable([
          {
            'status': 'error',
            'reason': 'low_battery',
            'cmd': 'ota_start',
          }
        ]),
      );

      final states = await useCase
          .execute(firmwareInfo: testFirmwareInfo, negotiatedMtu: testMtu)
          .toList();

      expect(states.last, isA<OtaError>());
      expect(
          (states.last as OtaError).message, contains('low_battery'));
    });

    test('emits OtaError on hash_mismatch after transfer', () async {
      final binaryData = Uint8List(testChunkSize); // Single chunk
      when(() => mockRepository.downloadFirmwareBinary(
            any(),
            onProgress: any(named: 'onProgress'),
          )).thenAnswer((_) async => Right(binaryData));

      when(() => mockRepository.sendOtaStart(
            expectedSize: any(named: 'expectedSize'),
            expectedHash: any(named: 'expectedHash'),
            version: any(named: 'version'),
          )).thenAnswer((_) async => const Right(null));

      when(() => mockRepository.writeOtaChunk(any()))
          .thenAnswer((_) async => const Right(null));

      when(() => mockRepository.sendOtaEnd())
          .thenAnswer((_) async => const Right(null));

      // First call (ota_ready) succeeds, second call (ota_verified) returns hash_mismatch
      var callCount = 0;
      when(() => mockRepository.listenForOtaNotifications()).thenAnswer((_) {
        callCount++;
        if (callCount == 1) {
          return Stream.fromIterable([
            {'status': 'ota_ready'}
          ]);
        } else {
          return Stream.fromIterable([
            {
              'status': 'error',
              'reason': 'hash_mismatch',
              'cmd': 'ota_end',
            }
          ]);
        }
      });

      final states = await useCase
          .execute(firmwareInfo: testFirmwareInfo, negotiatedMtu: testMtu)
          .toList();

      expect(states.last, isA<OtaError>());
      expect((states.last as OtaError).message, contains('hash_mismatch'));
    });

    test('sends correct number of chunks for given binary size and MTU',
        () async {
      // 250 bytes with chunkSize of 97 (100 - 3) = ceil(250/97) = 3 chunks
      final binaryData = Uint8List(250);
      final expectedChunks = (250 / testChunkSize).ceil();

      when(() => mockRepository.downloadFirmwareBinary(
            any(),
            onProgress: any(named: 'onProgress'),
          )).thenAnswer((_) async => Right(binaryData));

      when(() => mockRepository.sendOtaStart(
            expectedSize: any(named: 'expectedSize'),
            expectedHash: any(named: 'expectedHash'),
            version: any(named: 'version'),
          )).thenAnswer((_) async => const Right(null));

      when(() => mockRepository.writeOtaChunk(any()))
          .thenAnswer((_) async => const Right(null));

      when(() => mockRepository.sendOtaEnd())
          .thenAnswer((_) async => const Right(null));

      when(() => mockRepository.sendReboot())
          .thenAnswer((_) async => const Right(null));

      // Both ota_ready and ota_verified succeed
      var callCount = 0;
      when(() => mockRepository.listenForOtaNotifications()).thenAnswer((_) {
        callCount++;
        if (callCount == 1) {
          return Stream.fromIterable([
            {'status': 'ota_ready'}
          ]);
        } else {
          return Stream.fromIterable([
            {'status': 'ota_verified'}
          ]);
        }
      });

      final states = await useCase
          .execute(firmwareInfo: testFirmwareInfo, negotiatedMtu: testMtu)
          .toList();

      // Verify correct number of writeOtaChunk calls
      verify(() => mockRepository.writeOtaChunk(any()))
          .called(expectedChunks);

      // Verify we get the expected number of OtaTransferring states
      final transferringStates =
          states.whereType<OtaTransferring>().toList();
      expect(transferringStates.length, expectedChunks + 1); // initial 0.0 + per-chunk

      // Verify happy path completes
      expect(states.last, isA<OtaComplete>());
    });

    test('emits OtaError when notification stream closes without response',
        () async {
      final binaryData = Uint8List(200);
      when(() => mockRepository.downloadFirmwareBinary(
            any(),
            onProgress: any(named: 'onProgress'),
          )).thenAnswer((_) async => Right(binaryData));

      when(() => mockRepository.sendOtaStart(
            expectedSize: any(named: 'expectedSize'),
            expectedHash: any(named: 'expectedHash'),
            version: any(named: 'version'),
          )).thenAnswer((_) async => const Right(null));

      // Empty stream — .first throws StateError, caught by generic catch
      when(() => mockRepository.listenForOtaNotifications()).thenAnswer(
        (_) => const Stream<Map<String, dynamic>>.empty(),
      );

      final states = await useCase
          .execute(firmwareInfo: testFirmwareInfo, negotiatedMtu: testMtu)
          .toList();

      expect(states.last, isA<OtaError>());
      expect((states.last as OtaError).message,
          contains('Error waiting for ota_ready'));
    });
  });
}
