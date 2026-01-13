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
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> resetTodayCountForAllItems() async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  final itemsCollection = FirebaseFirestore.instance.collection('Item');
  final snapshot = await itemsCollection.get();

  for (final doc in snapshot.docs) {
    final data = doc.data();
    final lastUpdated = (data['lastUpdated'] as Timestamp?)?.toDate();

    final needsReset = lastUpdated == null ||
        lastUpdated.year != today.year ||
        lastUpdated.month != today.month ||
        lastUpdated.day != today.day;

    if (needsReset) {
      await doc.reference.update({
        'todaycount': 0,
        'lastUpdated': Timestamp.fromDate(today),
      });
    }
  }
}
