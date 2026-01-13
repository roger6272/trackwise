import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import 'package:trackwise/core/error/failures.dart';
import 'package:trackwise/core/usecases/usecase.dart';
import 'package:trackwise/features/events/domain/entities/event_log.dart';
import 'package:trackwise/features/events/domain/repositories/event_log_repository.dart';
import 'package:trackwise/features/export/domain/entities/aggregation_key.dart';
import 'package:trackwise/features/export/domain/entities/csv_export_config.dart';

/// Use case for generating CSV from event data.
@injectable
class GenerateCSVUseCase implements UseCase<String, CSVExportConfig> {
  final EventLogRepository repository;

  GenerateCSVUseCase(this.repository);

  @override
  Future<Either<Failure, String>> call(CSVExportConfig params) async {
    // Get events from repository
    final Either<Failure, List<EventLog>> eventsResult;

    if (params.itemId != null) {
      eventsResult = await repository.getEventsByItem(params.itemId!);
    } else {
      eventsResult = await repository.getEventsByDateRange(
        params.startDate,
        params.endDate,
      );
    }

    return eventsResult.fold(
      (failure) => Left(failure),
      (events) {
        // Filter events by date range if we fetched by item
        final filteredEvents = params.itemId != null
            ? events
                .where((e) =>
                    !e.createdTime.isBefore(params.startDate) &&
                    !e.createdTime.isAfter(params.endDate))
                .toList()
            : events;

        final csv = _generateCSV(filteredEvents, params.aggregationLevel);
        return Right(csv);
      },
    );
  }

  /// Generate CSV string from events.
  String _generateCSV(
    List<EventLog> events,
    ExportAggregationLevel aggregationLevel,
  ) {
    final buffer = StringBuffer();

    // Header row
    buffer.writeln('Item Name,Date,Event Count');

    if (events.isEmpty) {
      return buffer.toString();
    }

    if (aggregationLevel == ExportAggregationLevel.raw) {
      // Raw events - one row per event
      for (final event in events) {
        buffer.writeln(
          '${_escapeCSV(event.eventName)},${_formatDate(event.createdTime)},${event.increment}',
        );
      }
    } else {
      // Aggregated events
      final aggregated = _aggregateEvents(events, aggregationLevel);

      // Sort by item name, then by date
      final sortedKeys = aggregated.keys.toList()
        ..sort((a, b) {
          final nameCompare = a.itemName.compareTo(b.itemName);
          if (nameCompare != 0) return nameCompare;
          return a.date.compareTo(b.date);
        });

      for (final key in sortedKeys) {
        buffer.writeln(
          '${_escapeCSV(key.itemName)},${_formatDate(key.date)},${aggregated[key]}',
        );
      }
    }

    return buffer.toString();
  }

  /// Aggregate events by the specified level.
  Map<AggregationKey, int> _aggregateEvents(
    List<EventLog> events,
    ExportAggregationLevel level,
  ) {
    final Map<AggregationKey, int> aggregated = {};

    for (final event in events) {
      final key = AggregationKey(
        itemName: event.eventName,
        date: _getAggregationDate(event.createdTime, level),
      );
      aggregated[key] = (aggregated[key] ?? 0) + event.increment;
    }

    return aggregated;
  }

  /// Get the aggregation date based on level.
  DateTime _getAggregationDate(DateTime date, ExportAggregationLevel level) {
    switch (level) {
      case ExportAggregationLevel.raw:
        return date;
      case ExportAggregationLevel.daily:
        return DateTime(date.year, date.month, date.day);
      case ExportAggregationLevel.weekly:
        // Start of week (Monday)
        final weekday = date.weekday;
        return DateTime(date.year, date.month, date.day - (weekday - 1));
      case ExportAggregationLevel.monthly:
        return DateTime(date.year, date.month);
    }
  }

  /// Format date as YYYY-MM-DD.
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Escape CSV value - wrap in quotes if contains comma, newline, or quote.
  String _escapeCSV(String value) {
    if (value.contains(',') || value.contains('\n') || value.contains('"')) {
      // Escape double quotes by doubling them
      final escaped = value.replaceAll('"', '""');
      return '"$escaped"';
    }
    return value;
  }
}
