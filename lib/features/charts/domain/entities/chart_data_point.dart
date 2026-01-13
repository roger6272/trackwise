import 'package:equatable/equatable.dart';

/// A single data point for a chart.
///
/// Represents one bar or point in a bar chart or line chart.
/// Contains a date and a value (typically sum of increments for that period).
///
/// Example:
/// ```dart
/// final point = ChartDataPoint(
///   date: DateTime(2024, 1, 15),
///   value: 42,
/// );
/// ```
class ChartDataPoint extends Equatable {
  /// The date/time for this data point.
  ///
  /// For daily aggregation: start of day
  /// For weekly aggregation: Monday of the week
  /// For monthly aggregation: first of the month
  final DateTime date;

  /// The aggregated value for this data point.
  ///
  /// Typically the sum of event increments for the time period.
  final int value;

  const ChartDataPoint({
    required this.date,
    required this.value,
  });

  @override
  List<Object?> get props => [date, value];

  /// Create a copy with updated fields.
  ChartDataPoint copyWith({
    DateTime? date,
    int? value,
  }) {
    return ChartDataPoint(
      date: date ?? this.date,
      value: value ?? this.value,
    );
  }
}
