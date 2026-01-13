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

// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

Future<void> prepareBLERead(String deviceId, String type, int page) async {
  final device = BluetoothDevice(remoteId: DeviceIdentifier(deviceId));

  if (device.connectionState != BluetoothConnectionState.connected) {
    await device.connect(license: License.free, timeout: const Duration(seconds: 5));
  }

  final services = await device.discoverServices();

  final writeChar = services.expand((s) => s.characteristics).firstWhere((c) =>
      c.uuid.toString().toLowerCase() ==
      '12345678-1234-1234-1234-123456789010'); // CHAR_WRITE_UUID

  final command = json.encode({
    "cmd": "prepare_read",
    "type": type, // "prefs" or "logs"
    "page": page, // 🔢 NEW: include page
  });

  await writeChar.write(utf8.encode(command), withoutResponse: false);

  // Now read the response from the device
  await readBLEDataAndHandle(deviceId);
}
