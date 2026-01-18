import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:trackwise/core/error/failures.dart';
import 'package:trackwise/features/charts/domain/entities/chart_data.dart';
import 'package:trackwise/features/charts/domain/usecases/get_chart_data_usecase.dart';
import 'package:trackwise/features/charts/presentation/bloc/charts_bloc.dart';
import 'package:trackwise/features/charts/presentation/bloc/charts_event.dart';
import 'package:trackwise/features/charts/presentation/bloc/charts_state.dart';

import '../../helpers/test_helper.dart';
import '../../helpers/test_fixtures.dart';

void main() {
  late ChartsBloc bloc;
  late MockGetChartDataUseCase mockGetChartData;
  late MockGetCumulativeChartDataUseCase mockGetCumulativeChartData;

  setUp(() {
    mockGetChartData = MockGetChartDataUseCase();
    mockGetCumulativeChartData = MockGetCumulativeChartDataUseCase();

    bloc = ChartsBloc(
      getChartDataUseCase: mockGetChartData,
      getCumulativeChartDataUseCase: mockGetCumulativeChartData,
    );
  });

  setUpAll(() {
    registerFallbackValue(GetChartDataParams(
      startDate: DateTime(2024, 1, 1),
      endDate: DateTime(2024, 1, 31),
    ));
  });

  tearDown(() {
    bloc.close();
  });

  group('ChartsBloc', () {
    test('initial state is ChartsInitial', () {
      expect(bloc.state, const ChartsInitial());
    });

    group('LoadBarChart', () {
      blocTest<ChartsBloc, ChartsState>(
        'emits [ChartsLoading, ChartsLoaded] when LoadBarChart succeeds',
        build: () {
          when(() => mockGetChartData(any()))
              .thenAnswer((_) async => Right(testChartDataDaily));
          return bloc;
        },
        act: (bloc) => bloc.add(LoadBarChart(
          startDate: testStartDate,
          endDate: testEndDate,
          aggregationLevel: AggregationLevel.daily,
        )),
        expect: () => [
          const ChartsLoading(),
          isA<ChartsLoaded>()
              .having((s) => s.chartType, 'chartType', ChartType.bar)
              .having((s) => s.chartData, 'chartData', testChartDataDaily)
              .having((s) => s.startDate, 'startDate', testStartDate)
              .having((s) => s.endDate, 'endDate', testEndDate),
        ],
      );

      blocTest<ChartsBloc, ChartsState>(
        'emits [ChartsLoading, ChartsError] when LoadBarChart fails',
        build: () {
          when(() => mockGetChartData(any()))
              .thenAnswer((_) async => const Left(ServerFailure('Error')));
          return bloc;
        },
        act: (bloc) => bloc.add(LoadBarChart(
          startDate: testStartDate,
          endDate: testEndDate,
        )),
        expect: () => [
          const ChartsLoading(),
          const ChartsError('Error'),
        ],
      );

      blocTest<ChartsBloc, ChartsState>(
        'passes itemId to use case when provided',
        build: () {
          when(() => mockGetChartData(any()))
              .thenAnswer((_) async => Right(testChartDataDaily));
          return bloc;
        },
        act: (bloc) => bloc.add(LoadBarChart(
          startDate: testStartDate,
          endDate: testEndDate,
          itemId: testItemId,
        )),
        verify: (_) {
          verify(() => mockGetChartData(any(
            that: isA<GetChartDataParams>()
                .having((p) => p.itemId, 'itemId', testItemId),
          ))).called(1);
        },
      );
    });

    group('LoadCumulativeChart', () {
      blocTest<ChartsBloc, ChartsState>(
        'emits [ChartsLoading, ChartsLoaded] when LoadCumulativeChart succeeds',
        build: () {
          when(() => mockGetCumulativeChartData(any()))
              .thenAnswer((_) async => Right(testCumulativeChartData));
          return bloc;
        },
        act: (bloc) => bloc.add(LoadCumulativeChart(
          startDate: testStartDate,
          endDate: testEndDate,
        )),
        expect: () => [
          const ChartsLoading(),
          isA<ChartsLoaded>()
              .having((s) => s.chartType, 'chartType', ChartType.cumulative)
              .having((s) => s.chartData, 'chartData', testCumulativeChartData),
        ],
      );

      blocTest<ChartsBloc, ChartsState>(
        'emits [ChartsLoading, ChartsError] when LoadCumulativeChart fails',
        build: () {
          when(() => mockGetCumulativeChartData(any()))
              .thenAnswer((_) async => const Left(ServerFailure('Error')));
          return bloc;
        },
        act: (bloc) => bloc.add(LoadCumulativeChart(
          startDate: testStartDate,
          endDate: testEndDate,
        )),
        expect: () => [
          const ChartsLoading(),
          const ChartsError('Error'),
        ],
      );
    });

    group('ChangeAggregationLevel', () {
      blocTest<ChartsBloc, ChartsState>(
        'reloads bar chart with new aggregation level',
        build: () {
          when(() => mockGetChartData(any()))
              .thenAnswer((_) async => Right(testChartDataWeekly));
          return bloc;
        },
        seed: () => ChartsLoaded(
          chartData: testChartDataDaily,
          chartType: ChartType.bar,
          startDate: testStartDate,
          endDate: testEndDate,
        ),
        act: (bloc) => bloc.add(const ChangeAggregationLevel(AggregationLevel.weekly)),
        expect: () => [
          const ChartsLoading(),
          isA<ChartsLoaded>()
              .having((s) => s.chartData.aggregationLevel, 'aggregationLevel', AggregationLevel.weekly),
        ],
      );

      blocTest<ChartsBloc, ChartsState>(
        'reloads cumulative chart with new aggregation level',
        build: () {
          when(() => mockGetCumulativeChartData(any()))
              .thenAnswer((_) async => Right(testCumulativeChartDataWeekly));
          return bloc;
        },
        seed: () => ChartsLoaded(
          chartData: testCumulativeChartData,
          chartType: ChartType.cumulative,
          startDate: testStartDate,
          endDate: testEndDate,
        ),
        act: (bloc) => bloc.add(const ChangeAggregationLevel(AggregationLevel.weekly)),
        expect: () => [
          const ChartsLoading(),
          isA<ChartsLoaded>()
              .having((s) => s.chartType, 'chartType', ChartType.cumulative)
              .having((s) => s.chartData.aggregationLevel, 'aggregationLevel', AggregationLevel.weekly),
        ],
      );
    });

    group('RefreshChart', () {
      blocTest<ChartsBloc, ChartsState>(
        'refreshes bar chart when current chart is bar',
        build: () {
          when(() => mockGetChartData(any()))
              .thenAnswer((_) async => Right(testChartDataDaily));
          return bloc;
        },
        seed: () => ChartsLoaded(
          chartData: testChartDataDaily,
          chartType: ChartType.bar,
          startDate: testStartDate,
          endDate: testEndDate,
        ),
        act: (bloc) => bloc.add(const RefreshChart()),
        expect: () => [
          const ChartsLoading(),
          isA<ChartsLoaded>().having((s) => s.chartType, 'chartType', ChartType.bar),
        ],
      );

      blocTest<ChartsBloc, ChartsState>(
        'refreshes cumulative chart when current chart is cumulative',
        build: () {
          when(() => mockGetCumulativeChartData(any()))
              .thenAnswer((_) async => Right(testCumulativeChartData));
          return bloc;
        },
        seed: () => ChartsLoaded(
          chartData: testCumulativeChartData,
          chartType: ChartType.cumulative,
          startDate: testStartDate,
          endDate: testEndDate,
        ),
        act: (bloc) => bloc.add(const RefreshChart()),
        expect: () => [
          const ChartsLoading(),
          isA<ChartsLoaded>().having((s) => s.chartType, 'chartType', ChartType.cumulative),
        ],
      );
    });
  });
}
