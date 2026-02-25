import 'package:flutter_test/flutter_test.dart';
import 'package:traxelos/features/bluetooth/data/datasources/device_connection.dart';

void main() {
  group('DeviceConnection', () {
    test('should be created with deviceInstanceId', () {
      final conn = DeviceConnection(deviceInstanceId: 'dev_abc');
      expect(conn.deviceInstanceId, 'dev_abc');
      expect(conn.negotiatedMtu, 180); // BluetoothConstants.defaultMtuLimit
      expect(conn.isProcessingWrite, false);
    });

    test('dispose should cancel subscriptions and close controller', () async {
      final conn = DeviceConnection(deviceInstanceId: 'dev_abc');
      // Should not throw
      await conn.dispose();
      expect(conn.messageController.isClosed, true);
    });

    test('clearConnectionState should reset all fields', () {
      final conn = DeviceConnection(deviceInstanceId: 'dev_abc');
      conn.negotiatedMtu = 512;
      conn.clearConnectionState();
      expect(conn.negotiatedMtu, 180);
      expect(conn.readChar, isNull);
      expect(conn.notifyChar, isNull);
      expect(conn.setItemsChar, isNull);
      expect(conn.writeChar, isNull);
    });
  });
}
