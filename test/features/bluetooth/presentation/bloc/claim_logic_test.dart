import 'package:flutter_test/flutter_test.dart';
import 'package:traxelos/features/bluetooth/domain/entities/ble_device.dart';
import 'package:traxelos/features/bluetooth/presentation/bloc/device_connection_state.dart';
import 'package:traxelos/features/items/domain/entities/item.dart';

BleDevice _createTestDevice(String id) =>
    BleDevice(id: id, name: 'Test Device', rssi: 0);

Item _createTestItem(String id, {String? claimedBy}) => Item(
      id: id,
      name: 'Test $id',
      count: 0,
      todayCount: 0,
      incrementBy: 1,
      reminder: ReminderType.none,
      reminderValue: 0,
      lastUpdated: DateTime(2026, 1, 1),
      userId: 'user_123',
      claimedBy: claimedBy,
    );

void main() {
  group('Claim logic', () {
    group('isItemEditable', () {
      test('unclaimed item is always editable', () {
        final devices = <String, DeviceConnectionState>{};
        expect(isItemEditable(null, devices), isTrue);
      });

      test('claimed item is editable when claiming device is online', () {
        final devices = {
          'device_abc': DeviceConnectionState(
            device: _createTestDevice('device_abc'),
            syncStatus: DeviceSyncStatus.synced,
          ),
        };
        expect(isItemEditable('device_abc', devices), isTrue);
      });

      test('claimed item is NOT editable when claiming device is offline', () {
        final devices = <String, DeviceConnectionState>{};
        expect(isItemEditable('device_abc', devices), isFalse);
      });

      test('claimed item is NOT editable when claiming device is handshaking', () {
        final devices = {
          'device_abc': DeviceConnectionState(
            device: _createTestDevice('device_abc'),
            syncStatus: DeviceSyncStatus.handshaking,
          ),
        };
        expect(isItemEditable('device_abc', devices), isFalse);
      });
    });

    group('claim filtering', () {
      test('should keep unclaimed items and own claims, remove other claims', () {
        final items = [
          _createTestItem('item1', claimedBy: null),
          _createTestItem('item2', claimedBy: 'device_1'),
          _createTestItem('item3', claimedBy: 'device_2'),
          _createTestItem('item4', claimedBy: null),
          _createTestItem('item5', claimedBy: 'device_1'),
        ];

        // Filter for device_1: should keep unclaimed + device_1 claims
        final filtered = items
            .where((item) =>
                item.claimedBy == null || item.claimedBy == 'device_1')
            .toList();

        expect(filtered.length, 4);
        expect(
          filtered.map((i) => i.id),
          containsAll(['item1', 'item2', 'item4', 'item5']),
        );
        expect(filtered.map((i) => i.id), isNot(contains('item3')));
      });

      test('should keep all items when no claims exist', () {
        final items = [
          _createTestItem('item1', claimedBy: null),
          _createTestItem('item2', claimedBy: null),
        ];

        final filtered = items
            .where((item) =>
                item.claimedBy == null || item.claimedBy == 'device_1')
            .toList();

        expect(filtered.length, 2);
      });

      test('should return empty when all items claimed by other devices', () {
        final items = [
          _createTestItem('item1', claimedBy: 'device_2'),
          _createTestItem('item2', claimedBy: 'device_3'),
        ];

        final filtered = items
            .where((item) =>
                item.claimedBy == null || item.claimedBy == 'device_1')
            .toList();

        expect(filtered, isEmpty);
      });
    });
  });
}
