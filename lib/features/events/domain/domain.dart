/// Domain layer exports for the events feature.
///
/// Contains:
/// - Entities: EventLog
/// - Repository interfaces: EventLogRepository
/// - Use cases: GetEventsByDateRange, InsertEvents, GetEventsByItem, DeleteEventsForItem
library events.domain;

// Entities
export 'entities/event_log.dart';

// Repositories
export 'repositories/event_log_repository.dart';

// Use cases
export 'usecases/get_events_by_date_range_usecase.dart';
export 'usecases/insert_events_usecase.dart';
export 'usecases/get_events_by_item_usecase.dart';
export 'usecases/delete_events_for_item_usecase.dart';
