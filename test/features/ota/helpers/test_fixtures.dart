import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:traxelos/features/ota/data/models/firmware_info_model.dart';
import 'package:traxelos/features/ota/domain/entities/firmware_info.dart';

final testReleasedAt = DateTime.utc(2026, 3, 28, 12, 0, 0);

/// Creates a [FirmwareInfo] whose sha256 matches the given [binaryData].
FirmwareInfo testFirmwareInfoForBinary(Uint8List binaryData) {
  return FirmwareInfo(
    version: '2.1.0',
    filePath: 'firmware/bins/v2.1.0.bin',
    sha256: sha256.convert(binaryData).toString(),
    minAppVersion: '1.0.0',
    changelog: 'Bug fixes and improvements',
    releasedAt: testReleasedAt,
  );
}

final testFirmwareInfo = FirmwareInfo(
  version: '2.1.0',
  filePath: 'firmware/bins/v2.1.0.bin',
  sha256: 'abc123def456',
  minAppVersion: '1.0.0',
  changelog: 'Bug fixes and improvements',
  releasedAt: testReleasedAt,
);

final testFirmwareInfoModel = FirmwareInfoModel(
  version: '2.1.0',
  filePath: 'firmware/bins/v2.1.0.bin',
  sha256: 'abc123def456',
  minAppVersion: '1.0.0',
  changelog: 'Bug fixes and improvements',
  releasedAt: testReleasedAt,
);
