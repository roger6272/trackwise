import 'package:equatable/equatable.dart';

import '../../domain/entities/event_log.dart';

/// Base state class for Events BLoC.
///
/// All event-related states extend this class and use Equatable for value equality.
/// States represent the current status of the events feature in the UI.
abstract class EventsState extends Equatable {
  const EventsState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any events are loaded.
///
/// This is the starting state when the BLoC is first created.
/// The UI should show a placeholder or trigger LoadEvents.
class EventsInitial extends EventsState {
  const EventsInitial();
}

/// Loading state while fetching events.
///
/// Emitted during:
/// - Initial load (LoadEvents)
/// - Filter changes (FilterByDateRange, FilterByItem)
///
/// The UI should show a loading indicator.
class EventsLoading extends EventsState {
  const EventsLoading();
}

/// Success state with loaded events.
///
/// Contains the list of events and current filter values.
/// Filters are preserved so the UI can show what range/item is active.
class EventsLoaded extends EventsState {
  /// List of event logs matching current filters
  final List<EventLog> events;

  /// Start of date range filter (null if filtering by item)
  final DateTime? startDate;

  /// End of date range filter (null if filtering by item)
  final DateTime? endDate;

  /// Item ID filter (null if filtering by date range only)
  final String? itemId;

  const EventsLoaded({
    required this.events,
    this.startDate,
    this.endDate,
    this.itemId,
  });

  @override
  List<Object?> get props => [events, startDate, endDate, itemId];

  /// Create a copy with updated fields.
  ///
  /// Useful for adding events optimistically without reloading from Firestore.
  ///
  /// Example:
  /// ```dart
  /// // Add new event to list
  /// final updatedEvents = [newEvent, ...currentState.events];
  /// final newState = currentState.copyWith(events: updatedEvents);
  /// ```
  EventsLoaded copyWith({
    List<EventLog>? events,
    DateTime? startDate,
    DateTime? endDate,
    String? itemId,
  }) {
    return EventsLoaded(
      events: events ?? this.events,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      itemId: itemId ?? this.itemId,
    );
  }

  /// Whether filtering by specific item (vs date range)
  bool get isFilteringByItem => itemId != null;

  /// Total count of events
  int get totalEvents => events.length;

  /// Sum of all increments in the events list
  int get totalIncrements => events.fold(0, (sum, e) => sum + e.increment);
}

/// Error state with failure message.
///
/// Emitted when:
/// - Firestore operation fails (ServerFailure)
/// - User not authenticated (AuthFailure)
///
/// The UI should display the error message to the user.
class EventsError extends EventsState {
  /// Human-readable error message extracted from Failure.message
  final String message;

  const EventsError(this.message);

  @override
  List<Object?> get props => [message];
}
