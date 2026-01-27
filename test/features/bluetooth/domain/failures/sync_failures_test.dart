import 'package:flutter_test/flutter_test.dart';
import 'package:traxelos/core/error/failures.dart';
import 'package:traxelos/features/bluetooth/domain/failures/sync_failures.dart';

void main() {
  group('SyncFailures', () {
    group('NoInternetFailure', () {
      test('should extend SyncFailure', () {
        const failure = NoInternetFailure();
        expect(failure, isA<SyncFailure>());
        expect(failure, isA<Failure>());
      });

      test('should have default message', () {
        const failure = NoInternetFailure();
        expect(failure.message, 'Internet connection required to sync.');
      });

      test('should allow custom message', () {
        const failure = NoInternetFailure('Custom message');
        expect(failure.message, 'Custom message');
      });
    });

    group('WrongAccountFailure', () {
      test('should extend SyncFailure', () {
        const failure = WrongAccountFailure();
        expect(failure, isA<SyncFailure>());
      });

      test('should have default message', () {
        const failure = WrongAccountFailure();
        expect(failure.message, contains('Factory reset required'));
      });
    });

    group('DeviceLimitFailure', () {
      test('should extend SyncFailure', () {
        const failure = DeviceLimitFailure();
        expect(failure, isA<SyncFailure>());
      });

      test('should have default message mentioning 10 devices', () {
        const failure = DeviceLimitFailure();
        expect(failure.message, contains('10 devices'));
      });
    });

    group('SyncConflictFailure', () {
      test('should extend SyncFailure', () {
        const failure = SyncConflictFailure(appSyncSeq: 5);
        expect(failure, isA<SyncFailure>());
      });

      test('should contain sync sequence numbers', () {
        const failure = SyncConflictFailure(
          deviceSyncSeq: 3,
          appSyncSeq: 5,
        );
        expect(failure.deviceSyncSeq, 3);
        expect(failure.appSyncSeq, 5);
      });

      test('should support null deviceSyncSeq', () {
        const failure = SyncConflictFailure(appSyncSeq: 5);
        expect(failure.deviceSyncSeq, isNull);
      });

      test('should implement Equatable', () {
        const failure1 = SyncConflictFailure(deviceSyncSeq: 3, appSyncSeq: 5);
        const failure2 = SyncConflictFailure(deviceSyncSeq: 3, appSyncSeq: 5);
        expect(failure1, equals(failure2));
      });

      test('should have correct props', () {
        const failure = SyncConflictFailure(
          deviceSyncSeq: 3,
          appSyncSeq: 5,
          message: 'test',
        );
        expect(failure.props, contains('test'));
        expect(failure.props, contains(5));
        // deviceSyncSeq is included when not null
        expect(failure.props, contains(3));
      });

      test('should not include null deviceSyncSeq in props', () {
        const failure = SyncConflictFailure(appSyncSeq: 5);
        // props should only have message and appSyncSeq
        expect(failure.props.length, 2);
      });
    });

    group('FirestoreUpdateFailure', () {
      test('should extend SyncFailure', () {
        const failure = FirestoreUpdateFailure();
        expect(failure, isA<SyncFailure>());
      });

      test('should have default message', () {
        const failure = FirestoreUpdateFailure();
        expect(failure.message, contains('Sync incomplete'));
      });
    });

    group('TooManyItemsFailure', () {
      test('should extend SyncFailure', () {
        const failure = TooManyItemsFailure(itemCount: 101);
        expect(failure, isA<SyncFailure>());
      });

      test('should contain item count', () {
        const failure = TooManyItemsFailure(itemCount: 101);
        expect(failure.itemCount, 101);
      });

      test('should have default message mentioning 100 items', () {
        const failure = TooManyItemsFailure(itemCount: 101);
        expect(failure.message, contains('100 items'));
      });

      test('should have correct props', () {
        const failure = TooManyItemsFailure(itemCount: 150);
        expect(failure.props, contains(150));
      });
    });

    group('SyncCompleteNotAcknowledgedFailure', () {
      test('should extend SyncFailure', () {
        const failure = SyncCompleteNotAcknowledgedFailure();
        expect(failure, isA<SyncFailure>());
      });

      test('should have default message', () {
        const failure = SyncCompleteNotAcknowledgedFailure();
        expect(failure.message, contains('did not confirm'));
      });
    });

    group('OverrideFailure', () {
      test('should extend SyncFailure', () {
        const failure = OverrideFailure();
        expect(failure, isA<SyncFailure>());
      });

      test('should contain device message when provided', () {
        const failure = OverrideFailure(deviceMessage: 'missing_chunks');
        expect(failure.deviceMessage, 'missing_chunks');
      });

      test('should support null device message', () {
        const failure = OverrideFailure();
        expect(failure.deviceMessage, isNull);
      });

      test('should have correct props when deviceMessage is set', () {
        const failure = OverrideFailure(deviceMessage: 'error');
        expect(failure.props, contains('error'));
      });

      test('should not include null deviceMessage in props', () {
        const failure = OverrideFailure();
        // props should only have message when deviceMessage is null
        expect(failure.props.length, 1);
      });
    });

    group('BleSyncFailure', () {
      test('should extend SyncFailure', () {
        const failure = BleSyncFailure();
        expect(failure, isA<SyncFailure>());
      });

      test('should have default message', () {
        const failure = BleSyncFailure();
        expect(failure.message, contains('Bluetooth error'));
      });

      test('should allow custom message', () {
        const failure = BleSyncFailure('Connection lost');
        expect(failure.message, 'Connection lost');
      });
    });

    group('NotAuthenticatedFailure', () {
      test('should extend SyncFailure', () {
        const failure = NotAuthenticatedFailure();
        expect(failure, isA<SyncFailure>());
      });

      test('should have default message', () {
        const failure = NotAuthenticatedFailure();
        expect(failure.message, contains('log in'));
      });
    });
  });
}
