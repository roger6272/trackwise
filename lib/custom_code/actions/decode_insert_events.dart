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

Future<void> decodeInsertEvents(String message) async {
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

  // Convert single event to list for consistent processing
  final eventsList = data is List ? data : [data];

  final batch = FirebaseFirestore.instance.batch();
  int batchCount = 0;

  for (final eventData in eventsList) {
    try {
      //debugPrint("📥 Live event: " +
      //    eventData['event'].toString() +
      //    " from " +
      //    eventData['itemName'].toString());

      if (eventData['event'] == 'switch') {
        // For single events, update FFAppState
        if (eventsList.length == 1) {
          FFAppState().isactivated = eventData['itemId'];
        }

        final itemRef = FirebaseFirestore.instance
            .collection('Item')
            .doc(eventData['itemId']);
        batch.update(itemRef, {
          'lastUpdated': Timestamp.fromDate(
            DateTime.now().add(Duration(milliseconds: 1)),
          ),
        });
      } else {
        final itemRef =
            FirebaseFirestore.instance.doc("/Item/${eventData['itemId']}");
        final timestamp = eventData['timestamp'] ?? 0;

        // Debug: show what timestamp the device sent
        final dateFromDevice = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000, isUtc: true);
        debugPrint("📅 Event timestamp from device: $timestamp (UTC: $dateFromDevice, Local: ${dateFromDevice.toLocal()})");

        final event = eventData['event']?.toString() ?? 'unknown';
        final count = eventData['count'];
        final eventLogRef = FirebaseFirestore.instance
            .collection('EventLog')
            .doc('${itemRef.id}-$event-$timestamp-$count');
        batch.set(
            eventLogRef,
            {
              'created_time':
                  Timestamp.fromMillisecondsSinceEpoch(timestamp * 1000),
              'item': itemRef,
              'event_name': event,
              'increment': eventData['increment'],
              'currentcount': count,
              'uid': userRef,
              'id': '${itemRef.id}-$event-$timestamp-$count',
            },
            SetOptions(merge: true));
      }
      batchCount++;
    } catch (e) {
      debugPrint("❌ Error preparing event for batch: $e");
    }
  }

  try {
    if (batchCount > 0) {
      await batch.commit();
      debugPrint("✅ Batch committed for $batchCount events.");
    } else {
      debugPrint("ℹ️ No events to commit in batch.");
    }
  } catch (e) {
    debugPrint("❌ Firestore batch write failed: $e");
  }
}
