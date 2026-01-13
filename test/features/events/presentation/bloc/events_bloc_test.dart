import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:trackwise/core/error/failures.dart';
import 'package:trackwise/features/events/domain/usecases/get_events_by_date_range_usecase.dart';
import 'package:trackwise/features/events/domain/usecases/get_events_by_item_usecase.dart';
import 'package:trackwise/features/events/domain/usecases/insert_events_usecase.dart';
import 'package:trackwise/features/events/presentation/bloc/events_bloc.dart';
import 'package:trackwise/features/events/presentation/bloc/events_event.dart';
import 'package:trackwise/features/events/presentation/bloc/events_state.dart';

import '../../helpers/test_helper.dart';
import '../../helpers/test_fixtures.dart';

void main() {
  late EventsBloc bloc;
  late MockGetEventsByDateRangeUseCase mockGetEventsByDateRange;
  late MockGetEventsByItemUseCase mockGetEventsByItem;
  late MockInsertEventsUseCase mockInsertEvents;

  setUp(() {
    mockGetEventsByDateRange = MockGetEventsByDateRangeUseCase();
    mockGetEventsByItem = MockGetEventsByItemUseCase();
    mockInsertEvents = MockInsertEventsUseCase();

    bloc = EventsBloc(
      getEventsByDateRangeUseCase: mockGetEventsByDateRange,
      getEventsByItemUseCase: mockGetEventsByItem,
      insertEventsUseCase: mockInsertEvents,
    );
  });

  setUpAll(() {
    registerFallbackValue(GetEventsByDateRangeParams(
      startDate: DateTime(2024, 1, 1),
      endDate: DateTime(2024, 1, 31),
    ));
    registerFallbackValue(GetEventsByItemParams('item_1'));
    registerFallbackValue(InsertEventsParams(const []));
  });

  tearDown(() {
    bloc.close();
  });

  group('EventsBloc', () {
    test('initial state is EventsInitial', () {
      expect(bloc.state, const EventsInitial());
    });

    group('LoadEvents', () {
      blocTest<EventsBloc, EventsState>(
        'emits [EventsLoading, EventsLoaded] when LoadEvents succeeds with date range',
        build: () {
          when(() => mockGetEventsByDateRange(any()))
              .thenAnswer((_) async => Right(testEventLogs));
          return bloc;
        },
        act: (bloc) => bloc.add(LoadEvents(
          startDate: testStartDate,
          endDate: testEndDate,
        )),
        expect: () => [
          const EventsLoading(),
          isA<EventsLoaded>()
              .having((s) => s.events, 'events', testEventLogs)
              .having((s) => s.startDate, 'startDate', testStartDate)
              .having((s) => s.endDate, 'endDate', testEndDate),
        ],
      );

      blocTest<EventsBloc, EventsState>(
        'emits [EventsLoading, EventsLoaded] when LoadEvents succeeds with itemId',
        build: () {
          when(() => mockGetEventsByItem(any()))
              .thenAnswer((_) async => Right(testEventLogs));
          return bloc;
        },
        act: (bloc) => bloc.add(LoadEvents(itemId: testItemId)),
        expect: () => [
          const EventsLoading(),
          isA<EventsLoaded>()
              .having((s) => s.events, 'events', testEventLogs)
              .having((s) => s.itemId, 'itemId', testItemId),
        ],
      );

      blocTest<EventsBloc, EventsState>(
        'emits [EventsLoading, EventsError] when LoadEvents fails',
        build: () {
          when(() => mockGetEventsByDateRange(any()))
              .thenAnswer((_) async => const Left(ServerFailure('Error')));
          return bloc;
        },
        act: (bloc) => bloc.add(const LoadEvents()),
        expect: () => [
          const EventsLoading(),
          const EventsError('Error'),
        ],
      );
    });

    group('FilterByDateRange', () {
      blocTest<EventsBloc, EventsState>(
        'emits [EventsLoading, EventsLoaded] when FilterByDateRange succeeds',
        build: () {
          when(() => mockGetEventsByDateRange(any()))
              .thenAnswer((_) async => Right(testEventLogs));
          return bloc;
        },
        act: (bloc) => bloc.add(FilterByDateRange(
          startDate: testStartDate,
          endDate: testEndDate,
        )),
        expect: () => [
          const EventsLoading(),
          isA<EventsLoaded>()
              .having((s) => s.startDate, 'startDate', testStartDate)
              .having((s) => s.endDate, 'endDate', testEndDate),
        ],
      );
    });

    group('FilterByItem', () {
      blocTest<EventsBloc, EventsState>(
        'emits [EventsLoading, EventsLoaded] when FilterByItem succeeds',
        build: () {
          when(() => mockGetEventsByItem(any()))
              .thenAnswer((_) async => Right(testEventLogs));
          return bloc;
        },
        act: (bloc) => bloc.add(FilterByItem(testItemId)),
        expect: () => [
          const EventsLoading(),
          isA<EventsLoaded>()
              .having((s) => s.itemId, 'itemId', testItemId),
        ],
      );
    });

    group('AddEvent', () {
      blocTest<EventsBloc, EventsState>(
        'adds event to beginning of list and persists',
        build: () {
          when(() => mockInsertEvents(any()))
              .thenAnswer((_) async => const Right(null));
          return bloc;
        },
        seed: () => EventsLoaded(
          events: [testEventLog2],
          startDate: testStartDate,
          endDate: testEndDate,
        ),
        act: (bloc) => bloc.add(AddEvent(testEventLog1)),
        expect: () => [
          isA<EventsLoaded>()
              .having((s) => s.events.length, 'events.length', 2)
              .having((s) => s.events.first, 'first event', testEventLog1),
        ],
        verify: (_) {
          verify(() => mockInsertEvents(any())).called(1);
        },
      );

      blocTest<EventsBloc, EventsState>(
        'does nothing when state is not EventsLoaded',
        build: () => bloc,
        act: (bloc) => bloc.add(AddEvent(testEventLog1)),
        expect: () => [],
      );
    });

    group('AddEventsBatch', () {
      blocTest<EventsBloc, EventsState>(
        'adds multiple events to beginning of list and persists',
        build: () {
          when(() => mockInsertEvents(any()))
              .thenAnswer((_) async => const Right(null));
          return bloc;
        },
        seed: () => EventsLoaded(
          events: [testEventLog3],
          startDate: testStartDate,
          endDate: testEndDate,
        ),
        act: (bloc) => bloc.add(AddEventsBatch([testEventLog1, testEventLog2])),
        expect: () => [
          isA<EventsLoaded>()
              .having((s) => s.events.length, 'events.length', 3),
        ],
        verify: (_) {
          verify(() => mockInsertEvents(any())).called(1);
        },
      );
    });
  });
}
