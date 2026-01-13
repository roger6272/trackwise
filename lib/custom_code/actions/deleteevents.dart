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

import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> deleteevents(
  List<EventLogRecord>? eventLog,
  DocumentReference? itemRef,
) async {
  if (eventLog == null || itemRef == null) {
    //print('No events or item reference provided.');
    return;
  }

  // Create a batch to perform multiple deletes
  WriteBatch batch = FirebaseFirestore.instance.batch();

  // Iterate through the list of event logs
  for (var event in eventLog) {
    // Check if the event's document reference matches the item reference
    if (event.item == itemRef) {
      // Add the delete operation to the batch
      batch.delete(event.reference);
    }
  }

  // Commit the batch
  await batch.commit();
}
