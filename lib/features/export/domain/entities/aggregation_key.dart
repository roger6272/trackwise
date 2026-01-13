import 'package:equatable/equatable.dart';

/// Key for aggregating events by item and date.
class AggregationKey extends Equatable {
  final String itemName;
  final DateTime date;

  const AggregationKey({
    required this.itemName,
    required this.date,
  });

  @override
  List<Object?> get props => [itemName, date];
}
