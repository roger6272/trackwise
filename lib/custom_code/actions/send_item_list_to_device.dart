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
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> sendItemListToDevice(String deviceId) async {
  final targetUUID = Guid("12345678-1234-1234-1234-123456789008");

  try {
    // Step 1: Create BluetoothDevice instance
    final device = BluetoothDevice(remoteId: DeviceIdentifier(deviceId));
    await device.connect(license: License.free, timeout: const Duration(seconds: 5));

    // Step 2: Fetch item list from Firestore
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final userRef = FirebaseFirestore.instance.doc("/users/$uid");

    final snapshot = await FirebaseFirestore.instance
        .collection('Item')
        .where('uid', isEqualTo: userRef)
        .get();

    final itemList = snapshot.docs.map((doc) {
      final data = doc.data();
      final ts = data['lastResetTime'] as Timestamp?;
      final lastResetTime = ts != null
          ? ts.toDate().toUtc().millisecondsSinceEpoch ~/ 1000
          : null;

      final reminderStr = data["reminder"] ?? "No Reminder";

      final reminder = reminderStr == "No Reminder"
          ? 0
          : (reminderStr == "Vibrate on Target" ? 1 : 2);

      return {
        "id": doc.id,
        "name": data["item_name"] ?? "Unnamed",
        "count": data["count"] ?? 0,
        "todaycount": data["todaycount"] ?? 0,
        "increment": data["increment_by"] ?? 1,
        "reminder": reminder,
        "reminder_value": data["reminder_value"] ?? 0,
        "lastResetTime": lastResetTime,
      };
    }).toList();

    final jsonStr = jsonEncode(itemList);
    print("Prepared JSON: $jsonStr");

    // Step 3: Discover services and find target characteristic
    final services = await device.discoverServices();
    final characteristics = services.expand((s) => s.characteristics);
    final char = characteristics.firstWhere(
      (c) => c.uuid == targetUUID,
      orElse: () => throw Exception("Target characteristic not found."),
    );

    // Step 4: Write JSON in chunks (MTU safe)
    const mtuLimit = 180;
    for (var i = 0; i < jsonStr.length; i += mtuLimit) {
      final chunk = jsonStr.substring(
          i, (i + mtuLimit > jsonStr.length) ? jsonStr.length : i + mtuLimit);
      await char.write(utf8.encode(chunk),
          withoutResponse: false); // BLE expects response
      await Future.delayed(const Duration(milliseconds: 30));
    }

    print("Sent item list to ESP32");
    print("Current UID: ${FirebaseAuth.instance.currentUser?.uid}");
    print("Item list length: ${itemList.length}");
    print("Item list JSON: $jsonStr");
  } catch (e) {
    print("Error sending item list: $e");
  }
}
