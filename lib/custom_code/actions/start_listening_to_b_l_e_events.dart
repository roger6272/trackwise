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

Future<void> startListeningToBLEEvents(BTDeviceStruct deviceInfo) async {
  final deviceId = deviceInfo.id;

  // Avoid duplicate listeners
  if (GetIt.instance.isRegistered<StreamSubscription<List<int>>>()) {
    debugPrint("🔁 BLE listener already exists — skipping");
    return;
  }

  // Flag to prevent recursive calls during reconnection
  FFAppState().isReconnecting = false;

  //get device info
  final device = BluetoothDevice(remoteId: DeviceIdentifier(deviceId));

  // Check if the device is connected. Connect first if not
  final currentState = await device.connectionState.first;
  if (currentState != BluetoothConnectionState.connected &&
      !FFAppState().isReconnecting) {
    //await device.connect(timeout: const Duration(seconds: 5));
    onConnectActions(deviceInfo);
  } else {
    debugPrint("✅ Device already connected, skipping connect");
  }

  //Cancel "connection state" listener with GetIt if existed
  if (GetIt.instance
      .isRegistered<StreamSubscription<BluetoothConnectionState>>()) {
    final oldConnSub =
        GetIt.instance.get<StreamSubscription<BluetoothConnectionState>>();
    await oldConnSub.cancel();
    try {
      GetIt.instance.unregister<StreamSubscription<BluetoothConnectionState>>();
    } catch (e) {
      debugPrint(
          "Tried to unregister connection state subscription, but it was not registered: $e");
    }
  }

///////////////////
  autoReconnectHandler(deviceInfo);

//////////////////
  processBLEMessages(deviceInfo);

  debugPrint("❌ CHAR_COUNT_NOTIFY_UUID not found");
}
