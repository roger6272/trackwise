// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

Future<bool> connectDevice(BTDeviceStruct deviceInfo) async {
  final device = BluetoothDevice.fromId(deviceInfo.id);
  bool hasRequiredCharacteristics = false;

  try {
    if (device.connectionState != BluetoothConnectionState.connected) {
      await device.connect(license: License.free, timeout: const Duration(seconds: 10));
      debugPrint('Device connected');
    }

    final services = await device.discoverServices();

    // Scan for expected characteristics by UUID
    final expectedUuids = [
      '12345678-1234-1234-1234-123456789008', // CHAR_SET_ITEMS_UUID
      '12345678-1234-1234-1234-123456789010', // CHAR_SET_SELECTED_UUID
    ];

    for (BluetoothService service in services) {
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        final uuid = characteristic.uuid.toString().toLowerCase();
        if (expectedUuids.contains(uuid)) {
          debugPrint('Found expected characteristic: $uuid');
          hasRequiredCharacteristics = true;
        }
      }
    }
  } catch (e) {
    debugPrint('Connection failed: ${e.toString()}');
  }

  return hasRequiredCharacteristics;
}
