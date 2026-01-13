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

import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

Future<void> sendSelectedItemToDevice(
  String deviceId,
  String selectedId,
) async {
  final targetUUID = Guid("12345678-1234-1234-1234-123456789010");

  try {
    final device = BluetoothDevice(remoteId: DeviceIdentifier(deviceId));

    // Ensure connection
    if (device.connectionState != BluetoothConnectionState.connected) {
      await device.connect(license: License.free, timeout: const Duration(seconds: 5));
    }

    // Discover services
    final services = await device.discoverServices();

    final characteristics = services.expand((s) => s.characteristics);
    final char = characteristics.firstWhere(
      (c) => c.uuid == targetUUID,
      orElse: () {
        throw Exception("❌ Target characteristic $targetUUID not found.");
      },
    );

    // Send JSON command instead of plain ID
    final jsonCommand = jsonEncode({
      "cmd": "set_selected",
      "id": selectedId,
    });

    // Write selected item ID
    await char.write(utf8.encode(jsonCommand), withoutResponse: false);
    print("✅ JSON command sent: $jsonCommand");
  } catch (e) {
    print("🚨 Error sending selected ID command: $e");
  }
}
