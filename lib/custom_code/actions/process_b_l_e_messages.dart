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

Future<void> processBLEMessages(BTDeviceStruct deviceInfo) async {
  final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  final userRef = FirebaseFirestore.instance.doc("/users/$uid");

  final deviceId = deviceInfo.id;
  final device = BluetoothDevice(remoteId: DeviceIdentifier(deviceId));
  final services = await device.discoverServices();

  for (var service in services) {
    for (var char in service.characteristics) {
      if (char.uuid.toString().toLowerCase() ==
          '12345678-1234-1234-1234-123456789002') {
        await char.setNotifyValue(
            true); // Handle Notify Messages passed through listener

        final bleChunkQueue = <String>[]; // Holds incoming BLE chunks
        bool isProcessing = false;
        String bleJsonBuffer = '';

        // ✅ Register the subscription in GetIt
        final subscription = char.lastValueStream.listen((value) async {
          final chunk = utf8.decode(value);
          bleChunkQueue.add(chunk); // Add the chunk to the queue
          //debugPrint("🧩 Queued BLE chunk: $chunk");

          if (isProcessing) return; // Already processing

          isProcessing = true;

          while (bleChunkQueue.isNotEmpty) {
            bleJsonBuffer += bleChunkQueue.removeAt(0); // Dequeue

            while (bleJsonBuffer.contains('\n')) {
              final lines = bleJsonBuffer.split('\n');
              final raw = lines.first;
              bleJsonBuffer =
                  lines.sublist(1).join('\n'); // retain any remaining chunks

              if (raw.trim().isEmpty) continue;
              if (!raw.trim().startsWith('{') && !raw.trim().startsWith('[')) {
                debugPrint("⚠️ Skipped non-JSON chunk: $raw");
                continue;
              }

              try {
                final jsonString =
                    raw; // raw is already a string, no need to decode
                dynamic parsed;
                parsed = jsonDecode(jsonString);

                final type = parsed['type'];

                if (type == 'prefs') {
                  decodeUpdateItemStatus(jsonString);
                } else if (type == 'event') {
                  decodeInsertEvents(jsonString);
                }
              } catch (e) {
                debugPrint("❌ Failed to decode BLE data: $raw");
                debugPrint("Error: $e");
                return;
              }
            }
          }
          isProcessing = false;
        });

        GetIt.instance
            .registerSingleton<StreamSubscription<List<int>>>(subscription);
        return;
      }
    }
  }
}
