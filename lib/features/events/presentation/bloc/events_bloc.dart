import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/logger.dart';
import 'package:injectable/injectable.dart';

import '../../domain/usecases/get_events_by_date_range_usecase.dart';
import '../../domain/usecases/get_events_by_item_usecase.dart';
import '../../domain/usecases/insert_events_usecase.dart';
import 'events_event.dart';
import 'events_state.dart';

/// BLoC for managing Events feature state.
///
/// Handles all event-related user actions and emits appropriate states.
/// Uses domain layer use cases to interact with the repository.
///
/// Features:
/// - Load events by date range (default: last 30 days)
/// - Filter events by item
/// - Add events in real-time (from Bluetooth)
/// - Optimistic updates for better UX
///
/// Registered as factory in GetIt so each screen gets its own instance.
@injectable
class EventsBloc extends Bloc<EventsEvent, EventsState> {
  final GetEventsByDateRangeUseCase getEventsByDateRangeUseCase;
  final GetEventsByItemUseCase getEventsByItemUseCase;
  final InsertEventsUseCase insertEventsUseCase;

  EventsBloc({
    required this.getEventsByDateRangeUseCase,
    required this.getEventsByItemUseCase,
    required this.insertEventsUseCase,
  }) : super(const EventsInitial()) {
    on<LoadEvents>(_onLoadEvents);
    on<FilterByDateRange>(_onFilterByDateRange);
    on<FilterByItem>(_onFilterByItem);
    on<ClearFilters>(_onClearFilters);
    on<AddEvent>(_onAddEvent);
    on<AddEventsBatch>(_onAddEventsBatch);
  }

  /// Handle LoadEvents - fetch events based on filters.
  ///
  /// If itemId is provided, fetches events for that item.
  /// Otherwise, fetches by date range (defaults to last 30 days).
  ///
  /// Emits:
  /// 1. EventsLoading - while fetching
  /// 2. EventsLoaded - on success
  /// 3. EventsError - on failure
  Future<void> _onLoadEvents(
    LoadEvents event,
    Emitter<EventsState> emit,
  ) async {
    AppLogger.debug('EventsBloc: LoadEvents called with itemId=${event.itemId}');
    emit(const EventsLoading());

    // If filtering by item, use item-specific query
    if (event.itemId != null) {
      AppLogger.debug('EventsBloc: Fetching events for item ${event.itemId}');
      final result = await getEventsByItemUseCase(
        GetEventsByItemParams(event.itemId!),
      );

      result.fold(
        (failure) {
          AppLogger.debug('EventsBloc: Failed to load events: ${failure.message}');
          emit(EventsError(failure.message));
        },
        (events) {
          AppLogger.debug('EventsBloc: Loaded ${events.length} events for item ${event.itemId}');
          emit(EventsLoaded(
            events: events,
            itemId: event.itemId,
          ));
        },
      );
      return;
    }

    // Otherwise, filter by date range (default to last 30 days)
    final endDate = event.endDate ?? DateTime.now();
    final startDate = event.startDate ?? endDate.subtract(const Duration(days: 30));

    final result = await getEventsByDateRangeUseCase(
      GetEventsByDateRangeParams(
        startDate: startDate,
        endDate: endDate,
      ),
    );

    result.fold(
      (failure) => emit(EventsError(failure.message)),
      (events) => emit(EventsLoaded(
        events: events,
        startDate: startDate,
        endDate: endDate,
      )),
    );
  }

  /// Handle FilterByDateRange - reload with new date range.
  ///
  /// Clears any item filter and applies the new date range.
  ///
  /// Emits:
  /// 1. EventsLoading - while fetching
  /// 2. EventsLoaded - on success with new date range
  /// 3. EventsError - on failure
  Future<void> _onFilterByDateRange(
    FilterByDateRange event,
    Emitter<EventsState> emit,
  ) async {
    emit(const EventsLoading());

    final result = await getEventsByDateRangeUseCase(
      GetEventsByDateRangeParams(
        startDate: event.startDate,
        endDate: event.endDate,
      ),
    );

    result.fold(
      (failure) => emit(EventsError(failure.message)),
      (events) => emit(EventsLoaded(
        events: events,
        startDate: event.startDate,
        endDate: event.endDate,
      )),
    );
  }

  /// Handle FilterByItem - reload for specific item.
  ///
  /// Clears date range filter and fetches all events for the item.
  ///
  /// Emits:
  /// 1. EventsLoading - while fetching
  /// 2. EventsLoaded - on success with item filter
  /// 3. EventsError - on failure
  Future<void> _onFilterByItem(
    FilterByItem event,
    Emitter<EventsState> emit,
  ) async {
    emit(const EventsLoading());

    final result = await getEventsByItemUseCase(
      GetEventsByItemParams(event.itemId),
    );

    result.fold(
      (failure) => emit(EventsError(failure.message)),
      (events) => emit(EventsLoaded(
        events: events,
        itemId: event.itemId,
      )),
    );
  }

  /// Handle ClearFilters - reset to default (last 30 days).
  ///
  /// Clears all filters and reloads with default date range.
  Future<void> _onClearFilters(
    ClearFilters event,
    Emitter<EventsState> emit,
  ) async {
    add(const LoadEvents());
  }

  /// Handle AddEvent - add single event (from Bluetooth).
  ///
  /// Uses optimistic update: Shows the event immediately in the UI
  /// and persists to Firestore in the background.
  ///
  /// Events are added at the beginning of the list (most recent first).
  ///
  /// Emits:
  /// 1. EventsLoaded with new event - optimistic update
  Future<void> _onAddEvent(
    AddEvent event,
    Emitter<EventsState> emit,
  ) async {
    final currentState = state;

    if (currentState is EventsLoaded) {
      // Optimistic update: add event to the beginning of the list
      final updatedEvents = [event.event, ...currentState.events];
      emit(currentState.copyWith(events: updatedEvents));

      // Persist to Firestore (fire and forget for real-time feel)
      // Errors are logged but don't affect the UI
      await insertEventsUseCase(InsertEventsParams([event.event]));
    }
  }

  /// Handle AddEventsBatch - add multiple events (from Bluetooth).
  ///
  /// Uses optimistic update: Shows all events immediately in the UI
  /// and persists to Firestore in batch.
  ///
  /// Events are added at the beginning of the list (most recent first).
  ///
  /// Emits:
  /// 1. EventsLoaded with new events - optimistic update
  Future<void> _onAddEventsBatch(
    AddEventsBatch event,
    Emitter<EventsState> emit,
  ) async {
    final currentState = state;

    if (currentState is EventsLoaded) {
      // Optimistic update: add all events to the beginning
      final updatedEvents = [...event.events, ...currentState.events];
      emit(currentState.copyWith(events: updatedEvents));

      // Persist to Firestore in batch
      await insertEventsUseCase(InsertEventsParams(event.events));
    }
  }
}
