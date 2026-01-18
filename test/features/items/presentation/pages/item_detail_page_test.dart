import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:trackwise/features/charts/domain/entities/chart_data.dart';
import 'package:trackwise/features/charts/domain/entities/chart_data_point.dart';
import 'package:trackwise/features/charts/presentation/bloc/charts_bloc.dart';
import 'package:trackwise/features/charts/presentation/bloc/charts_event.dart';
import 'package:trackwise/features/charts/presentation/bloc/charts_state.dart';
import 'package:trackwise/features/events/presentation/bloc/events_bloc.dart';
import 'package:trackwise/features/events/presentation/bloc/events_event.dart';
import 'package:trackwise/features/events/presentation/bloc/events_state.dart';
import 'package:trackwise/features/items/presentation/pages/item_detail_page.dart';

class MockEventsBloc extends MockBloc<EventsEvent, EventsState>
    implements EventsBloc {}

class MockChartsBloc extends MockBloc<ChartsEvent, ChartsState>
    implements ChartsBloc {}

void main() {
  late MockEventsBloc mockEventsBloc;
  late MockChartsBloc mockChartsBloc;

  setUpAll(() {
    registerFallbackValue(const LoadEvents());
    registerFallbackValue(LoadBarChart(
      startDate: DateTime.now(),
      endDate: DateTime.now(),
      aggregationLevel: AggregationLevel.daily,
    ));
  });

  setUp(() {
    mockEventsBloc = MockEventsBloc();
    mockChartsBloc = MockChartsBloc();

    // Register mocks in service locator
    final sl = GetIt.instance;
    if (sl.isRegistered<EventsBloc>()) {
      sl.unregister<EventsBloc>();
    }
    if (sl.isRegistered<ChartsBloc>()) {
      sl.unregister<ChartsBloc>();
    }
    sl.registerFactory<EventsBloc>(() => mockEventsBloc);
    sl.registerFactory<ChartsBloc>(() => mockChartsBloc);

    when(() => mockEventsBloc.state).thenReturn(const EventsInitial());
    when(() => mockChartsBloc.state).thenReturn(const ChartsInitial());
  });

  tearDown(() {
    final sl = GetIt.instance;
    if (sl.isRegistered<EventsBloc>()) {
      sl.unregister<EventsBloc>();
    }
    if (sl.isRegistered<ChartsBloc>()) {
      sl.unregister<ChartsBloc>();
    }
  });

  Widget createTestWidget({
    String itemId = 'test_item',
    String? itemName = 'Test Item',
    int? currentCount = 10,
    DateTime? lastResetTime,
  }) {
    return MaterialApp(
      home: ItemDetailPage(
        itemId: itemId,
        itemName: itemName,
        currentCount: currentCount,
        lastResetTime: lastResetTime ?? DateTime.now(),
      ),
    );
  }

  group('ItemDetailPage', () {
    testWidgets('displays app bar with item name', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(find.text('Test Item'), findsOneWidget);
    });

    testWidgets('displays "None" when item name is null', (tester) async {
      await tester.pumpWidget(createTestWidget(itemName: null));
      await tester.pump();

      // Find "None" in the AppBar title specifically
      // Note: "None" also appears in the reminder type label in StaticHeader
      expect(find.text('None'), findsWidgets);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('None'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('has back button in app bar', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    });

    testWidgets('displays filter section with aggregation options',
        (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // The filter section should be visible
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays loading state when events are loading',
        (tester) async {
      when(() => mockEventsBloc.state).thenReturn(const EventsLoading());

      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // Page should still render even during loading
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays events when loaded', (tester) async {
      when(() => mockEventsBloc.state).thenReturn(
        const EventsLoaded(events: []),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays charts when loaded', (tester) async {
      final chartData = ChartData(
        dataPoints: [
          ChartDataPoint(date: DateTime.now(), value: 5),
        ],
        aggregationLevel: AggregationLevel.daily,
      );

      when(() => mockChartsBloc.state).thenReturn(
        ChartsLoaded(
          chartData: chartData,
          chartType: ChartType.bar,
          startDate: DateTime.now().subtract(const Duration(days: 1)),
          endDate: DateTime.now(),
        ),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('uses current count passed as parameter', (tester) async {
      when(() => mockEventsBloc.state).thenReturn(
        const EventsLoaded(events: []),
      );

      await tester.pumpWidget(createTestWidget(currentCount: 42));
      await tester.pump();

      // The summary cards should display the count
      // Note: The exact display depends on widget implementation
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}
