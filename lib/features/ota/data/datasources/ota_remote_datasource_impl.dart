import 'dart:convert';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/utils/logger.dart';
import '../models/firmware_info_model.dart';
import 'ota_remote_datasource.dart';

/// Implementation of [OtaRemoteDataSource] using Firebase Storage and Remote Config.
@LazySingleton(as: OtaRemoteDataSource)
class OtaRemoteDataSourceImpl implements OtaRemoteDataSource {
  final FirebaseStorage _storage;
  final FirebaseRemoteConfig _remoteConfig;

  /// Hardcoded fallback for min firmware version when Remote Config is unreachable.
  static const String _fallbackMinFirmwareVersion = '1.0.0';

  /// Maximum firmware binary size (2MB) — must fit in ESP32 OTA partition (~1.9MB).
  static const int _maxBinarySize = 2 * 1024 * 1024;

  /// OTA firmware channel: "release" or "beta".
  /// Set at build time via `--dart-define=OTA_CHANNEL=beta`.
  static const String _channel =
      String.fromEnvironment('OTA_CHANNEL', defaultValue: 'release');

  OtaRemoteDataSourceImpl(this._storage, this._remoteConfig);

  @override
  Future<FirmwareInfoModel> fetchLatestFirmwareInfo() async {
    AppLogger.debug('Fetching firmware info (channel: $_channel)');

    final ref = _storage.ref('firmware/$_channel/latest.json');
    final data = await ref.getData(_maxBinarySize);

    if (data == null) {
      throw Exception('Failed to download firmware/$_channel/latest.json: no data');
    }

    final jsonString = utf8.decode(data);
    final json = jsonDecode(jsonString) as Map<String, dynamic>;

    final model = FirmwareInfoModel.fromJson(json);
    AppLogger.debug('Latest firmware: v${model.version}');

    return model;
  }

  @override
  Future<String> fetchMinFirmwareVersion() async {
    try {
      // Fetch with a short timeout — don't block OTA check on Remote Config
      await _remoteConfig.fetchAndActivate();
      final version = _remoteConfig.getString('min_firmware_version');

      if (version.isEmpty) {
        AppLogger.debug(
            'Remote Config min_firmware_version is empty, using fallback');
        return _fallbackMinFirmwareVersion;
      }

      AppLogger.debug('Min firmware version from Remote Config: $version');
      return version;
    } catch (e) {
      AppLogger.error('Failed to fetch Remote Config, using fallback', e);
      return _fallbackMinFirmwareVersion;
    }
  }

  @override
  Future<List<int>> downloadFirmwareBinary(
    String filePath, {
    void Function(double progress)? onProgress,
  }) async {
    AppLogger.debug('Downloading firmware binary: $filePath');

    final ref = _storage.ref(filePath);

    // Get file metadata to know total size for progress reporting
    final metadata = await ref.getMetadata();
    final totalSize = metadata.size ?? 0;

    if (totalSize > _maxBinarySize) {
      throw Exception(
          'Firmware binary too large: $totalSize bytes (max: $_maxBinarySize)');
    }

    // Download with progress tracking
    final downloadTask = ref.getData(_maxBinarySize);

    // Firebase getData doesn't support progress natively on the returned future,
    // so we report 0 at start and 1.0 on completion. For real streaming progress,
    // the BLoC layer can use getStream or writeToFile instead.
    onProgress?.call(0.0);

    final data = await downloadTask;

    if (data == null) {
      throw Exception('Failed to download firmware binary: no data');
    }

    onProgress?.call(1.0);
    AppLogger.debug('Downloaded firmware binary: ${data.length} bytes');

    return data.toList();
  }
}
