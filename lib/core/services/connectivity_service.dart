import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:injectable/injectable.dart';
import '../utils/logger.dart';

/// Service for checking internet connectivity.
///
/// Used by sync operations to verify internet is available before
/// attempting Firestore operations. Combines network interface check
/// with actual connectivity verification.
abstract class ConnectivityService {
  /// Checks if device has an active internet connection.
  ///
  /// Returns true if:
  /// 1. Device has WiFi, mobile, or ethernet connection
  /// 2. Can reach a known host (google.com)
  ///
  /// Returns false if no network interface or lookup fails.
  Future<bool> hasInternetConnection();

  /// Watches connectivity changes.
  ///
  /// Emits true when connection becomes available,
  /// false when connection is lost.
  Stream<bool> watchConnectivity();
}

/// Implementation of [ConnectivityService] using connectivity_plus
/// and DNS lookup for verification.
@LazySingleton(as: ConnectivityService)
class ConnectivityServiceImpl implements ConnectivityService {
  final Connectivity _connectivity;

  ConnectivityServiceImpl({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  @override
  Future<bool> hasInternetConnection() async {
    try {
      // First check if we have a network interface
      final connectivityResult = await _connectivity.checkConnectivity();

      // connectivity_plus returns a list of results
      final hasNetworkInterface = connectivityResult.any((result) =>
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.mobile ||
          result == ConnectivityResult.ethernet);

      if (!hasNetworkInterface) {
        AppLogger.debug('ConnectivityService: No network interface available');
        return false;
      }

      // Then verify we can actually reach the internet
      // Using DNS lookup as it's faster than HTTP request
      final result = await InternetAddress.lookup('google.com');
      final hasInternet = result.isNotEmpty && result[0].rawAddress.isNotEmpty;

      AppLogger.debug('ConnectivityService: hasInternet=$hasInternet');
      return hasInternet;
    } on SocketException catch (e) {
      AppLogger.debug('ConnectivityService: SocketException - ${e.message}');
      return false;
    } catch (e) {
      AppLogger.debug('ConnectivityService: Error checking connectivity - $e');
      return false;
    }
  }

  @override
  Stream<bool> watchConnectivity() {
    return _connectivity.onConnectivityChanged.asyncMap((results) async {
      // Check if any result indicates network is available
      final hasNetworkInterface = results.any((result) =>
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.mobile ||
          result == ConnectivityResult.ethernet);

      if (!hasNetworkInterface) {
        return false;
      }

      // Verify actual connectivity
      return await hasInternetConnection();
    });
  }
}
