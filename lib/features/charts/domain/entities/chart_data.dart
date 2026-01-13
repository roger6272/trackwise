import 'package:equatable/equatable.dart';

import 'chart_data_point.dart';

/// Aggregation level for chart data.
///
/// Determines how events are grouped for display.
enum AggregationLevel {
  /// Group by day (start of each day)
  daily,

  /// Group by week (Monday of each week)
  weekly,

  /// Group by month (first of each month)
  monthly,
}

/// Extension to convert AggregationLevel to/from string.
extension AggregationLevelExtension on AggregationLevel {
  String get name {
    switch (this) {
      case AggregationLevel.daily:
        return 'daily';
      case AggregationLevel.weekly:
        return 'weekly';
      case AggregationLevel.monthly:
        return 'monthly';
    }
  }

  static AggregationLevel fromString(String value) {
    switch (value.toLowerCase()) {
      case 'daily':
        return AggregationLevel.daily;
      case 'weekly':
        return AggregationLevel.weekly;
      case 'monthly':
        return AggregationLevel.monthly;
      default:
        return AggregationLevel.daily;
    }
  }
}

/// Chart data containing aggregated data points.
///
/// Used by the Charts BLoC to provide data for bar charts and line charts.
/// Contains a list of data points and the aggregation level used.
///
/// Example:
/// ```dart
/// final chartData = ChartData(
///   dataPoints: [
///     ChartDataPoint(date: DateTime(2024, 1, 1), value: 10),
///     ChartDataPoint(date: DateTime(2024, 1, 2), value: 15),
///   ],
///   aggregationLevel: AggregationLevel.daily,
/// );
/// print('Total: ${chartData.totalValue}'); // 25
/// ```
class ChartData extends Equatable {
  /// List of data points sorted by date (ascending).
  final List<ChartDataPoint> dataPoints;

  /// The aggregation level used (daily, weekly, monthly).
  final AggregationLevel aggregationLevel;

  const ChartData({
    required this.dataPoints,
    required this.aggregationLevel,
  });

  @override
  List<Object?> get props => [dataPoints, aggregationLevel];

  /// Total value across all data points.
  int get totalValue => dataPoints.fold(0, (sum, point) => sum + point.value);

  /// Number of data points.
  int get count => dataPoints.length;

  /// Whether this chart has any data.
  bool get isEmpty => dataPoints.isEmpty;

  /// Whether this chart has data.
  bool get isNotEmpty => dataPoints.isNotEmpty;

  /// Maximum value across all data points.
  ///
  /// Returns 0 if no data points exist.
  int get maxValue {
    if (dataPoints.isEmpty) return 0;
    return dataPoints.map((p) => p.value).reduce((a, b) => a > b ? a : b);
  }

  /// Minimum value across all data points.
  ///
  /// Returns 0 if no data points exist.
  int get minValue {
    if (dataPoints.isEmpty) return 0;
    return dataPoints.map((p) => p.value).reduce((a, b) => a < b ? a : b);
  }

  /// Average value across all data points.
  ///
  /// Returns 0 if no data points exist.
  double get averageValue {
    if (dataPoints.isEmpty) return 0;
    return totalValue / dataPoints.length;
  }

  /// Create empty chart data.
  static ChartData empty({
    AggregationLevel aggregationLevel = AggregationLevel.daily,
  }) {
    return ChartData(
      dataPoints: const [],
      aggregationLevel: aggregationLevel,
    );
  }
}
