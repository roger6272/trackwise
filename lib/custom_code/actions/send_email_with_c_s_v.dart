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
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> sendEmailWithCSV(
  String csvContent,
  String emailAddress,
  DateTime startDate,
  DateTime endDate,
  String aggregationLevel,
) async {
  final base64Csv = base64Encode(utf8.encode(csvContent));

  // Format dates for filename
  final startDateStr =
      '${startDate.year}${startDate.month.toString().padLeft(2, '0')}${startDate.day.toString().padLeft(2, '0')}';
  final endDateStr =
      '${endDate.year}${endDate.month.toString().padLeft(2, '0')}${endDate.day.toString().padLeft(2, '0')}';
  final filename =
      'tally_export_${startDateStr}_to_${endDateStr}_${aggregationLevel}.csv';

  await FirebaseFirestore.instance.collection('mail').add({
    'to': [emailAddress],
    'message': {
      'subject': 'Your tally export CSV',
      'text': 'Please find your data attached.',
      'attachments': [
        {
          'filename': filename,
          'type': 'text/csv',
          'content': base64Csv,
        }
      ]
    }
  });
}
