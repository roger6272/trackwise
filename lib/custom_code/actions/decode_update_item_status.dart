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
  final selected_id = parsed['selected_id'];

  final existingSnapshot = await FirebaseFirestore.instance
      .collection('Item')
      .where('uid', isEqualTo: userRef)
      .get();

  final existingItemIDs =
      existingSnapshot.docs.map((doc) => doc.id).toSet(); //pulling id of items

  FFAppState().isactivated = selected_id; //update current selected_id

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
