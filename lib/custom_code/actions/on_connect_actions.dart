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
import 'dart:async';
import 'package:get_it/get_it.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> onConnectActions(BTDeviceStruct deviceInfo) async {
  final deviceId = deviceInfo.id;
  int currentpage = FFAppState().currentLogPage;

  //UPDATE APP STATE
  FFAppState().deviceConnected = true;
  FFAppState().isManualDisconnect = false;

  //CONNECT
  await connectDevice(deviceInfo);

  //SUBSCRIBE TO NOTIFICATIONS / INDICATIONS
  await startListeningToBLEEvents(deviceInfo);

  //SYNC CLOCK
  await sendCurrentTimeToDevice(deviceId);

  //PULL ITEM PREFS  (uses “prepare_read” style characteristic)
  await prepareBLERead(deviceId, "prefs", currentpage);

  //PULL EVENT LOGS  (second call with a different key)
  await prepareBLERead(deviceId, "logs", currentpage);

  return;
}
