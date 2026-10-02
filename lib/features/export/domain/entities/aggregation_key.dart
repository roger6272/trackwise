import 'package:equatable/equatable.dart';

/// Key for aggregating events by item, category, event type, and date.
/// Grouped by [itemId], not [itemName] — item names are not unique.
class AggregationKey extends Equatable {
  final String itemId;
  final String itemName;
  final String category;
  final String eventType;
  final DateTime date;

  const AggregationKey({
    required this.itemId,
    required this.itemName,
    required this.category,
    required this.eventType,
    required this.date,
  });

  @override
  List<Object?> get props => [itemId, category, eventType, date];
}
