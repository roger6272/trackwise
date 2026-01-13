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

Future<void> autoReconnectHandler(BTDeviceStruct deviceInfo) async {
  final deviceId = deviceInfo.id;
  final device = BluetoothDevice(remoteId: DeviceIdentifier(deviceId));

  //Listener set up to monitor connection state
  final connectionStateSub =
      device.connectionState.listen((BluetoothConnectionState state) async {
    if (state == BluetoothConnectionState.disconnected) {
      //if disconnected

      //check if it's intentional. If so, everything should be handled already in disconnectDevice function. do nothing.
      if (FFAppState().isManualDisconnect) {
        debugPrint("Manual disconnect: not auto-reconnecting.");
        return;
      }

      debugPrint("🚫 BLE device disconnected — cleaning up");
      FFAppState().deviceConnected = false;

      // Cancel and remove the BLE data listener
      if (GetIt.instance.isRegistered<StreamSubscription<List<int>>>()) {
        final sub = GetIt.instance.get<StreamSubscription<List<int>>>();
        await sub.cancel();
        try {
          GetIt.instance.unregister<StreamSubscription<List<int>>>();
        } catch (e) {
          debugPrint(
              "Tried to unregister BLE subscription, but it was not registered: $e");
        }
      }

      // Start scanning for the device
      StreamSubscription<List<ScanResult>>? scanSub;
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 5),
      );
      scanSub = FlutterBluePlus.scanResults.listen((results) async {
        for (final scanResult in results) {
          if (scanResult.device.remoteId.str == deviceId) {
            debugPrint("Found device, reconnecting...");
            await scanSub?.cancel();
            await FlutterBluePlus.stopScan();
            onConnectActions(deviceInfo);
            break;
          }
        }
      });
    }
  });
  GetIt.instance
      .registerSingleton<StreamSubscription<BluetoothConnectionState>>(
          connectionStateSub);
}
