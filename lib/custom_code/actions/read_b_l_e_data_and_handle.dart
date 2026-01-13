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
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> readBLEDataAndHandle(String deviceId) async {
  final device = BluetoothDevice(remoteId: DeviceIdentifier(deviceId));
  final services = await device.discoverServices();

  final readChar = services.expand((s) => s.characteristics).firstWhere((c) =>
      c.uuid.toString().toLowerCase() ==
      '12345678-1234-1234-1234-123456789001'); // CHAR_READ_UUID

  final value = await readChar.read();
  final jsonString = utf8.decode(value);

  debugPrint("📦 BLE raw payload size: ${value.length} bytes");
  debugPrint("📦 BLE raw string: $jsonString");

  dynamic parsed;
  try {
    parsed = jsonDecode(jsonString);
  } catch (e) {
    debugPrint("❌ Failed to decode BLE data: $jsonString");
    debugPrint("Error: $e");
    return;
  }

  print("Still fine before decodeinsertlogs");

  // Handle empty array response (no data)
  if (parsed is List) {
    if (parsed.isEmpty) {
      debugPrint("📭 BLE returned empty array - no data");
      return;
    }
    debugPrint("❌ BLE returned unexpected array: $parsed");
    return;
  }

  // Ensure parsed is a Map
  if (parsed is! Map<String, dynamic>) {
    debugPrint("❌ BLE data is not an object: $parsed");
    return;
  }

  final type = parsed['type'];

////////////Device receives 'logs' command and sends logs to update to app////////////////////////////////////////////////////////////////////////////////////////////////
  if (type == 'logs') {
    decodeInsertLogs(jsonString, deviceId);

///////////Device receives 'prefs' command and sends item info to update COUNT & SELECTED ITEM in UI////////////////////////////////////////////
  } else if (type == 'prefs') {
    decodeUpdateItemStatus(jsonString);
  } else {
    print("Unexpected BLE data format: $parsed");
  }
}
