import 'package:flutter_test/flutter_test.dart';

import 'package:trackwise/features/bluetooth/domain/entities/sync_state.dart';

void main() {
  group('SyncStatus', () {
    test('should have three values', () {
      expect(SyncStatus.values.length, 3);
      expect(SyncStatus.values, contains(SyncStatus.inSync));
      expect(SyncStatus.values, contains(SyncStatus.conflict));
      expect(SyncStatus.values, contains(SyncStatus.wrongAccount));
    });
  });

  group('HandshakeResult', () {
    test('should create with required fields', () {
      const result = HandshakeResult(
        status: SyncStatus.inSync,
        deviceInstanceId: 'device-uuid-123',
      );

      expect(result.status, SyncStatus.inSync);
      expect(result.deviceInstanceId, 'device-uuid-123');
      expect(result.deviceSyncSeq, isNull);
    });

    test('should create with deviceSyncSeq for conflict', () {
      const result = HandshakeResult(
        status: SyncStatus.conflict,
        deviceInstanceId: 'device-uuid-456',
        deviceSyncSeq: 40,
      );

      expect(result.status, SyncStatus.conflict);
      expect(result.deviceInstanceId, 'device-uuid-456');
      expect(result.deviceSyncSeq, 40);
    });

    group('fromJson', () {
      test('should parse in_sync response', () {
        final json = {
          'status': 'in_sync',
          'device_instance_id': 'uuid-123',
        };

        final result = HandshakeResult.fromJson(json);

        expect(result.status, SyncStatus.inSync);
        expect(result.deviceInstanceId, 'uuid-123');
        expect(result.deviceSyncSeq, isNull);
      });

      test('should parse conflict response with device_seq', () {
        final json = {
          'status': 'conflict',
          'device_instance_id': 'uuid-456',
          'device_seq': 40,
        };

        final result = HandshakeResult.fromJson(json);

        expect(result.status, SyncStatus.conflict);
        expect(result.deviceInstanceId, 'uuid-456');
        expect(result.deviceSyncSeq, 40);
      });

      test('should parse wrong_account response', () {
        final json = {
          'status': 'wrong_account',
          'device_instance_id': 'uuid-789',
        };

        final result = HandshakeResult.fromJson(json);

        expect(result.status, SyncStatus.wrongAccount);
        expect(result.deviceInstanceId, 'uuid-789');
        expect(result.deviceSyncSeq, isNull);
      });

      test('should handle unknown status as conflict', () {
        final json = {
          'status': 'unknown_status',
          'device_instance_id': 'uuid-000',
        };

        final result = HandshakeResult.fromJson(json);

        expect(result.status, SyncStatus.conflict);
      });

      test('should handle missing device_instance_id', () {
        final json = {
          'status': 'in_sync',
        };

        final result = HandshakeResult.fromJson(json);

        expect(result.deviceInstanceId, '');
      });

      test('should handle null status', () {
        final json = <String, dynamic>{
          'device_instance_id': 'uuid-123',
        };

        final result = HandshakeResult.fromJson(json);

        expect(result.status, SyncStatus.conflict); // Default to conflict
      });
    });

    test('should be equal when all fields match', () {
      const result1 = HandshakeResult(
        status: SyncStatus.conflict,
        deviceInstanceId: 'uuid-123',
        deviceSyncSeq: 40,
      );
      const result2 = HandshakeResult(
        status: SyncStatus.conflict,
        deviceInstanceId: 'uuid-123',
        deviceSyncSeq: 40,
      );

      expect(result1, equals(result2));
    });

    test('should not be equal when fields differ', () {
      const result1 = HandshakeResult(
        status: SyncStatus.inSync,
        deviceInstanceId: 'uuid-123',
      );
      const result2 = HandshakeResult(
        status: SyncStatus.conflict,
        deviceInstanceId: 'uuid-123',
        deviceSyncSeq: 40,
      );

      expect(result1, isNot(equals(result2)));
    });

    test('toString should include all fields', () {
      const result = HandshakeResult(
        status: SyncStatus.conflict,
        deviceInstanceId: 'uuid-123',
        deviceSyncSeq: 40,
      );

      final str = result.toString();

      expect(str, contains('conflict'));
      expect(str, contains('uuid-123'));
      expect(str, contains('40'));
    });
  });

  group('OverrideResult', () {
    test('should create with required fields', () {
      const result = OverrideResult(
        status: 'override_complete',
      );

      expect(result.status, 'override_complete');
      expect(result.message, isNull);
      expect(result.isSuccess, isTrue);
    });

    test('should create with error message', () {
      const result = OverrideResult(
        status: 'error',
        message: 'missing_chunks',
      );

      expect(result.status, 'error');
      expect(result.message, 'missing_chunks');
      expect(result.isSuccess, isFalse);
    });

    group('fromJson', () {
      test('should parse override_complete response', () {
        final json = {
          'status': 'override_complete',
        };

        final result = OverrideResult.fromJson(json);

        expect(result.status, 'override_complete');
        expect(result.message, isNull);
        expect(result.isSuccess, isTrue);
      });

      test('should parse error response with message', () {
        final json = {
          'status': 'error',
          'message': 'missing_chunks',
        };

        final result = OverrideResult.fromJson(json);

        expect(result.status, 'error');
        expect(result.message, 'missing_chunks');
        expect(result.isSuccess, isFalse);
      });

      test('should handle missing status', () {
        final json = <String, dynamic>{
          'message': 'some error',
        };

        final result = OverrideResult.fromJson(json);

        expect(result.status, 'error');
        expect(result.isSuccess, isFalse);
      });
    });

    test('should be equal when all fields match', () {
      const result1 = OverrideResult(status: 'error', message: 'test');
      const result2 = OverrideResult(status: 'error', message: 'test');

      expect(result1, equals(result2));
    });

    test('toString should include all fields', () {
      const result = OverrideResult(
        status: 'error',
        message: 'missing_chunks',
      );

      final str = result.toString();

      expect(str, contains('error'));
      expect(str, contains('missing_chunks'));
    });
  });

  group('SyncCompleteResult', () {
    test('should create with status', () {
      const result = SyncCompleteResult(status: 'seq_updated');

      expect(result.status, 'seq_updated');
      expect(result.isSuccess, isTrue);
    });

    test('isSuccess should be false for other statuses', () {
      const result = SyncCompleteResult(status: 'error');

      expect(result.isSuccess, isFalse);
    });

    group('fromJson', () {
      test('should parse seq_updated response', () {
        final json = {
          'status': 'seq_updated',
        };

        final result = SyncCompleteResult.fromJson(json);

        expect(result.status, 'seq_updated');
        expect(result.isSuccess, isTrue);
      });

      test('should handle missing status', () {
        final json = <String, dynamic>{};

        final result = SyncCompleteResult.fromJson(json);

        expect(result.status, '');
        expect(result.isSuccess, isFalse);
      });
    });

    test('should be equal when status matches', () {
      const result1 = SyncCompleteResult(status: 'seq_updated');
      const result2 = SyncCompleteResult(status: 'seq_updated');

      expect(result1, equals(result2));
    });

    test('toString should include status', () {
      const result = SyncCompleteResult(status: 'seq_updated');

      final str = result.toString();

      expect(str, contains('seq_updated'));
    });
  });
}
