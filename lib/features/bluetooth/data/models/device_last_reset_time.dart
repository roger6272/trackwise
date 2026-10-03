import '../../../items/domain/entities/item.dart';

/// The `lastResetTime` (UTC seconds) to send the device for [item].
///
/// Normally the stored value, or 0 when the item has never been reset.
/// Exception: a never-reset item created or edited today is sent today's
/// local midnight. The nRF build treats 0 as "last reset on an earlier day"
/// and zeroes `todaycount` on its next wake, losing today's counts
/// (BLE_PROTOCOL.md §0). Midnight is the value it writes itself after a
/// daily reset, so Firestore and the UI end up exactly as they would anyway.
int deviceLastResetTimeSeconds(Item item, {DateTime? now}) {
  final stored = item.lastResetTime;
  if (stored != null) return stored.toUtc().millisecondsSinceEpoch ~/ 1000;

  final today = now ?? DateTime.now();
  final midnight = DateTime(today.year, today.month, today.day);
  if (item.lastUpdated.isBefore(midnight)) return 0;
  return midnight.toUtc().millisecondsSinceEpoch ~/ 1000;
}
