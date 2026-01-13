import 'package:equatable/equatable.dart';

import '../../domain/entities/event_log.dart';

/// Base event class for Events BLoC.
///
/// All event-related events extend this class and use Equatable for value equality.
/// Events represent user actions that trigger BLoC state changes.
abstract class EventsEvent extends Equatable {
  const EventsEvent();

  @override
  List<Object?> get props => [];
}

/// Event to load events from Firestore.
///
/// Uses GetEventsByDateRangeUseCase or GetEventsByItemUseCase depending on
/// which filters are provided.
///
/// If no dates provided, defaults to last 30 days.
///
/// Example:
/// ```dart
/// // Load last 30 days
/// bloc.add(LoadEvents());
///
/// // Load specific date range
/// bloc.add(LoadEvents(
///   startDate: DateTime(2024, 1, 1),
///   endDate: DateTime(2024, 1, 31),
/// ));
///
/// // Load for specific item
/// bloc.add(LoadEvents(itemId: 'item_123'));
/// ```
class LoadEvents extends EventsEvent {
  final DateTime? startDate;
  final DateTime? endDate;
  final String? itemId;

  const LoadEvents({
    this.startDate,
    this.endDate,
    this.itemId,
  });

  @override
  List<Object?> get props => [startDate, endDate, itemId];
}

/// Event to filter events by date range.
///
/// Reloads events with the new date range filter applied.
///
/// Example:
/// ```dart
/// bloc.add(FilterByDateRange(
///   startDate: DateTime(2024, 1, 1),
///   endDate: DateTime(2024, 1, 31),
/// ));
/// ```
class FilterByDateRange extends EventsEvent {
  final DateTime startDate;
  final DateTime endDate;

  const FilterByDateRange({
    required this.startDate,
    required this.endDate,
  });

  @override
  List<Object?> get props => [startDate, endDate];
}

/// Event to filter events by item.
///
/// Reloads events for the specified item only.
///
/// Example:
/// ```dart
/// bloc.add(FilterByItem('item_123'));
/// ```
class FilterByItem extends EventsEvent {
  final String itemId;

  const FilterByItem(this.itemId);

  @override
  List<Object?> get props => [itemId];
}

/// Event to clear all filters and reload.
///
/// Resets to default (last 30 days, no item filter).
class ClearFilters extends EventsEvent {
  const ClearFilters();
}

/// Event to add a new event (from Bluetooth or manual).
///
/// Used for real-time event updates from ESP32 via Bluetooth.
/// The event is added optimistically to the UI and persisted to Firestore.
///
/// Example:
/// ```dart
/// bloc.add(AddEvent(newEvent));
/// ```
class AddEvent extends EventsEvent {
  final EventLog event;

  const AddEvent(this.event);

  @override
  List<Object?> get props => [event];
}

/// Event to add multiple events in batch (from Bluetooth).
///
/// Used when ESP32 sends multiple events at once.
/// Events are added optimistically to the UI and persisted in batch to Firestore.
///
/// Example:
/// ```dart
/// bloc.add(AddEventsBatch(eventsFromBluetooth));
/// ```
class AddEventsBatch extends EventsEvent {
  final List<EventLog> events;

  const AddEventsBatch(this.events);

  @override
  List<Object?> get props => [events];
}
