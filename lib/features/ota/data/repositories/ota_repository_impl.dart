import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/firmware_info.dart';
import '../../domain/repositories/ota_repository.dart';
import '../datasources/ota_ble_datasource.dart';
import '../datasources/ota_remote_datasource.dart';

/// Implementation of [OtaRepository] using remote and BLE datasources.
@LazySingleton(as: OtaRepository)
class OtaRepositoryImpl implements OtaRepository {
  final OtaRemoteDataSource _remoteDataSource;
  final OtaBleDatasource _bleDataSource;

  OtaRepositoryImpl(this._remoteDataSource, this._bleDataSource);

  // ============================================================
  // REMOTE (Firebase)
  // ============================================================

  @override
  Future<Either<Failure, FirmwareInfo>> fetchLatestFirmwareInfo() async {
    try {
      final info = await _remoteDataSource.fetchLatestFirmwareInfo();
      return Right(info);
    } catch (e) {
      AppLogger.error('Failed to fetch firmware info', e);
      return Left(ServerFailure('Failed to fetch firmware info: $e'));
    }
  }

  @override
  Future<Either<Failure, String>> fetchMinFirmwareVersion() async {
    try {
      final version = await _remoteDataSource.fetchMinFirmwareVersion();
      return Right(version);
    } catch (e) {
      AppLogger.error('Failed to fetch min firmware version', e);
      return Left(ServerFailure('Failed to fetch min firmware version: $e'));
    }
  }

  @override
  Future<Either<Failure, List<int>>> downloadFirmwareBinary(
    String filePath, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final data = await _remoteDataSource.downloadFirmwareBinary(
        filePath,
        onProgress: onProgress,
      );
      return Right(data);
    } catch (e) {
      AppLogger.error('Failed to download firmware binary', e);
      return Left(ServerFailure('Failed to download firmware binary: $e'));
    }
  }

  // ============================================================
  // BLE (Device Communication)
  // ============================================================

  @override
  Future<Either<Failure, void>> sendOtaStart({
    required int expectedSize,
    required String expectedHash,
    required String version,
  }) async {
    try {
      await _bleDataSource.sendOtaStart(
        expectedSize: expectedSize,
        expectedHash: expectedHash,
        version: version,
      );
      return const Right(null);
    } on StateError catch (e) {
      return Left(BluetoothFailure('OTA start failed: ${e.message}'));
    } catch (e) {
      AppLogger.error('OTA start failed', e);
      return Left(BluetoothFailure('OTA start failed: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> sendOtaEnd() async {
    try {
      await _bleDataSource.sendOtaEnd();
      return const Right(null);
    } on StateError catch (e) {
      return Left(BluetoothFailure('OTA end failed: ${e.message}'));
    } catch (e) {
      AppLogger.error('OTA end failed', e);
      return Left(BluetoothFailure('OTA end failed: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> sendReboot() async {
    try {
      await _bleDataSource.sendReboot();
      return const Right(null);
    } on StateError catch (e) {
      return Left(BluetoothFailure('Reboot failed: ${e.message}'));
    } catch (e) {
      AppLogger.error('Reboot failed', e);
      return Left(BluetoothFailure('Reboot failed: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> sendOtaAbort() async {
    try {
      await _bleDataSource.sendOtaAbort();
      return const Right(null);
    } on StateError catch (e) {
      return Left(BluetoothFailure('OTA abort failed: ${e.message}'));
    } catch (e) {
      AppLogger.error('OTA abort failed', e);
      return Left(BluetoothFailure('OTA abort failed: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> writeOtaChunk(Uint8List chunk) async {
    try {
      await _bleDataSource.writeOtaChunk(chunk);
      return const Right(null);
    } on StateError catch (e) {
      return Left(BluetoothFailure('OTA chunk write failed: ${e.message}'));
    } catch (e) {
      return Left(BluetoothFailure('OTA chunk write failed: $e'));
    }
  }

  @override
  Stream<Map<String, dynamic>> listenForOtaNotifications() {
    return _bleDataSource.listenForOtaNotifications();
  }
}
