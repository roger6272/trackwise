import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../events/domain/entities/event_log.dart';
import '../../../events/domain/repositories/event_log_repository.dart';
import '../../../items/domain/repositories/item_repository.dart';
import '../entities/chart_data.dart';
import '../entities/chart_data_point.dart';

/// Parameters for GetChartDataUseCase.
///
/// Contains date range and aggregation level for chart generation.
class GetChartDataParams extends Equatable {
  final DateTime startDate;
  final DateTime endDate;
  final AggregationLevel aggregationLevel;

  /// Optional item ID to filter events by a specific item.
  final String? itemId;

  /// Optional time to filter events after (for interval start time).
  final DateTime? sinceResetTime;

  /// Optional time to filter events before (for interval end time).
  final DateTime? untilResetTime;

  /// Whether viewing first cycle (All Time or Period 0).
  /// Initial count is only included in charts for the first cycle.
  final bool isFirstCycle;

  /// Optional reset number to filter events by cycle.
  /// When null or negative, no cycle filtering is applied (All Time view).
  final int? resetNumber;

  const GetChartDataParams({
    required this.startDate,
    required this.endDate,
    this.aggregationLevel = AggregationLevel.daily,
    this.itemId,
    this.sinceResetTime,
    this.untilResetTime,
    this.isFirstCycle = true,
    this.resetNumber,
  });

  @override
  List<Object?> get props => [startDate, endDate, aggregationLevel, itemId, sinceResetTime, untilResetTime, isFirstCycle, resetNumber];
}

/// Use case for generating aggregated chart data from events.
///
/// Fetches events from the repository and aggregates them by the specified
/// level (daily, weekly, or monthly). Returns sorted chart data points.
///
/// Example:
/// ```dart
/// final result = await getChartDataUseCase(
///   GetChartDataParams(
///     startDate: DateTime(2024, 1, 1),
///     endDate: DateTime(2024, 1, 31),
///     aggregationLevel: AggregationLevel.daily,
///   ),
/// );
/// result.fold(
///   (failure) => print('Error: ${failure.message}'),
///   (chartData) => print('Generated ${chartData.count} data points'),
/// );
/// ```
@lazySingleton
class GetChartDataUseCase extends UseCase<ChartData, GetChartDataParams> {
  final EventLogRepository repository;
  final ItemRepository itemRepository;

  GetChartDataUseCase(this.repository, this.itemRepository);

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

        // Filter by reset number to ensure only events from the selected cycle
        if (params.resetNumber != null && params.resetNumber! >= 0) {
          filteredEvents = filteredEvents
              .where((e) => e.resetNumber == params.resetNumber)
              .toList();
        }

        final aggregated = _aggregateEvents(filteredEvents, params.aggregationLevel);
        return Right(ChartData(
          dataPoints: aggregated,
          aggregationLevel: params.aggregationLevel,
          // Only include initial count for first cycle (All Time or Period 0)
          initialCount: params.isFirstCycle ? initialCount : 0,
          createdAt: createdAt,
        ));
      },
    );
  }

  /// Aggregate events by the specified level.
  ///
  /// Groups events by date key and sums their increments.
  /// Excludes 'reset' and 'created' events to only count actual increments.
  List<ChartDataPoint> _aggregateEvents(
    List<EventLog> events,
    AggregationLevel aggregationLevel,
  ) {
    final Map<DateTime, int> aggregated = {};

    for (var event in events) {
      // Skip reset/created events - only count actual increments
      if (event.eventName == 'reset' || event.eventName == 'created') continue;
      final key = _getAggregationKey(event.createdTime, aggregationLevel);
      aggregated[key] = (aggregated[key] ?? 0) + event.increment;
    }

    // Convert to list and sort by date ascending
    return aggregated.entries
        .map((e) => ChartDataPoint(date: e.key, value: e.value))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Get the aggregation key for a date based on the level.
  ///
  /// - Hourly: start of hour
  /// - Daily: start of day (midnight)
  /// - Weekly: Monday of the week
  /// - Monthly: first of the month
  DateTime _getAggregationKey(DateTime date, AggregationLevel level) {
    switch (level) {
      case AggregationLevel.hourly:
        return DateTime(date.year, date.month, date.day, date.hour);
      case AggregationLevel.daily:
        return DateTime(date.year, date.month, date.day);
      case AggregationLevel.weekly:
        // Calculate Monday of the week (weekday 1 = Monday, 7 = Sunday)
        final weekday = date.weekday;
        return DateTime(date.year, date.month, date.day - (weekday - 1));
      case AggregationLevel.monthly:
        return DateTime(date.year, date.month);
    }
  }
}
