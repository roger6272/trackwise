import 'package:flutter_test/flutter_test.dart';

import 'package:traxelos/features/bluetooth/domain/entities/sync_state.dart';

void main() {
  group('SyncStatus', () {
    test('should have three values', () {
      expect(SyncStatus.values.length, 3);
      expect(SyncStatus.values, contains(SyncStatus.inSync));
      expect(SyncStatus.values, contains(SyncStatus.wrongAccount));
      expect(SyncStatus.values, contains(SyncStatus.uninitialized));
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
      });

      test('should parse wrong_account response', () {
        final json = {
          'status': 'wrong_account',
          'device_instance_id': 'uuid-789',
        };

        final result = HandshakeResult.fromJson(json);

        expect(result.status, SyncStatus.wrongAccount);
        expect(result.deviceInstanceId, 'uuid-789');
      });

      test('should handle unknown status as inSync', () {
        final json = {
          'status': 'unknown_status',
          'device_instance_id': 'uuid-000',
        };

        final result = HandshakeResult.fromJson(json);

        expect(result.status, SyncStatus.inSync);
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

        expect(result.status, SyncStatus.inSync); // Default to inSync
      });
    });

    test('should be equal when all fields match', () {
      const result1 = HandshakeResult(
        status: SyncStatus.inSync,
        deviceInstanceId: 'uuid-123',
      );
      const result2 = HandshakeResult(
        status: SyncStatus.inSync,
        deviceInstanceId: 'uuid-123',
      );

      expect(result1, equals(result2));
    });

    test('should not be equal when fields differ', () {
      const result1 = HandshakeResult(
        status: SyncStatus.inSync,
        deviceInstanceId: 'uuid-123',
      );
      const result2 = HandshakeResult(
        status: SyncStatus.wrongAccount,
        deviceInstanceId: 'uuid-123',
      );

      expect(result1, isNot(equals(result2)));
    });

    test('toString should include all fields', () {
      const result = HandshakeResult(
        status: SyncStatus.inSync,
        deviceInstanceId: 'uuid-123',
      );

      final str = result.toString();

      expect(str, contains('inSync'));
      expect(str, contains('uuid-123'));
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

}
