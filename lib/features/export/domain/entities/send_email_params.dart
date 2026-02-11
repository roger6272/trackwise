import 'package:equatable/equatable.dart';

import 'csv_export_config.dart';

/// Parameters for sending an email with CSV export.
class SendEmailParams extends Equatable {
  final String email;
  final DateTime startDate;
  final DateTime endDate;
  final ExportAggregationLevel aggregationLevel;
  final bool latestCycleOnly;
  final List<String>? itemIds;

  const SendEmailParams({
    required this.email,
    required this.startDate,
    required this.endDate,
    this.aggregationLevel = ExportAggregationLevel.daily,
    this.latestCycleOnly = false,
    this.itemIds,
  });

  @override
  List<Object?> get props => [email, startDate, endDate, aggregationLevel, latestCycleOnly, itemIds];

  /// Convert to CSVExportConfig for CSV generation.
  CSVExportConfig toCSVExportConfig() {
    return CSVExportConfig(
      startDate: startDate,
      endDate: endDate,
      aggregationLevel: aggregationLevel,
      latestCycleOnly: latestCycleOnly,
      itemIds: itemIds,
    );
  }
}
