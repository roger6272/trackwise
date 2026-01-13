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
import 'package:intl/intl.dart';

Future<void> sendCurrentTimeToDevice(String deviceId) async {
  final targetUUID = Guid(
      "12345678-1234-1234-1234-123456789010"); // Reuse or set a separate UUID if needed

  try {
    // Step 1: Connect to device
    final device = BluetoothDevice(remoteId: DeviceIdentifier(deviceId));
    await device.connect(license: License.free, timeout: const Duration(seconds: 5));

    // Step 2: Discover services and get the characteristic
    final services = await device.discoverServices();
    final characteristics = services.expand((s) => s.characteristics);
    final char = characteristics.firstWhere(
      (c) => c.uuid == targetUUID,
      orElse: () => throw Exception("Target characteristic not found."),
    );

    // Step 3: Get current time and format it
    final now = DateTime.now().toUtc();
    final offset = DateTime.now().timeZoneOffset.inMinutes;
    final formattedTime = DateFormat("yyyy-MM-dd HH:mm:ss").format(now);
    final timePayload = jsonEncode({
      "cmd": "set_time",
      "utc_time": formattedTime,
      "offset": offset,
    });

    // Step 4: Write time payload in chunks
    const mtuLimit = 180;
    for (var i = 0; i < timePayload.length; i += mtuLimit) {
      final chunk = timePayload.substring(
          i,
          (i + mtuLimit > timePayload.length)
              ? timePayload.length
              : i + mtuLimit);
      await char.write(utf8.encode(chunk), withoutResponse: false);
      await Future.delayed(const Duration(milliseconds: 30));
    }

    print("Time sent to ESP32: $formattedTime");
  } catch (e) {
    print("Error sending current time: $e");
  }
}
