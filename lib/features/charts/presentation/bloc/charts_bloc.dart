import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/usecases/get_chart_data_usecase.dart';
import '../../domain/usecases/get_cumulative_chart_data_usecase.dart';
import 'charts_event.dart';
import 'charts_state.dart';

/// BLoC for managing Charts feature state.
///
/// Handles all chart-related user actions and emits appropriate states.
/// Uses domain layer use cases for data aggregation.
///
/// Features:
/// - Bar charts with daily/weekly/monthly aggregation
/// - Cumulative (running total) charts
/// - Date range filtering
/// - Item-specific charts
///
/// Registered as factory in GetIt so each screen gets its own instance.
@injectable
class ChartsBloc extends Bloc<ChartsEvent, ChartsState> {
  final GetChartDataUseCase getChartDataUseCase;
  final GetCumulativeChartDataUseCase getCumulativeChartDataUseCase;

  ChartsBloc({
    required this.getChartDataUseCase,
    required this.getCumulativeChartDataUseCase,
  }) : super(const ChartsInitial()) {
    on<LoadBarChart>(_onLoadBarChart);
    on<LoadCumulativeChart>(_onLoadCumulativeChart);
    on<ChangeDateRange>(_onChangeDateRange);
    on<ChangeAggregationLevel>(_onChangeAggregationLevel);
    on<RefreshChart>(_onRefreshChart);
  }

  /// Handle LoadBarChart - fetch and aggregate events for bar chart.
  ///
  /// Emits:
  /// 1. ChartsLoading - while fetching
  /// 2. ChartsLoaded (ChartType.bar) - on success
  /// 3. ChartsError - on failure
  Future<void> _onLoadBarChart(
    LoadBarChart event,
    Emitter<ChartsState> emit,
  ) async {
    emit(const ChartsLoading());

    final result = await getChartDataUseCase(
      GetChartDataParams(
        startDate: event.startDate,
        endDate: event.endDate,
        aggregationLevel: event.aggregationLevel,
        itemId: event.itemId,
        sinceResetTime: event.sinceResetTime,
        untilResetTime: event.untilResetTime,
        isFirstCycle: event.isFirstCycle,
        resetNumber: event.resetNumber,
      ),
    );

    result.fold(
      (failure) => emit(ChartsError(failure.message)),
      (chartData) => emit(ChartsLoaded(
        chartData: chartData,
        chartType: ChartType.bar,
        startDate: event.startDate,
        endDate: event.endDate,
        itemId: event.itemId,
      )),
    );
  }

  /// Handle LoadCumulativeChart - fetch events and calculate running total.
  ///
  /// Emits:
  /// 1. ChartsLoading - while fetching
  /// 2. ChartsLoaded (ChartType.cumulative) - on success
  /// 3. ChartsError - on failure
  Future<void> _onLoadCumulativeChart(
    LoadCumulativeChart event,
    Emitter<ChartsState> emit,
  ) async {
    emit(const ChartsLoading());

    final result = await getCumulativeChartDataUseCase(
      GetChartDataParams(
        startDate: event.startDate,
        endDate: event.endDate,
        aggregationLevel: event.aggregationLevel,
        itemId: event.itemId,
        sinceResetTime: event.sinceResetTime,
        untilResetTime: event.untilResetTime,
        isFirstCycle: event.isFirstCycle,
        resetNumber: event.resetNumber,
      ),
    );

    result.fold(
      (failure) => emit(ChartsError(failure.message)),
      (chartData) => emit(ChartsLoaded(
        chartData: chartData,
        chartType: ChartType.cumulative,
        startDate: event.startDate,
        endDate: event.endDate,
        itemId: event.itemId,
      )),
    );
  }

  /// Handle ChangeDateRange - reload current chart with new dates.
  ///
  /// Preserves the current chart type and aggregation level.
  /// If no chart is loaded yet, defaults to bar chart with daily aggregation.
  ///
  /// Emits:
  /// 1. ChartsLoading - while fetching
  /// 2. ChartsLoaded - on success
  /// 3. ChartsError - on failure
  Future<void> _onChangeDateRange(
    ChangeDateRange event,
    Emitter<ChartsState> emit,
  ) async {
    final currentState = state;

    if (currentState is ChartsLoaded) {
      // Reload with same chart type but new date range
      if (currentState.chartType == ChartType.cumulative) {
        add(LoadCumulativeChart(
          startDate: event.startDate,
          endDate: event.endDate,
          aggregationLevel: currentState.aggregationLevel,
          itemId: currentState.itemId,
        ));
      } else {
        add(LoadBarChart(
          startDate: event.startDate,
          endDate: event.endDate,
          aggregationLevel: currentState.aggregationLevel,
          itemId: currentState.itemId,
        ));
      }
    } else {
      // Default to bar chart
      add(LoadBarChart(
        startDate: event.startDate,
        endDate: event.endDate,
      ));
    }
  }

  /// Handle ChangeAggregationLevel - reload chart with new aggregation.
  ///
  /// Applies to both bar and cumulative charts.
  ///
  /// Emits:
  /// 1. ChartsLoading - while fetching
  /// 2. ChartsLoaded - on success
  /// 3. ChartsError - on failure
  Future<void> _onChangeAggregationLevel(
    ChangeAggregationLevel event,
    Emitter<ChartsState> emit,
  ) async {
    final currentState = state;

    if (currentState is ChartsLoaded) {
      if (currentState.chartType == ChartType.cumulative) {
        add(LoadCumulativeChart(
          startDate: currentState.startDate,
          endDate: currentState.endDate,
          aggregationLevel: event.aggregationLevel,
          itemId: currentState.itemId,
        ));
      } else {
        add(LoadBarChart(
          startDate: currentState.startDate,
          endDate: currentState.endDate,
          aggregationLevel: event.aggregationLevel,
          itemId: currentState.itemId,
        ));
      }
    }
  }

  /// Handle RefreshChart - reload current chart with current settings.
  ///
  /// Useful when new events have been added and the chart needs updating.
  Future<void> _onRefreshChart(
    RefreshChart event,
    Emitter<ChartsState> emit,
  ) async {
    final currentState = state;

    if (currentState is ChartsLoaded) {
      if (currentState.chartType == ChartType.cumulative) {
        add(LoadCumulativeChart(
          startDate: currentState.startDate,
          endDate: currentState.endDate,
          aggregationLevel: currentState.aggregationLevel,
          itemId: currentState.itemId,
        ));
      } else {
        add(LoadBarChart(
          startDate: currentState.startDate,
          endDate: currentState.endDate,
          aggregationLevel: currentState.aggregationLevel,
          itemId: currentState.itemId,
        ));
      }
    }
  }
}
