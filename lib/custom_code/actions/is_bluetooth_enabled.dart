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

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

Future<bool> isBluetoothEnabled() async {
  await Future.delayed(const Duration(milliseconds: 100));
  if (await FlutterBluePlus.isSupported == false) {
    print("Bluetooth not supported by this device");
    return false;
  }
  bool returnme = false;
  var subscription =
      FlutterBluePlus.adapterState.listen((BluetoothAdapterState state) {
    print(state);
    if (state == BluetoothAdapterState.on) {
      // usually start scanning, connecting, etc
      returnme = true;
    } else {
      // show an error to the user, etc
      returnme = false;
    }
  });
  await Future.delayed(const Duration(milliseconds: 100));

  subscription.cancel();

  return returnme;
}
