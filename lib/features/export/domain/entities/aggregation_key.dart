import 'package:equatable/equatable.dart';

/// Key for aggregating events by item, category, event type, and date.
class AggregationKey extends Equatable {
  final String itemName;
  final String category;
  final String eventType;
  final DateTime date;

  const AggregationKey({
    required this.itemName,
    required this.category,
    required this.eventType,
    required this.date,
  });

  @override
  List<Object?> get props => [itemName, category, eventType, date];
}
