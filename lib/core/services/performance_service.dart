import 'package:firebase_performance/firebase_performance.dart';
import 'package:injectable/injectable.dart';

/// Service for tracking performance metrics.
///
/// Wraps Firebase Performance Monitoring to provide custom traces
/// for key operations like Bluetooth connections and Firestore queries.
@lazySingleton
class PerformanceService {
  final FirebasePerformance _performance;

  PerformanceService(this._performance);

  /// Factory constructor for dependency injection
  @factoryMethod
  static PerformanceService create() {
    return PerformanceService(FirebasePerformance.instance);
  }

  // ==================== Bluetooth Traces ====================

  /// Trace Bluetooth connection operation
  Future<T> traceBluetoothConnection<T>(
    Future<T> Function() operation,
  ) async {
    final trace = _performance.newTrace('bluetooth_connection');
    await trace.start();

    try {
      final result = await operation();
      trace.putAttribute('status', 'success');
      await trace.stop();
      return result;
    } catch (e) {
      trace.putAttribute('status', 'error');
      trace.putAttribute('error_type', e.runtimeType.toString());
      await trace.stop();
      rethrow;
    }
  }

  /// Trace Bluetooth data transfer
  Future<T> traceBluetoothDataTransfer<T>(
    Future<T> Function() operation, {
    required int itemCount,
  }) async {
    final trace = _performance.newTrace('bluetooth_data_transfer');
    trace.setMetric('item_count', itemCount);
    await trace.start();

    try {
      final result = await operation();
      trace.putAttribute('status', 'success');
      await trace.stop();
      return result;
    } catch (e) {
      trace.putAttribute('status', 'error');
      await trace.stop();
      rethrow;
    }
  }

  // ==================== Firestore Traces ====================

  /// Trace Firestore query operation
  Future<T> traceFirestoreQuery<T>(
    String queryName,
    Future<T> Function() query,
  ) async {
    final trace = _performance.newTrace('firestore_$queryName');
    await trace.start();

    try {
      final result = await query();
      trace.putAttribute('status', 'success');
      await trace.stop();
      return result;
    } catch (e) {
      trace.putAttribute('status', 'error');
      trace.putAttribute('error_type', e.runtimeType.toString());
      await trace.stop();
      rethrow;
    }
  }

  /// Trace getting items from Firestore
  Future<T> traceGetItems<T>(Future<T> Function() query) async {
    return traceFirestoreQuery('get_items', query);
  }

  /// Trace getting events from Firestore
  Future<T> traceGetEvents<T>(Future<T> Function() query) async {
    return traceFirestoreQuery('get_events', query);
  }

  /// Trace getting profile from Firestore
  Future<T> traceGetProfile<T>(Future<T> Function() query) async {
    return traceFirestoreQuery('get_profile', query);
  }

  // ==================== Export Traces ====================

  /// Trace CSV generation
  Future<T> traceCsvGeneration<T>(
    Future<T> Function() operation, {
    required int eventCount,
  }) async {
    final trace = _performance.newTrace('csv_generation');
    trace.setMetric('event_count', eventCount);
    await trace.start();

    try {
      final result = await operation();
      trace.putAttribute('status', 'success');
      await trace.stop();
      return result;
    } catch (e) {
      trace.putAttribute('status', 'error');
      await trace.stop();
      rethrow;
    }
  }

  /// Trace JSON data export (GDPR)
  Future<T> traceDataExport<T>(Future<T> Function() operation) async {
    final trace = _performance.newTrace('data_export');
    await trace.start();

    try {
      final result = await operation();
      trace.putAttribute('status', 'success');
      await trace.stop();
      return result;
    } catch (e) {
      trace.putAttribute('status', 'error');
      await trace.stop();
      rethrow;
    }
  }

  // ==================== Auth Traces ====================

  /// Trace sign in operation
  Future<T> traceSignIn<T>(
    String method,
    Future<T> Function() operation,
  ) async {
    final trace = _performance.newTrace('sign_in');
    trace.putAttribute('method', method);
    await trace.start();

    try {
      final result = await operation();
      trace.putAttribute('status', 'success');
      await trace.stop();
      return result;
    } catch (e) {
      trace.putAttribute('status', 'error');
      await trace.stop();
      rethrow;
    }
  }

  /// Trace sign up operation
  Future<T> traceSignUp<T>(
    String method,
    Future<T> Function() operation,
  ) async {
    final trace = _performance.newTrace('sign_up');
    trace.putAttribute('method', method);
    await trace.start();

    try {
      final result = await operation();
      trace.putAttribute('status', 'success');
      await trace.stop();
      return result;
    } catch (e) {
      trace.putAttribute('status', 'error');
      await trace.stop();
      rethrow;
    }
  }

  // ==================== Generic Trace ====================

  /// Create a custom trace for any operation
  Future<T> trace<T>(
    String traceName,
    Future<T> Function() operation, {
    Map<String, String>? attributes,
    Map<String, int>? metrics,
  }) async {
    final trace = _performance.newTrace(traceName);

    // Add custom attributes
    attributes?.forEach((key, value) {
      trace.putAttribute(key, value);
    });

    // Add custom metrics
    metrics?.forEach((key, value) {
      trace.setMetric(key, value);
    });

    await trace.start();

    try {
      final result = await operation();
      trace.putAttribute('status', 'success');
      await trace.stop();
      return result;
    } catch (e) {
      trace.putAttribute('status', 'error');
      trace.putAttribute('error_type', e.runtimeType.toString());
      await trace.stop();
      rethrow;
    }
  }
}
