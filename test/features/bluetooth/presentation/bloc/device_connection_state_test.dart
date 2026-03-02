import 'package:flutter_test/flutter_test.dart';
import 'package:traxelos/features/bluetooth/domain/entities/ble_device.dart';
import 'package:traxelos/features/bluetooth/presentation/bloc/device_connection_state.dart';

void main() {
  group('DeviceConnectionState', () {
    final testDevice = BleDevice(id: 'AA:BB:CC', name: 'Test Device', rssi: -50);

    test('isOnline should be true when syncStatus is synced', () {
      final state = DeviceConnectionState(
        device: testDevice,
        syncStatus: DeviceSyncStatus.synced,
      );
      expect(state.isOnline, true);
    });

    test('isOnline should be false for non-synced statuses', () {
      for (final status in DeviceSyncStatus.values) {
        final state = DeviceConnectionState(device: testDevice, syncStatus: status);
        if (status == DeviceSyncStatus.synced) {
          expect(state.isOnline, true);
        } else {
          expect(state.isOnline, false, reason: '$status should not be online');
        }
      }
    });

    test('copyWith should preserve fields when not specified', () {
      final state = DeviceConnectionState(
        device: testDevice,
        syncStatus: DeviceSyncStatus.syncing,
        selectedItemId: 'item_1',
        isOverriding: true,
      );
      final copied = state.copyWith(syncStatus: DeviceSyncStatus.synced);
      expect(copied.device, testDevice);
      expect(copied.syncStatus, DeviceSyncStatus.synced);
      expect(copied.selectedItemId, 'item_1');
      expect(copied.isOverriding, true);
    });

    test('copyWith clearSelectedItemId should set to null', () {
      final state = DeviceConnectionState(
        device: testDevice,
        syncStatus: DeviceSyncStatus.synced,
        selectedItemId: 'item_1',
      );
      final cleared = state.copyWith(clearSelectedItemId: true);
      expect(cleared.selectedItemId, isNull);
    });
  });

  group('DeviceSyncStatus', () {
    test('should have all expected values', () {
      expect(DeviceSyncStatus.values, containsAll([
        DeviceSyncStatus.handshaking,
        DeviceSyncStatus.syncing,
        DeviceSyncStatus.synced,
        DeviceSyncStatus.setup,
        DeviceSyncStatus.wrongAccount,
      ]));
    });
  });

  group('isItemEditable', () {
    final testDevice = BleDevice(id: 'AA:BB:CC', name: 'Test', rssi: -50);

    test('unclaimed items are always editable', () {
      expect(isItemEditable(null, {}), true);
    });

    test('claimed item is editable when claiming device is online', () {
      final devices = {
        'dev_1': DeviceConnectionState(device: testDevice, syncStatus: DeviceSyncStatus.synced),
      };
      expect(isItemEditable('dev_1', devices), true);
    });

    test('claimed item is NOT editable when claiming device is offline', () {
      expect(isItemEditable('dev_1', {}), false);
    });

    test('claimed item is NOT editable when claiming device is not synced', () {
      final devices = {
        'dev_1': DeviceConnectionState(device: testDevice, syncStatus: DeviceSyncStatus.handshaking),
      };
      expect(isItemEditable('dev_1', devices), false);
    });
  });
}
