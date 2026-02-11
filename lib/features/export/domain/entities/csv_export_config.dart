import 'package:equatable/equatable.dart';

/// Aggregation level for CSV export.
enum ExportAggregationLevel {
  raw,
  daily,
  byCycle,
}

/// Configuration for CSV export.
class CSVExportConfig extends Equatable {
  final DateTime startDate;
  final DateTime endDate;
  final ExportAggregationLevel aggregationLevel;
  final bool latestCycleOnly; // Only relevant when byCycle is selected
  final List<String>? itemIds; // Optional: export for specific items only

  const CSVExportConfig({
    required this.startDate,
    required this.endDate,
    this.aggregationLevel = ExportAggregationLevel.daily,
    this.latestCycleOnly = false,
    this.itemIds,
  });

  @override
  List<Object?> get props => [startDate, endDate, aggregationLevel, latestCycleOnly, itemIds];

  /// Generate filename for the CSV export.
  String get filename {
    final level = aggregationLevel == ExportAggregationLevel.byCycle ? 'by_cycle' : aggregationLevel.name;
    if (aggregationLevel == ExportAggregationLevel.byCycle && latestCycleOnly) {
      return 'tally_export_latest_cycle_$level.csv';
    }
    if (aggregationLevel == ExportAggregationLevel.byCycle) {
      return 'tally_export_$level.csv';
    }
    final start = _formatDate(startDate);
    final end = _formatDate(endDate);
    return 'tally_export_${start}_to_${end}_$level.csv';
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
