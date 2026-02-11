import 'package:equatable/equatable.dart';

/// Aggregation level for CSV export.
enum ExportAggregationLevel {
  raw,
  daily,
}

/// Data scope for CSV export.
enum ExportDataScope {
  /// Export all data within date range
  total,
  /// Export only data from the latest reset cycle
  latestCycle,
}

/// Configuration for CSV export.
class CSVExportConfig extends Equatable {
  final DateTime startDate;
  final DateTime endDate;
  final ExportAggregationLevel aggregationLevel;
  final ExportDataScope dataScope;
  final List<String>? itemIds; // Optional: export for specific items only

  const CSVExportConfig({
    required this.startDate,
    required this.endDate,
    this.aggregationLevel = ExportAggregationLevel.daily,
    this.dataScope = ExportDataScope.total,
    this.itemIds,
  });

  @override
  List<Object?> get props => [startDate, endDate, aggregationLevel, dataScope, itemIds];

  /// Generate filename for the CSV export.
  String get filename {
    final level = aggregationLevel.name;
    if (dataScope == ExportDataScope.latestCycle) {
      return 'tally_export_latest_cycle_$level.csv';
    }
    final start = _formatDate(startDate);
    final end = _formatDate(endDate);
    return 'tally_export_${start}_to_${end}_$level.csv';
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
