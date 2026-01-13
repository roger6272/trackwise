import 'package:equatable/equatable.dart';

/// Aggregation level for CSV export.
enum ExportAggregationLevel {
  raw,
  daily,
  weekly,
  monthly,
}

/// Configuration for CSV export.
class CSVExportConfig extends Equatable {
  final DateTime startDate;
  final DateTime endDate;
  final ExportAggregationLevel aggregationLevel;
  final String? itemId; // Optional: export for specific item only

  const CSVExportConfig({
    required this.startDate,
    required this.endDate,
    this.aggregationLevel = ExportAggregationLevel.daily,
    this.itemId,
  });

  @override
  List<Object?> get props => [startDate, endDate, aggregationLevel, itemId];

  /// Generate filename for the CSV export.
  String get filename {
    final start = _formatDate(startDate);
    final end = _formatDate(endDate);
    final level = aggregationLevel.name;
    return 'tally_export_${start}_to_${end}_$level.csv';
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
