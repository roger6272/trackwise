import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../events/domain/entities/event_log.dart';
import '../../../events/domain/repositories/event_log_repository.dart';
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

  GetCumulativeChartDataUseCase(this.repository);

  @override
  Future<Either<Failure, ChartData>> call(GetChartDataParams params) async {
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
        // Filter events after sinceResetTime if provided
        final filteredEvents = params.sinceResetTime != null
            ? events.where((e) => e.createdTime.isAfter(params.sinceResetTime!)).toList()
            : events;

        final cumulative = _calculateCumulative(filteredEvents);
        return Right(ChartData(
          dataPoints: cumulative,
          aggregationLevel: AggregationLevel.daily,
        ));
      },
    );
  }

  /// Calculate cumulative totals by day.
  ///
  /// First aggregates events by day, then calculates running total.
  List<ChartDataPoint> _calculateCumulative(List<EventLog> events) {
    if (events.isEmpty) return [];

    // Sort events by date ascending
    final sorted = List<EventLog>.from(events)
      ..sort((a, b) => a.createdTime.compareTo(b.createdTime));

    // First, aggregate by day
    final Map<DateTime, int> dailyTotals = {};
    for (var event in sorted) {
      final date = DateTime(
        event.createdTime.year,
        event.createdTime.month,
        event.createdTime.day,
      );
      dailyTotals[date] = (dailyTotals[date] ?? 0) + event.increment;
    }

    // Then calculate cumulative values
    final sortedDays = dailyTotals.keys.toList()..sort();
    final List<ChartDataPoint> cumulative = [];
    var runningTotal = 0;

    for (var date in sortedDays) {
      runningTotal += dailyTotals[date]!;
      cumulative.add(ChartDataPoint(date: date, value: runningTotal));
    }

    return cumulative;
  }
}
