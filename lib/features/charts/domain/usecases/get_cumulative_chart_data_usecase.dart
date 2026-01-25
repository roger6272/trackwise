import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../events/domain/entities/event_log.dart';
import '../../../events/domain/repositories/event_log_repository.dart';
import '../../../items/domain/repositories/item_repository.dart';
import '../entities/chart_data.dart';
import '../entities/chart_data_point.dart';
import 'get_chart_data_usecase.dart';

/// Use case for generating cumulative (running total) chart data.
///
/// Fetches events and calculates a running total, showing the cumulative
/// sum of increments over time. Always uses daily aggregation.
///
/// Useful for showing growth trends and total progress over a period.
///
/// Example:
/// ```dart
/// final result = await getCumulativeChartDataUseCase(
///   GetChartDataParams(
///     startDate: DateTime(2024, 1, 1),
///     endDate: DateTime(2024, 1, 31),
///   ),
/// );
/// result.fold(
///   (failure) => print('Error: ${failure.message}'),
///   (chartData) {
///     // Last point shows total accumulated value
///     print('Total: ${chartData.dataPoints.last.value}');
///   },
/// );
/// ```
@lazySingleton
class GetCumulativeChartDataUseCase
    extends UseCase<ChartData, GetChartDataParams> {
  final EventLogRepository repository;
  final ItemRepository itemRepository;

  GetCumulativeChartDataUseCase(this.repository, this.itemRepository);

  @override
  Future<Either<Failure, ChartData>> call(GetChartDataParams params) async {
    // Fetch item's initialCount and creation date if itemId is provided
    int initialCount = 0;
    DateTime? createdAt;
    if (params.itemId != null) {
      final itemResult = await itemRepository.getItem(params.itemId!);
      itemResult.fold(
        (failure) {
          // Silently use 0 if item fetch fails
        },
        (item) {
          initialCount = item.initialCount;
          // Use lastUpdated as fallback for creation date
          // (it equals creation time for new items)
          createdAt = item.lastUpdated;
        },
      );
    }

    // Fetch events based on filters
    final Either<Failure, List<EventLog>> eventsResult;

    if (params.itemId != null) {
      // Use item + date range filter for charts
      eventsResult = await repository.getEventsByItemAndDateRange(
        params.itemId!,
        params.startDate,
        params.endDate,
      );
    } else {
      eventsResult = await repository.getEventsByDateRange(
        params.startDate,
        params.endDate,
      );
    }

    return eventsResult.fold(
      (failure) => Left(failure),
      (events) {
        // Try to get more accurate createdAt from "created" event
        final createdEvent = events.where((e) => e.eventName == 'created').firstOrNull;
        if (createdEvent != null) {
          createdAt = createdEvent.createdTime;
        }

        // Filter events by interval boundaries [start, end) - inclusive start, exclusive end
        var filteredEvents = events;
        if (params.sinceResetTime != null) {
          filteredEvents = filteredEvents
              .where((e) => !e.createdTime.isBefore(params.sinceResetTime!))
              .toList();
        }
        if (params.untilResetTime != null) {
          filteredEvents = filteredEvents
              .where((e) => e.createdTime.isBefore(params.untilResetTime!))
              .toList();
        }

        final cumulative = _calculateCumulative(filteredEvents, params.aggregationLevel);
        return Right(ChartData(
          dataPoints: cumulative,
          aggregationLevel: params.aggregationLevel,
          initialCount: initialCount,
          createdAt: createdAt,
        ));
      },
    );
  }

  /// Calculate cumulative totals by the specified aggregation level.
  ///
  /// First aggregates events by the time bucket, then calculates running total.
  /// Excludes 'reset' and 'created' events to only count actual increments.
  List<ChartDataPoint> _calculateCumulative(
    List<EventLog> events,
    AggregationLevel aggregationLevel,
  ) {
    if (events.isEmpty) return [];

    // Sort events by date ascending
    final sorted = List<EventLog>.from(events)
      ..sort((a, b) => a.createdTime.compareTo(b.createdTime));

    // First, aggregate by time bucket (excluding reset/created events)
    final Map<DateTime, int> bucketTotals = {};
    for (var event in sorted) {
      // Skip reset/created events - only count actual increments
      if (event.eventName == 'reset' || event.eventName == 'created') continue;
      final key = _getAggregationKey(event.createdTime, aggregationLevel);
      bucketTotals[key] = (bucketTotals[key] ?? 0) + event.increment;
    }

    // Then calculate cumulative values
    final sortedBuckets = bucketTotals.keys.toList()..sort();
    final List<ChartDataPoint> cumulative = [];
    var runningTotal = 0;

    for (var date in sortedBuckets) {
      runningTotal += bucketTotals[date]!;
      cumulative.add(ChartDataPoint(date: date, value: runningTotal));
    }

    return cumulative;
  }

  /// Get the aggregation key for a date based on the level.
  DateTime _getAggregationKey(DateTime date, AggregationLevel level) {
    switch (level) {
      case AggregationLevel.hourly:
        return DateTime(date.year, date.month, date.day, date.hour);
      case AggregationLevel.daily:
        return DateTime(date.year, date.month, date.day);
      case AggregationLevel.weekly:
        final weekday = date.weekday;
        return DateTime(date.year, date.month, date.day - (weekday - 1));
      case AggregationLevel.monthly:
        return DateTime(date.year, date.month);
    }
  }
}
