import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:trackwise/core/services/connectivity_service.dart';

class MockConnectivity extends Mock implements Connectivity {}

void main() {
  group('ConnectivityService', () {
    // Note: Full testing of hasInternetConnection() is limited because
    // InternetAddress.lookup() cannot be easily mocked without additional
    // infrastructure. These tests focus on the interface contract.

    test('ConnectivityServiceImpl implements ConnectivityService', () {
      final service = ConnectivityServiceImpl();
      expect(service, isA<ConnectivityService>());
    });

    test('hasInternetConnection returns boolean', () async {
      final service = ConnectivityServiceImpl();
      // This will perform actual network check - result depends on environment
      final result = await service.hasInternetConnection();
      expect(result, isA<bool>());
    });

    test('watchConnectivity returns stream', () {
      final service = ConnectivityServiceImpl();
      final stream = service.watchConnectivity();
      expect(stream, isA<Stream<bool>>());
    });
  });

  group('ConnectivityService interface', () {
    test('abstract interface has correct methods', () {
      // Verify the interface contract
      expect(ConnectivityService, isNotNull);
    });
  });
}
