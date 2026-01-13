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
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import 'package:get_it/get_it.dart';

Future<void> disconnectDevice(String deviceId) async {
  // Cancel and remove BLE listener if registered
  if (GetIt.instance.isRegistered<StreamSubscription<List<int>>>()) {
    final sub = GetIt.instance<StreamSubscription<List<int>>>();
    await sub.cancel();
    GetIt.instance.unregister<StreamSubscription<List<int>>>();
    FFAppState().isManualDisconnect = true;
    debugPrint("🔕 BLE listener cancelled");
  }

  try {
    final connectedDevices = FlutterBluePlus.connectedDevices;
    final device = connectedDevices.firstWhere(
      (d) => d.remoteId.str == deviceId,
      orElse: () => throw Exception("Device not connected"),
    );
    await device.disconnect();

    FlutterBluePlus
        .stopScan(); // 🛑 Stops auto-connecting if scanning continues

    print("🔌 Disconnected from device: $deviceId");
  } catch (e) {
    print("❌ Failed to disconnect: $e");
  }
}
