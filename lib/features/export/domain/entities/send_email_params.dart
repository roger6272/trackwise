import 'package:equatable/equatable.dart';

import 'csv_export_config.dart';

/// Parameters for sending an email with CSV export.
class SendEmailParams extends Equatable {
  final String email;
  final DateTime startDate;
  final DateTime endDate;
  final ExportAggregationLevel aggregationLevel;
  final ExportDataScope dataScope;
  final List<String>? itemIds;

  const SendEmailParams({
    required this.email,
    required this.startDate,
    required this.endDate,
    this.aggregationLevel = ExportAggregationLevel.daily,
    this.dataScope = ExportDataScope.total,
    this.itemIds,
  });

  @override
  List<Object?> get props => [email, startDate, endDate, aggregationLevel, dataScope, itemIds];

  /// Convert to CSVExportConfig for CSV generation.
  CSVExportConfig toCSVExportConfig() {
    return CSVExportConfig(
      startDate: startDate,
      endDate: endDate,
      aggregationLevel: aggregationLevel,
      dataScope: dataScope,
      itemIds: itemIds,
    );
  }
}
