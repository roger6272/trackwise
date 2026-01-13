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
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> dataExportPrep(
  DateTime startDate,
  DateTime endDate,
  String aggregationLevel, // "daily", "hourly", "weekly"
  String emailAddress,
) async {
  // Validate aggregation level
  if (!['Day', 'Hour', 'Week'].contains(aggregationLevel)) {
    throw Exception(
        "Invalid aggregation level. Must be 'Day', 'Hour', or 'Week'.");
  }

  // Validate date range
  if (startDate.isAfter(endDate)) {
    throw Exception("Start date must be before end date.");
  }

  final uid = FirebaseAuth.instance.currentUser?.uid;
  final userRef = FirebaseFirestore.instance.doc('users/$uid');

  final logsRef = FirebaseFirestore.instance
      .collection('EventLog')
      .where('uid', isEqualTo: userRef)
      .where('created_time',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
      .where('created_time', isLessThanOrEqualTo: Timestamp.fromDate(endDate));

  QuerySnapshot<Map<String, dynamic>> querySnapshot;

  try {
    querySnapshot = await logsRef.get();
    debugPrint("✅ Logs fetched: ${querySnapshot.size}");
  } catch (e, stack) {
    debugPrint("❌ Firestore read failed: $e");
    debugPrint("🧱 Stack trace: $stack");
    return; // Exit early so logs isn't undefined
  }

  final logs = querySnapshot.docs.map((doc) => doc.data()).toList();

  if (logs.isEmpty) {
    debugPrint("No logs found for export.");
    return;
  }

  // Collect all unique item references
  Set<DocumentReference> itemRefs = {};
  for (final log in logs) {
    final item = log['item'];
    if (item is DocumentReference) {
      itemRefs.add(item);
    }
  }

  // Fetch item names from Item collection
  Map<String, String> itemIdToName = {};
  for (final itemRef in itemRefs) {
    try {
      final itemDoc = await itemRef.get();
      if (itemDoc.exists) {
        final itemData = itemDoc.data() as Map<String, dynamic>?;
        final itemName = itemData?['item_name'] as String? ?? 'Unknown Item';
        itemIdToName[itemRef.id] = itemName;
      } else {
        itemIdToName[itemRef.id] = 'Deleted Item';
      }
    } catch (e) {
      debugPrint("❌ Error fetching item ${itemRef.id}: $e");
      itemIdToName[itemRef.id] = 'Error Loading Item';
    }
  }

  Map<String, Map<String, Map<String, int>>> groupedCounts = {};

  for (final log in logs) {
    final createdTime = log['created_time'];
    if (createdTime == null || createdTime is! Timestamp) {
      continue; // Skip invalid timestamps
    }

    final ts = createdTime.toDate().toLocal();
    final item = log['item'];
    final eventType = log['event_name'] as String?;
    final increment = (log['increment'] ?? 1) as num;

    // Get item identifier (ID or name)
    String itemIdentifier;
    if (item is DocumentReference) {
      itemIdentifier = itemIdToName[item.id] ?? 'Unknown Item';
    } else {
      itemIdentifier = item.toString();
    }

    if (eventType == null) {
      continue; // Skip logs without event type
    }

    String timeKey;

    switch (aggregationLevel) {
      case 'Hour':
        timeKey = DateFormat('yyyy-MM-dd HH:00').format(ts);
        break;
      case 'Week':
        try {
          // Calculate the Sunday of the current week
          // Find the most recent Sunday (weekday 7)
          final daysSinceSunday = ts.weekday == 7 ? 0 : ts.weekday;
          final sundayDate = ts.subtract(Duration(days: daysSinceSunday));
          timeKey = DateFormat('yyyy-MM-dd').format(sundayDate);
        } catch (e) {
          debugPrint('Error parsing weekly date: $e');
          continue; // Skip this log entry
        }
        break;
      case 'Day':
      default:
        timeKey = DateFormat('yyyy-MM-dd').format(ts);
        break;
    }

    groupedCounts.putIfAbsent(timeKey, () => {});
    groupedCounts[timeKey]!
        .putIfAbsent(itemIdentifier, () => {'increments': 0, 'resets': 0});

    if (eventType == 'increment') {
      groupedCounts[timeKey]![itemIdentifier]!['increments'] =
          (groupedCounts[timeKey]![itemIdentifier]!['increments'] ?? 0) +
              increment.toInt();
    } else if (eventType == 'reset') {
      groupedCounts[timeKey]![itemIdentifier]!['resets'] =
          (groupedCounts[timeKey]![itemIdentifier]!['resets'] ?? 0) + 1;
    }
  }

  // Convert to CSV
  final csvLines = ['Time Aggregation,Time,Item Name,Increments,Resets'];
  groupedCounts.forEach((time, itemsMap) {
    itemsMap.forEach((itemName, counts) {
      csvLines.add(
          '"$aggregationLevel",$time,"$itemName",${counts['increments']},${counts['resets']}');
    });
  });

  final csvContent = csvLines.join('\n');

  await sendEmailWithCSV(
      csvContent, emailAddress, startDate, endDate, aggregationLevel);
}
