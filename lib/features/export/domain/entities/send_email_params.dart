import 'package:equatable/equatable.dart';

import 'csv_export_config.dart';

/// Parameters for sending an email with CSV export.
class SendEmailParams extends Equatable {
  final String email;
  final DateTime startDate;
  final DateTime endDate;
  final ExportAggregationLevel aggregationLevel;
  final String? itemId;

  const SendEmailParams({
    required this.email,
    required this.startDate,
    required this.endDate,
    this.aggregationLevel = ExportAggregationLevel.daily,
    this.itemId,
  });

  @override
  List<Object?> get props => [email, startDate, endDate, aggregationLevel, itemId];

  /// Convert to CSVExportConfig for CSV generation.
  CSVExportConfig toCSVExportConfig() {
    return CSVExportConfig(
      startDate: startDate,
      endDate: endDate,
      aggregationLevel: aggregationLevel,
      itemId: itemId,
    );
  }
}
