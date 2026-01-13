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

Future<void> decodeInsertLogs(String message, String deviceId) async {
  final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  final userRef = FirebaseFirestore.instance.doc('users/$uid');

  dynamic parsed;
  try {
    parsed = jsonDecode(message);
  } catch (e) {
    debugPrint("❌ Failed to decode logs data: $message");
    debugPrint("Error: $e");
    return;
  }

  final data = parsed['data'];

  debugPrint("LogsReceivedandParsed"); ////////Receive Logs

  for (final log in data) {
    final event = log['event'] as String;
    final count = log['count'] as int;
    final increment = log['increment'] as int;
    final timestamp = log['timestamp'] as int;
    final itemRef = FirebaseFirestore.instance.doc("/Item/${log['itemId']}");
    final logId = '${itemRef.id}-$event-$timestamp-$count';

    await FirebaseFirestore.instance.collection('EventLog').doc(logId).set({
      'item': itemRef,
      'event_name': event,
      'currentcount': count,
      'increment': increment,
      'created_time': Timestamp.fromMillisecondsSinceEpoch(timestamp * 1000),
      'uid': userRef,
    }, SetOptions(merge: true));
  }

  final hasMore = parsed['hasMore'] == true;

  if (hasMore) {
    FFAppState().update(() =>
        FFAppState().currentLogPage += 1); // or track with a local variable
    await prepareBLERead(deviceId, 'logs', FFAppState().currentLogPage);
  } else {
    FFAppState().update(() => FFAppState().currentLogPage = 0);

    // Get BLE device and services
    final device = BluetoothDevice(remoteId: DeviceIdentifier(deviceId));
    final services = await device.discoverServices();

    // Send clear_logs command to device
    final writeChar = services.expand((s) => s.characteristics).firstWhere(
        (c) =>
            c.uuid.toString().toLowerCase() ==
            '12345678-1234-1234-1234-123456789010'); // CHAR_WRITE_UUID

    const clearLogsJson = '{"cmd":"clear_logs"}';
    await writeChar.write(utf8.encode(clearLogsJson), withoutResponse: false);
    debugPrint("🧹 Sent clear_logs command to device");
  }
}
