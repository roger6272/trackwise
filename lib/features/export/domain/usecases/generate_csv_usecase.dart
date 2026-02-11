import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import 'package:traxelos/core/error/failures.dart';
import 'package:traxelos/core/usecases/usecase.dart';
import 'package:traxelos/features/categories/domain/repositories/category_repository.dart';
import 'package:traxelos/features/events/domain/entities/event_log.dart';
import 'package:traxelos/features/events/domain/repositories/event_log_repository.dart';
import 'package:traxelos/features/export/domain/entities/aggregation_key.dart';
import 'package:traxelos/features/export/domain/entities/csv_export_config.dart';
import 'package:traxelos/features/items/domain/repositories/item_repository.dart';

/// Use case for generating CSV from event data.
@injectable
class GenerateCSVUseCase implements UseCase<String, CSVExportConfig> {
  final EventLogRepository repository;
  final ItemRepository itemRepository;
  final CategoryRepository categoryRepository;

  GenerateCSVUseCase(this.repository, this.itemRepository, this.categoryRepository);

  @override
  Future<Either<Failure, String>> call(CSVExportConfig params) async {
    // Get events from repository
    final eventsResult = await repository.getEventsByDateRange(
      params.startDate,
      params.endDate,
    );

    if (eventsResult.isLeft()) {
      return Left(eventsResult.fold((l) => l, (_) => throw Exception()));
    }

    final events = eventsResult.getOrElse(() => []);

    // Filter by selected items if specified
    var filteredEvents = (params.itemIds != null && params.itemIds!.isNotEmpty)
        ? events.where((e) => params.itemIds!.contains(e.itemId)).toList()
        : events;

    // Filter by data scope
    if (params.dataScope == ExportDataScope.latestCycle && filteredEvents.isNotEmpty) {
      // Find the maximum reset number per item (latest cycle per item)
      final Map<String, int> maxResetPerItem = {};
      for (final event in filteredEvents) {
        final currentMax = maxResetPerItem[event.itemId] ?? 0;
        if (event.resetNumber > currentMax) {
          maxResetPerItem[event.itemId] = event.resetNumber;
        }
      }
      filteredEvents = filteredEvents
          .where((e) => e.resetNumber == maxResetPerItem[e.itemId])
          .toList();
    }

    if (filteredEvents.isEmpty) {
      return Right(_generateCSV(filteredEvents, params.aggregationLevel, {}, {}, {}, {}));
    }

    // Get userId from first event to fetch items and categories
    final userId = filteredEvents.first.userId;
    if (userId.isEmpty) {
      return const Left(ValidationFailure('Invalid user data in events'));
    }

    // Verify all events belong to the same user (data integrity check)
    final hasMultipleUsers = filteredEvents.any((e) => e.userId != userId);
    if (hasMultipleUsers) {
      return const Left(ValidationFailure('Events contain mixed user data'));
    }

    // Build itemId -> categoryId and itemId -> itemName mappings
    final itemsResult = await itemRepository.getItems(userId);
    final Map<String, String?> itemCategoryMap = {};
    final Map<String, String> itemNameMap = {};
    final Map<String, Map<String, String>> itemCycleNotesMap = {};
    itemsResult.fold(
      (_) {},
      (items) {
        for (final item in items) {
          itemCategoryMap[item.id] = item.categoryId;
          itemNameMap[item.id] = item.name;
          if (item.cycleNotes.isNotEmpty) {
            itemCycleNotesMap[item.id] = item.cycleNotes;
          }
        }
      },
    );

    // Filter out events for deleted items (items not in the active items list)
    filteredEvents = filteredEvents.where((e) => itemNameMap.containsKey(e.itemId)).toList();

    // Build categoryId -> categoryName mapping
    final categoriesResult = await categoryRepository.getCategories(userId);
    final Map<String, String> categoryNameMap = {};
    categoriesResult.fold(
      (_) {},
      (categories) {
        for (final category in categories) {
          categoryNameMap[category.id] = category.name;
        }
      },
    );

    final csv = _generateCSV(filteredEvents, params.aggregationLevel, itemCategoryMap, categoryNameMap, itemNameMap, itemCycleNotesMap);
    return Right(csv);
  }

  /// Generate CSV string from events.
  String _generateCSV(
    List<EventLog> events,
    ExportAggregationLevel aggregationLevel,
    Map<String, String?> itemCategoryMap,
    Map<String, String> categoryNameMap,
    Map<String, String> itemNameMap,
    Map<String, Map<String, String>> itemCycleNotesMap,
  ) {
    final buffer = StringBuffer();

    // Helper to get category name from itemId
    String getCategoryName(String itemId) {
      final categoryId = itemCategoryMap[itemId];
      if (categoryId == null || categoryId.isEmpty) return 'Uncategorized';
      return categoryNameMap[categoryId] ?? 'Uncategorized';
    }

    // Helper to get item name from itemId
    String getItemName(String itemId) {
      return itemNameMap[itemId] ?? 'Unknown Item';
    }

    // Header row - use Timestamp for raw, Date for daily, Period Start for weekly/monthly
    // Helper to get cycle note for an item's reset number
    String getCycleNote(String itemId, int resetNumber) {
      final notes = itemCycleNotesMap[itemId];
      if (notes == null) return '';
      return notes[resetNumber.toString()] ?? '';
    }

    if (aggregationLevel == ExportAggregationLevel.raw) {
      buffer.writeln('Item Name,Category,Event Type,Cycle,Cycle Note,Timestamp,Event Count');
    } else if (aggregationLevel == ExportAggregationLevel.daily) {
      buffer.writeln('Item Name,Category,Event Type,Date,Event Count');
    } else {
      buffer.writeln('Item Name,Category,Event Type,Period Start,Event Count');
    }

    if (events.isEmpty) {
      return buffer.toString();
    }

    if (aggregationLevel == ExportAggregationLevel.raw) {
      // Raw events - one row per event with full timestamp
      for (final event in events) {
        final itemName = getItemName(event.itemId);
        final category = getCategoryName(event.itemId);
        final cycleNote = getCycleNote(event.itemId, event.resetNumber);
        buffer.writeln(
          '${_escapeCSV(itemName)},${_escapeCSV(category)},${_escapeCSV(event.eventName)},${event.resetNumber},${_escapeCSV(cycleNote)},${_formatDateTime(event.createdTime)},${event.increment}',
        );
      }
    } else {
      // Aggregated events - group by item, category, and date
      final aggregated = _aggregateEvents(events, aggregationLevel, itemCategoryMap, categoryNameMap, itemNameMap);

      // Sort by item name, then by date
      final sortedKeys = aggregated.keys.toList()
        ..sort((a, b) {
          final nameCompare = a.itemName.compareTo(b.itemName);
          if (nameCompare != 0) return nameCompare;
          return a.date.compareTo(b.date);
        });

      for (final key in sortedKeys) {
        buffer.writeln(
          '${_escapeCSV(key.itemName)},${_escapeCSV(key.category)},${_escapeCSV(key.eventType)},${_formatDate(key.date)},${aggregated[key]}',
        );
      }
    }

    return buffer.toString();
  }

  /// Aggregate events by the specified level.
  Map<AggregationKey, int> _aggregateEvents(
    List<EventLog> events,
    ExportAggregationLevel level,
    Map<String, String?> itemCategoryMap,
    Map<String, String> categoryNameMap,
    Map<String, String> itemNameMap,
  ) {
    final Map<AggregationKey, int> aggregated = {};

    // Helper to get category name from itemId
    String getCategoryName(String itemId) {
      final categoryId = itemCategoryMap[itemId];
      if (categoryId == null || categoryId.isEmpty) return 'Uncategorized';
      return categoryNameMap[categoryId] ?? 'Uncategorized';
    }

    // Helper to get item name from itemId
    String getItemName(String itemId) {
      return itemNameMap[itemId] ?? 'Unknown Item';
    }

    for (final event in events) {
      final key = AggregationKey(
        itemName: getItemName(event.itemId),
        category: getCategoryName(event.itemId),
        eventType: event.eventName,
        date: _getAggregationDate(event.createdTime, level),
      );
      aggregated[key] = (aggregated[key] ?? 0) + event.increment;
    }

    return aggregated;
  }

  /// Get the aggregation date based on level.
  DateTime _getAggregationDate(DateTime date, ExportAggregationLevel level) {
    switch (level) {
      case ExportAggregationLevel.raw:
        return date;
      case ExportAggregationLevel.daily:
        return DateTime(date.year, date.month, date.day);
      case ExportAggregationLevel.weekly:
        // Start of week (Monday) - use Duration for proper date arithmetic
        final daysToSubtract = date.weekday - 1;
        final weekStart = date.subtract(Duration(days: daysToSubtract));
        return DateTime(weekStart.year, weekStart.month, weekStart.day);
      case ExportAggregationLevel.monthly:
        return DateTime(date.year, date.month);
    }
  }

  /// Format date as YYYY-MM-DD.
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Format date with time as YYYY-MM-DD HH:MM:SS.
  String _formatDateTime(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
  }

  /// Escape CSV value - wrap in quotes if contains comma, newline, or quote.
  String _escapeCSV(String value) {
    if (value.contains(',') || value.contains('\n') || value.contains('"')) {
      // Escape double quotes by doubling them
      final escaped = value.replaceAll('"', '""');
      return '"$escaped"';
    }
    return value;
  }
}
