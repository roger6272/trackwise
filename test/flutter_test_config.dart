import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Global test configuration for all tests.
///
/// This file is automatically loaded by the Flutter test framework
/// before running any tests in the test/ directory.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Disable google_fonts HTTP fetching during tests
  GoogleFonts.config.allowRuntimeFetching = false;

  // Mock the asset loading to return empty manifest for google_fonts
  ServicesBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
    'flutter/assets',
    (ByteData? message) async {
      // Decode the asset key from the message
      final String key = utf8.decode(message!.buffer.asUint8List());

      // Return empty JSON manifest for AssetManifest requests
      if (key == 'AssetManifest.json' || key == 'AssetManifest.bin') {
        return ByteData.view(Uint8List.fromList(utf8.encode('{}')).buffer);
      }

      // Return null for other assets (will trigger fallback behavior)
      return null;
    },
  );

  await testMain();
}
