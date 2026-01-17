// BLE Legacy Functions
//
// Extracted from FlutterFlow custom_code/actions/ to remove FF dependencies.
// These functions handle BLE communication with ESP32 device for:
// - Reading prefs (item counts, selected item)
// - Reading logs (event history with pagination)
//
// Preserves exact behavior from original implementation.

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'ble_legacy_state.dart';
import 'bluetooth_constants.dart';

/// Sends a prepare_read command to the BLE device and handles the response.
///
/// [deviceId] - The BLE device remote ID
/// [type] - Either "prefs" or "logs"
/// [page] - Page number for paginated log reading
Future<void> prepareBLERead(String deviceId, String type, int page) async {
  final device = BluetoothDevice(remoteId: DeviceIdentifier(deviceId));

  final currentState = await device.connectionState.first;
  if (currentState != BluetoothConnectionState.connected) {
    await device.connect(license: License.free, timeout: const Duration(seconds: 5));
  }

  final services = await device.discoverServices();

  final writeChar = services.expand((s) => s.characteristics).firstWhere((c) =>
      c.uuid.toString().toLowerCase() ==
      BluetoothConstants.writeCharacteristicUUID.toLowerCase());

  final command = json.encode({
    "cmd": "prepare_read",
    "type": type,
    "page": page,
  });

  await writeChar.write(utf8.encode(command), withoutResponse: false);

  // Now read the response from the device
  await readBLEDataAndHandle(deviceId);
}

/// Reads BLE data from device and routes to appropriate handler.
///
/// [deviceId] - The BLE device remote ID
Future<void> readBLEDataAndHandle(String deviceId) async {
  final device = BluetoothDevice(remoteId: DeviceIdentifier(deviceId));
  final services = await device.discoverServices();

  final readChar = services.expand((s) => s.characteristics).firstWhere((c) =>
      c.uuid.toString().toLowerCase() ==
      BluetoothConstants.readCharacteristicUUID.toLowerCase());

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

  debugPrint("Still fine before decode handlers"); // Debug: remove after hardware testing

  // Device receives 'logs' command and sends logs to update to app
  // NOTE: await added intentionally - original FF code didn't await, but this ensures
  // Firestore writes complete before continuing (safer behavior)
  if (type == 'logs') {
    await decodeInsertLogs(jsonString, deviceId);
  }
  // Device receives 'prefs' command and sends item info to update COUNT & SELECTED ITEM in UI
  else if (type == 'prefs') {
    await decodeUpdateItemStatus(jsonString);
  } else {
    debugPrint("Unexpected BLE data format: $parsed");
  }
}

/// Decodes log data from device and inserts into Firestore EventLog collection.
/// Handles pagination - requests next page if hasMore is true.
/// Uses batch writes for better performance.
///
/// [message] - JSON string from device containing log data
/// [deviceId] - The BLE device remote ID (for pagination requests)
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

  debugPrint("LogsReceivedandParsed");

  // Use batch writes for better performance
  final batch = FirebaseFirestore.instance.batch();
  int logCount = 0;

  for (final log in data) {
    final event = log['event'] as String;
    final count = log['count'] as int;
    final increment = log['increment'] as int;
    final timestamp = log['timestamp'] as int;
    final itemRef = FirebaseFirestore.instance.doc("/Item/${log['itemId']}");
    final logId = '${itemRef.id}-$event-$timestamp-$count';

    // Debug: show what timestamp the device sent
    final dateFromDevice = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000, isUtc: true);
    debugPrint("📅 Device sent timestamp: $timestamp (UTC: $dateFromDevice, Local: ${dateFromDevice.toLocal()})");

    final docRef = FirebaseFirestore.instance.collection('EventLog').doc(logId);
    batch.set(docRef, {
      'item': itemRef,
      'event_name': event,
      'currentcount': count,
      'increment': increment,
      'created_time': Timestamp.fromMillisecondsSinceEpoch(timestamp * 1000),
      'uid': userRef,
    }, SetOptions(merge: true));
    logCount++;
  }

  if (logCount > 0) {
    await batch.commit();
    debugPrint("✅ Batch inserted $logCount event logs");
  }

  final hasMore = parsed['hasMore'] == true;

  if (hasMore) {
    BleLegacyState().currentLogPage += 1;
    await prepareBLERead(deviceId, 'logs', BleLegacyState().currentLogPage);
  } else {
    BleLegacyState().currentLogPage = 0;

    // Get BLE device and services
    final device = BluetoothDevice(remoteId: DeviceIdentifier(deviceId));
    final services = await device.discoverServices();

    // Send clear_logs command to device
    final writeChar = services.expand((s) => s.characteristics).firstWhere(
        (c) =>
            c.uuid.toString().toLowerCase() ==
            BluetoothConstants.writeCharacteristicUUID.toLowerCase());

    const clearLogsJson = '{"cmd":"clear_logs"}';
    await writeChar.write(utf8.encode(clearLogsJson), withoutResponse: false);
    debugPrint("🧹 Sent clear_logs command to device");
  }
}

/// Decodes prefs data from device and updates item counts in Firestore.
/// Also updates the currently selected item ID.
///
/// [message] - JSON string from device containing prefs data
Future<void> decodeUpdateItemStatus(String message) async {
  final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  final userRef = FirebaseFirestore.instance.doc('users/$uid');

  dynamic parsed;

  try {
    parsed = jsonDecode(message);
  } catch (e) {
    debugPrint("❌ Failed to decode BLE data: $message");
    debugPrint("Error: $e");
    return;
  }

  final data = parsed['data'];
  final selectedId = parsed['selected_id'];

  final existingSnapshot = await FirebaseFirestore.instance
      .collection('Item')
      .where('uid', isEqualTo: userRef)
      .get();

  final existingItemIDs = existingSnapshot.docs.map((doc) => doc.id).toSet();

  BleLegacyState().isactivated = selectedId;

  final batch = FirebaseFirestore.instance.batch();
  int updateCount = 0;

  for (final item in data) {
    if (item is Map<String, dynamic>) {
      final itemId = item['id'];
      final count = item['count'] ?? 0;
      final todaycount = item['todaycount'] ?? 0;
      final lastResetTime =
          Timestamp.fromMillisecondsSinceEpoch(item['lastResetTime'] * 1000);
      final itemRef = FirebaseFirestore.instance.collection('Item').doc(itemId);

      if (existingItemIDs.contains(itemId)) {
        batch.update(itemRef, {
          'count': count,
          'todaycount': todaycount,
          'lastResetTime': lastResetTime,
        });
        updateCount++;
        debugPrint("🔄 Queued update for item: $itemId");
      } else {
        debugPrint("⚠️ Item not found: $itemId");
      }
    }
  }

  if (updateCount > 0) {
    await batch.commit();
    debugPrint("✅ Batch update committed for $updateCount items.");
  } else {
    debugPrint("ℹ️ No items to update in batch.");
  }
}
