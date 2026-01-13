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

import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

Future<List<BTDeviceStruct>> findDevices() async {
  List<BTDeviceStruct> devices = [];
  try {
    // Request Bluetooth permissions for Android 12+ (API 31+)
    if (await Permission.bluetoothScan.isDenied) {
      await Permission.bluetoothScan.request();
    }
    if (await Permission.bluetoothConnect.isDenied) {
      await Permission.bluetoothConnect.request();
    }
    // Also request location permission (needed for BLE scanning on some devices)
    if (await Permission.locationWhenInUse.isDenied) {
      await Permission.locationWhenInUse.request();
    }

    // Check if permissions were granted
    if (await Permission.bluetoothScan.isDenied) {
      debugPrint('Bluetooth scan permission denied');
      return devices;
    }

    var subscription = FlutterBluePlus.scanResults.listen(
      (results) {
        print("update");
        List<ScanResult> scannedDevices = [];
        for (ScanResult r in results) {
          if (r.device.platformName.isNotEmpty) {
            scannedDevices.add(r);
          }
        }
        devices.clear();
        scannedDevices.forEach((deviceResult) {
          devices.add(BTDeviceStruct(
            name: deviceResult.device.platformName,
            id: deviceResult.device.remoteId.toString(),
            rssi: 0,
          ));
        });
      },
      onError: (e) => print(e),
    );
    // cleanup: cancel subscription when scanning stops
    //FlutterBluePlus.cancelWhenScanComplete(subscription);
    await FlutterBluePlus.adapterState
        .where((val) => val == BluetoothAdapterState.on)
        .first;
    await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 3), androidUsesFineLocation: true);

    // wait for scanning to stop
    await FlutterBluePlus.isScanning.where((val) => val == false).first;
  } catch (e) {
    debugPrint(e.toString());
  }
  return devices;
}
