import 'package:flutter_test/flutter_test.dart';

import 'package:traxelos/features/ota/data/models/firmware_info_model.dart';

void main() {
  group('FirmwareInfoModel', () {
    group('fromJson', () {
      test('parses valid JSON correctly', () {
        final json = {
          'version': '2.1.0',
          'file_path': 'firmware/bins/v2.1.0.bin',
          'sha256': 'abc123def456',
          'min_app_version': '1.0.0',
          'changelog': 'Bug fixes and improvements',
          'released_at': '2026-03-28T12:00:00.000Z',
        };

        final model = FirmwareInfoModel.fromJson(json);

        expect(model.version, '2.1.0');
        expect(model.filePath, 'firmware/bins/v2.1.0.bin');
        expect(model.sha256, 'abc123def456');
        expect(model.minAppVersion, '1.0.0');
        expect(model.changelog, 'Bug fixes and improvements');
        expect(model.releasedAt, DateTime.utc(2026, 3, 28, 12, 0, 0));
      });

      test('uses defaults for missing optional fields', () {
        final json = <String, dynamic>{};

        final model = FirmwareInfoModel.fromJson(json);

        expect(model.version, '0.0.0');
        expect(model.filePath, '');
        expect(model.sha256, '');
        expect(model.minAppVersion, '1.0.0');
        expect(model.changelog, '');
        // releasedAt defaults to DateTime.now(), just verify it's reasonable
        expect(
          model.releasedAt.difference(DateTime.now()).inSeconds.abs(),
          lessThan(5),
        );
      });
    });

    group('toJson', () {
      test('round-trip: fromJson → toJson preserves data', () {
        final originalJson = {
          'version': '2.1.0',
          'file_path': 'firmware/bins/v2.1.0.bin',
          'sha256': 'abc123def456',
          'min_app_version': '1.0.0',
          'changelog': 'Bug fixes and improvements',
          'released_at': '2026-03-28T12:00:00.000Z',
        };

        final model = FirmwareInfoModel.fromJson(originalJson);
        final roundTripped = model.toJson();

        expect(roundTripped['version'], '2.1.0');
        expect(roundTripped['file_path'], 'firmware/bins/v2.1.0.bin');
        expect(roundTripped['sha256'], 'abc123def456');
        expect(roundTripped['min_app_version'], '1.0.0');
        expect(roundTripped['changelog'], 'Bug fixes and improvements');
        expect(roundTripped['released_at'], '2026-03-28T12:00:00.000Z');
      });
    });
  });
}
