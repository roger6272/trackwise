import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:traxelos/features/bluetooth/domain/entities/paired_device.dart';

void main() {
  group('PairedDevice', () {
    final testDateTime = DateTime(2024, 1, 15, 10, 30);
    final testDevice = PairedDevice(
      deviceInstanceId: 'device-123-uuid',
      deviceName: 'My Trackwise',
      pairedAt: testDateTime,
    );

    test('should create PairedDevice with required fields', () {
      expect(testDevice.deviceInstanceId, 'device-123-uuid');
      expect(testDevice.deviceName, 'My Trackwise');
      expect(testDevice.pairedAt, testDateTime);
    });

    test('should support copyWith', () {
      final copy = testDevice.copyWith(deviceName: 'New Name');

      expect(copy.deviceInstanceId, testDevice.deviceInstanceId);
      expect(copy.deviceName, 'New Name');
      expect(copy.pairedAt, testDevice.pairedAt);
    });

    test('should default color to 0', () {
      expect(testDevice.color, 0);
    });

    test('copyWith should update color', () {
      final copy = testDevice.copyWith(color: 3);
      expect(copy.color, 3);
    });

    test('should be equal when all fields match', () {
      final sameDevice = PairedDevice(
        deviceInstanceId: 'device-123-uuid',
        deviceName: 'My Trackwise',
        pairedAt: testDateTime,
      );

      expect(testDevice, equals(sameDevice));
    });

    test('should not be equal when fields differ', () {
      final differentDevice = PairedDevice(
        deviceInstanceId: 'different-uuid',
        deviceName: 'My Trackwise',
        pairedAt: testDateTime,
      );

      expect(testDevice, isNot(equals(differentDevice)));
    });

    group('fromFirestore', () {
      test('should parse from Firestore map with Timestamp', () {
        final data = {
          'device_instance_id': 'device-456',
          'device_name': 'Work Device',
          'paired_at': Timestamp.fromDate(testDateTime),
        };

        final device = PairedDevice.fromFirestore(data);

        expect(device.deviceInstanceId, 'device-456');
        expect(device.deviceName, 'Work Device');
        expect(device.pairedAt, testDateTime);
      });

      test('should parse from Firestore map with int milliseconds', () {
        final data = {
          'device_instance_id': 'device-789',
          'device_name': 'Home Device',
          'paired_at': testDateTime.millisecondsSinceEpoch,
        };

        final device = PairedDevice.fromFirestore(data);

        expect(device.deviceInstanceId, 'device-789');
        expect(device.deviceName, 'Home Device');
        expect(device.pairedAt, testDateTime);
      });

      test('should parse color field', () {
        final data = {
          'device_instance_id': 'device-456',
          'device_name': 'Work Device',
          'paired_at': Timestamp.fromDate(testDateTime),
          'color': 5,
        };
        final device = PairedDevice.fromFirestore(data);
        expect(device.color, 5);
      });

      test('should default color to 0 when missing', () {
        final data = {
          'device_instance_id': 'device-456',
          'device_name': 'Work Device',
          'paired_at': Timestamp.fromDate(testDateTime),
        };
        final device = PairedDevice.fromFirestore(data);
        expect(device.color, 0);
      });

      test('should use default values for missing fields', () {
        final data = <String, dynamic>{};

        final device = PairedDevice.fromFirestore(data);

        expect(device.deviceInstanceId, '');
        expect(device.deviceName, 'Traxelos One');
        expect(device.pairedAt, isA<DateTime>());
      });

      test('should handle null paired_at', () {
        final data = {
          'device_instance_id': 'device-abc',
          'device_name': 'Test Device',
          'paired_at': null,
        };

        final device = PairedDevice.fromFirestore(data);

        expect(device.deviceInstanceId, 'device-abc');
        expect(device.pairedAt, isA<DateTime>());
      });
    });

    group('toFirestore', () {
      test('should convert to Firestore map', () {
        final map = testDevice.toFirestore();

        expect(map['device_instance_id'], 'device-123-uuid');
        expect(map['device_name'], 'My Trackwise');
        expect(map['paired_at'], isA<Timestamp>());
        expect(
          (map['paired_at'] as Timestamp).toDate(),
          testDateTime,
        );
        expect(map['color'], 0);
      });
    });

    test('toString should include all fields', () {
      final str = testDevice.toString();

      expect(str, contains('device-123-uuid'));
      expect(str, contains('My Trackwise'));
    });
  });
}
