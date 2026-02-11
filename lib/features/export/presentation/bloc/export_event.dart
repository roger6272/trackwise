import 'package:equatable/equatable.dart';

import '../../domain/entities/csv_export_config.dart';

/// Base event class for Export BLoC.
abstract class ExportEvent extends Equatable {
  const ExportEvent();

  @override
  List<Object?> get props => [];
}

/// Event to trigger CSV export via email.
///
/// Generates CSV from events in the date range with the specified
/// aggregation level and sends it to the provided email address.
class ExportCSV extends ExportEvent {
  final DateTime startDate;
  final DateTime endDate;
  final ExportAggregationLevel aggregationLevel;
  final ExportDataScope dataScope;
  final String email;
  final List<String>? itemIds;

  const ExportCSV({
    required this.startDate,
    required this.endDate,
    required this.aggregationLevel,
    this.dataScope = ExportDataScope.total,
    required this.email,
    this.itemIds,
  });

  @override
  List<Object?> get props => [startDate, endDate, aggregationLevel, dataScope, email, itemIds];
}

/// Event to reset the export state.
class ResetExport extends ExportEvent {
  const ResetExport();
}
