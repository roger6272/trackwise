/// Events feature exports.
///
/// The events feature handles:
/// - Event logging from ESP32 Bluetooth device
/// - Storing events in Firestore
/// - Querying events for analytics and charts
/// - Batch insert operations for performance
library events;

export 'domain/domain.dart';
export 'data/data.dart';
export 'presentation/presentation.dart';
