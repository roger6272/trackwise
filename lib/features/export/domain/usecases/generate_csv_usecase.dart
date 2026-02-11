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

    // Filter to latest cycle only when byCycle + latestCycleOnly
    if (params.aggregationLevel == ExportAggregationLevel.byCycle &&
        params.latestCycleOnly &&
        filteredEvents.isNotEmpty) {
      final Map<String, int> maxResetPerItem = {};
      for (final event in filteredEvents) {
        final currentMax = maxResetPerItem[event.itemId];
        if (currentMax == null || event.resetNumber > currentMax) {
          maxResetPerItem[event.itemId] = event.resetNumber;
        }
      }
      filteredEvents = filteredEvents
          .where((e) => e.resetNumber == maxResetPerItem[e.itemId])
          .toList();
    }

    if (filteredEvents.isEmpty) {
      return Right(_generateCSV(filteredEvents, params.aggregationLevel, {}, {}, {}, {}, {}));
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

    // Build itemId -> categoryId, itemId -> itemName, and cycle maps
    final itemsResult = await itemRepository.getItems(userId);
    final Map<String, String?> itemCategoryMap = {};
    final Map<String, String> itemNameMap = {};
    final Map<String, Map<String, String>> itemCycleNotesMap = {};
    final Map<String, Map<String, String>> itemCycleNamesMap = {};
    itemsResult.fold(
      (_) {},
      (items) {
        for (final item in items) {
          itemCategoryMap[item.id] = item.categoryId;
          itemNameMap[item.id] = item.name;
          if (item.cycleNotes.isNotEmpty) {
            itemCycleNotesMap[item.id] = item.cycleNotes;
          }
          if (item.cycleNames.isNotEmpty) {
            itemCycleNamesMap[item.id] = item.cycleNames;
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

    final csv = _generateCSV(filteredEvents, params.aggregationLevel, itemCategoryMap, categoryNameMap, itemNameMap, itemCycleNotesMap, itemCycleNamesMap);
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
    Map<String, Map<String, String>> itemCycleNamesMap,
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

    // Helper to get cycle note for an item's reset number
    String getCycleNote(String itemId, int resetNumber) {
      final notes = itemCycleNotesMap[itemId];
      if (notes == null) return '';
      return notes[resetNumber.toString()] ?? '';
    }

    // Helper to get cycle name for an item's reset number
    String getCycleName(String itemId, int resetNumber) {
      final names = itemCycleNamesMap[itemId];
      if (names == null) return '';
      return names[resetNumber.toString()] ?? '';
    }

    // Header row
    if (aggregationLevel == ExportAggregationLevel.raw) {
      buffer.writeln('Item Name,Category,Event Type,Cycle,Cycle Note,Timestamp,Event Count');
    } else if (aggregationLevel == ExportAggregationLevel.byCycle) {
      buffer.writeln('Item Name,Category,Cycle,Cycle Name,Cycle Note,Total Count');
    } else {
      buffer.writeln('Item Name,Category,Event Type,Date,Event Count');
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
    } else if (aggregationLevel == ExportAggregationLevel.byCycle) {
      // By cycle - group by item + cycle, sum increments (excluding reset/created)
      _writeByCycleRows(buffer, events, getCategoryName, getItemName, getCycleName, getCycleNote, itemCycleNamesMap, itemCycleNotesMap);
    } else {
      // Daily aggregation - filter out reset and created events
      final incrementEvents = events.where((e) => e.eventName != 'reset' && e.eventName != 'created').toList();

      final aggregated = _aggregateEvents(incrementEvents, aggregationLevel, itemCategoryMap, categoryNameMap, itemNameMap);

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

  /// Write by-cycle aggregation rows.
  void _writeByCycleRows(
    StringBuffer buffer,
    List<EventLog> events,
    String Function(String) getCategoryName,
    String Function(String) getItemName,
    String Function(String, int) getCycleName,
    String Function(String, int) getCycleNote,
    Map<String, Map<String, String>> itemCycleNamesMap,
    Map<String, Map<String, String>> itemCycleNotesMap,
  ) {
    // Filter out reset and created events
    final incrementEvents = events.where((e) => e.eventName != 'reset' && e.eventName != 'created').toList();

    // Group by itemId + resetNumber, sum increments
    final Map<String, Map<int, int>> cycleAggregation = {}; // itemId -> {resetNumber -> totalCount}
    for (final event in incrementEvents) {
      cycleAggregation.putIfAbsent(event.itemId, () => {});
      cycleAggregation[event.itemId]![event.resetNumber] =
          (cycleAggregation[event.itemId]![event.resetNumber] ?? 0) + event.increment;
    }

    // Also collect all item+cycle combos from all events (including reset/created) to ensure cycles appear even with 0 count
    for (final event in events) {
      cycleAggregation.putIfAbsent(event.itemId, () => {});
      cycleAggregation[event.itemId]!.putIfAbsent(event.resetNumber, () => 0);
    }

    // Also include cycles that have names or notes but no events
    // (e.g., item was reset from device without app creating event logs)
    for (final entry in itemCycleNamesMap.entries) {
      cycleAggregation.putIfAbsent(entry.key, () => {});
      for (final cycleKey in entry.value.keys) {
        final resetNumber = int.tryParse(cycleKey);
        if (resetNumber != null) {
          cycleAggregation[entry.key]!.putIfAbsent(resetNumber, () => 0);
        }
      }
    }
    for (final entry in itemCycleNotesMap.entries) {
      cycleAggregation.putIfAbsent(entry.key, () => {});
      for (final cycleKey in entry.value.keys) {
        final resetNumber = int.tryParse(cycleKey);
        if (resetNumber != null) {
          cycleAggregation[entry.key]!.putIfAbsent(resetNumber, () => 0);
        }
      }
    }

    // Build sorted rows: by item name, then by cycle number
    final rows = <_ByCycleRow>[];
    for (final entry in cycleAggregation.entries) {
      final itemId = entry.key;
      final itemName = getItemName(itemId);
      final category = getCategoryName(itemId);
      for (final cycleEntry in entry.value.entries) {
        final resetNumber = cycleEntry.key;
        rows.add(_ByCycleRow(
          itemName: itemName,
          category: category,
          cycle: resetNumber + 1, // 1-based display
          cycleName: getCycleName(itemId, resetNumber),
          cycleNote: getCycleNote(itemId, resetNumber),
          totalCount: cycleEntry.value,
        ));
      }
    }

    rows.sort((a, b) {
      final nameCompare = a.itemName.compareTo(b.itemName);
      if (nameCompare != 0) return nameCompare;
      return a.cycle.compareTo(b.cycle);
    });

    for (final row in rows) {
      buffer.writeln(
        '${_escapeCSV(row.itemName)},${_escapeCSV(row.category)},${row.cycle},${_escapeCSV(row.cycleName)},${_escapeCSV(row.cycleNote)},${row.totalCount}',
      );
    }
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
      case ExportAggregationLevel.byCycle:
        return date;
      case ExportAggregationLevel.daily:
        return DateTime(date.year, date.month, date.day);
    }
  }

  /// Format date as YYYY-MM-DD.
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Format date with time as YYYY-MM-DD HH:MM:SS ±HH:MM.
  String _formatDateTime(DateTime date) {
    final offset = date.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final hours = offset.inHours.abs().toString().padLeft(2, '0');
    final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')} $sign$hours:$minutes';
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

/// Internal helper for by-cycle row data.
class _ByCycleRow {
  final String itemName;
  final String category;
  final int cycle;
  final String cycleName;
  final String cycleNote;
  final int totalCount;

  _ByCycleRow({
    required this.itemName,
    required this.category,
    required this.cycle,
    required this.cycleName,
    required this.cycleNote,
    required this.totalCount,
  });
}
