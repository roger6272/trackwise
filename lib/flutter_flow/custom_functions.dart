import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'lat_lng.dart';
import 'place.dart';
import 'uploaded_file.dart';
import '/backend/backend.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/backend/schema/structs/index.dart';
import '/auth/firebase_auth/auth_util.dart';

int? totalincrements(
  List<EventLogRecord>? eventLog,
  String? timeunit,
  DateTime? pickedday,
  DateTime lastResetTime,
  bool showAfterResetOnly,
) {
  // Sum increment from EventLog collection and group by hour if the timeunit parameter has 1D. Group by day if the timeunit parameter has anything else. Return a list of increment by hour or day. Sort it by ascending by created_time. Also limit the day range based on a pickedday parameter. If timeunit is 1D, show 1 day of data till the pickedday date. If timeunit is 7D, show 7 day of data till the pickedday date.  If timeunit is 30D, show 30 day of data till the pickedday date.
  // Check if eventLog is null or empty, or if timeunit is null
  if (eventLog == null ||
      eventLog.isEmpty ||
      timeunit == null ||
      pickedday == null) {
    return null;
  }

  // Filter the eventLog based on the pickedday and timeunit
  DateTimeRange dateRange;
  switch (timeunit) {
    case '1D':
      final startOfDay =
          DateTime(pickedday.year, pickedday.month, pickedday.day);
      final endOfDay = startOfDay.add(Duration(days: 1));
      dateRange = DateTimeRange(
        start: startOfDay,
        end: endOfDay,
      );
      break;
    case '7D':
      final startOfNextDay =
          DateTime(pickedday.year, pickedday.month, pickedday.day)
              .add(Duration(days: 1));
      final start = startOfNextDay.subtract(Duration(days: 7));
      dateRange = DateTimeRange(
        start: start,
        end: startOfNextDay,
      );
      break;
    case '30D':
      final startOfNextDay =
          DateTime(pickedday.year, pickedday.month, pickedday.day)
              .add(Duration(days: 1));
      final start = startOfNextDay.subtract(Duration(days: 30));
      dateRange = DateTimeRange(
        start: start,
        end: startOfNextDay,
      );
      break;
    default:
      return null;
  }

  // Filter the eventLog based on the date range
  List<EventLogRecord> filteredEventLog = eventLog.where((record) {
    if (record.hasCreatedTime()) {
      DateTime createdTime = record.createdTime!;
      return createdTime.isAfter(dateRange.start) &&
          createdTime.isBefore(dateRange.end);
    }
    return false;
  }).toList();

  // If showAfterResetOnly is true, filter data after the lastResetTime
  if (showAfterResetOnly && lastResetTime != null) {
    filteredEventLog = filteredEventLog.where((record) {
      if (record.hasCreatedTime()) {
        DateTime createdTime = record.createdTime!;
        return createdTime.isAfter(lastResetTime!);
      }
      return false;
    }).toList();
  }

  // Group the filteredEventLog by hour or day based on the timeunit parameter
  Map<String, int> groupedData = {};
  for (EventLogRecord record in filteredEventLog) {
    String timeUnitValue = '';
    if (timeunit == '1D') {
      timeUnitValue = DateFormat('HH').format(record.createdTime!);
    } else {
      timeUnitValue = DateFormat('Md').format(record.createdTime!);
    }

    groupedData.update(timeUnitValue, (value) => value + record.increment,
        ifAbsent: () => record.increment);
  }

  // Convert the grouped data to a list and sort it in ascending order
  List<int> result = groupedData.values.toList();

  int sum = 0;

  for (int number in result) {
    sum += number;
  }

  return sum;
}

int? totalincrementsPrior(
  List<EventLogRecord>? eventLog,
  String? timeunit,
  DateTime? pickedday,
  DateTime? lastResetTime,
  bool showAfterResetOnly,
) {
  if (eventLog == null ||
      eventLog.isEmpty ||
      timeunit == null ||
      pickedday == null) {
    return null;
  }

  final pickednextday = DateTime(pickedday.year, pickedday.month, pickedday.day)
      .add(Duration(days: 1));

  int periodDays;
  switch (timeunit) {
    case '1D':
      periodDays = 1;
      break;
    case '7D':
      periodDays = 7;
      break;
    case '30D':
      periodDays = 30;
      break;
    default:
      return null;
  }

  // Calculate previous period range
  final prevPeriodEnd = pickednextday.subtract(Duration(days: periodDays));
  final prevPeriodStart = prevPeriodEnd.subtract(Duration(days: periodDays));

  // Filter the eventLog based on the previous period range
  final filteredEventLog = eventLog.where((record) {
    final createdTime = record.createdTime;
    return createdTime != null &&
        createdTime.isAfter(prevPeriodStart) &&
        createdTime.isBefore(prevPeriodEnd);
  }).toList();

  // If showAfterResetOnly is true, filter data based on lastResetTime
  List<EventLogRecord> finalFilteredEventLog = filteredEventLog;
  if (showAfterResetOnly && lastResetTime != null) {
    // Filter out data before the last reset using the provided lastResetTime
    finalFilteredEventLog = filteredEventLog.where((record) {
      final createdTime = record.createdTime;
      return createdTime != null && createdTime.isAfter(lastResetTime);
    }).toList();
  }

  // Sum increments
  int sum = 0;
  for (var record in finalFilteredEventLog) {
    sum += record.increment.toInt();
  }

  return sum;
}

double? totalincrementsPoP(
  List<EventLogRecord>? eventLog,
  String? timeunit,
  DateTime? pickedday,
  bool showAfterResetOnly,
  DateTime lastResetTime,
) {
  if (eventLog == null ||
      eventLog.isEmpty ||
      timeunit == null ||
      pickedday == null) {
    return null;
  }

  int periodDays;
  switch (timeunit) {
    case '1D':
      periodDays = 1;
      break;
    case '7D':
      periodDays = 7;
      break;
    case '30D':
      periodDays = 30;
      break;
    default:
      return null;
  }

  // Normalize pickedday to start of day
  final pickedStart = DateTime(pickedday.year, pickedday.month, pickedday.day);

  final currentPeriodEnd = pickedStart.add(Duration(days: 1));
  final currentPeriodStart =
      currentPeriodEnd.subtract(Duration(days: periodDays));
  final prevPeriodEnd = currentPeriodStart;
  final prevPeriodStart = prevPeriodEnd.subtract(Duration(days: periodDays));

  double currentSum = 0;
  double prevSum = 0;

  for (var record in eventLog) {
    final t = record.createdTime;
    if (t == null) continue;

    // Apply reset filter if enabled
    if (showAfterResetOnly == true && lastResetTime != null) {
      if (t.isBefore(lastResetTime)) {
        continue; // Skip records before reset
      }
    }

    if (t.isAfter(currentPeriodStart) && t.isBefore(currentPeriodEnd)) {
      currentSum += record.increment;
    } else if (t.isAfter(prevPeriodStart) && t.isBefore(prevPeriodEnd)) {
      prevSum += record.increment;
    }
  }

  if (prevSum == 0) return 0; // Can't calculate % change from 0

  final percentChange = ((currentSum - prevSum) / prevSum);
  return percentChange; // return as whole number
}

int? totalincrementsAverage(
  List<EventLogRecord>? eventLog,
  String? timeunit,
  DateTime? pickedday,
  bool showAfterResetOnly,
  DateTime lastResetTime,
) {
  // Sum increment from EventLog collection and group by hour if the timeunit parameter has 1D. Group by day if the timeunit parameter has anything else. Return a list of increment by hour or day. Sort it by ascending by created_time. Also limit the day range based on a pickedday parameter. If timeunit is 1D, show 1 day of data till the pickedday date. If timeunit is 7D, show 7 day of data till the pickedday date.  If timeunit is 30D, show 30 day of data till the pickedday date. If showAfterResetOnly is true and lastResetTime is provided, only include events after the reset time.
  // Check if eventLog is null or empty, or if timeunit is null
  if (eventLog == null ||
      eventLog.isEmpty ||
      timeunit == null ||
      pickedday == null) {
    return null;
  }

  // Filter the eventLog based on the pickedday and timeunit
  DateTimeRange dateRange;
  switch (timeunit) {
    case '1D':
      final startOfDay =
          DateTime(pickedday.year, pickedday.month, pickedday.day);
      final endOfDay = startOfDay.add(Duration(days: 1));
      dateRange = DateTimeRange(
        start: startOfDay,
        end: endOfDay,
      );
      break;
    case '7D':
      final startOfNextDay =
          DateTime(pickedday.year, pickedday.month, pickedday.day)
              .add(Duration(days: 1));
      final start = startOfNextDay.subtract(Duration(days: 7));
      dateRange = DateTimeRange(
        start: start,
        end: startOfNextDay,
      );
      break;
    case '30D':
      final startOfNextDay =
          DateTime(pickedday.year, pickedday.month, pickedday.day)
              .add(Duration(days: 1));
      final start = startOfNextDay.subtract(Duration(days: 30));
      dateRange = DateTimeRange(
        start: start,
        end: startOfNextDay,
      );
      break;
    default:
      return null;
  }

  // Filter the eventLog based on the date range and optionally reset time
  List<EventLogRecord> filteredEventLog = eventLog.where((record) {
    if (record.hasCreatedTime()) {
      DateTime createdTime = record.createdTime!;

      // Check if the event is within the date range
      bool withinDateRange = createdTime.isAfter(dateRange.start) &&
          createdTime.isBefore(dateRange.end);

      // If showAfterResetOnly is true and lastResetTime is provided,
      // also check if the event is after the reset time
      if (showAfterResetOnly == true && lastResetTime != null) {
        bool afterReset = createdTime.isAfter(lastResetTime);
        return withinDateRange && afterReset;
      }

      return withinDateRange;
    }
    return false;
  }).toList();

  // Group the filteredEventLog by hour or day based on the timeunit parameter
  Map<String, int> groupedData = {};
  for (var record in filteredEventLog) {
    String timeUnitValue = '';
    if (timeunit == '1D') {
      timeUnitValue = record.createdTime!.hour.toString().padLeft(2, '0');
    } else {
      timeUnitValue = '${record.createdTime!.month}/${record.createdTime!.day}';
    }
    groupedData.update(timeUnitValue, (value) => value + record.increment,
        ifAbsent: () => record.increment);
  }

  // Calculate the average count of the period
  int periodCount = 0;
  if (timeunit == '1D') {
    periodCount = 24;
  } else if (timeunit == '7D') {
    periodCount = 7;
  } else if (timeunit == '30D') {
    periodCount = 30;
  }

  int sum = groupedData.values.fold(0, (a, b) => a + b);
  if (periodCount == 0) return null;
  double average = sum / periodCount;

  return average.round();
}

int? totalincrementsMax(
  List<EventLogRecord>? eventLog,
  String? timeunit,
  DateTime? pickedday,
  bool showAfterResetOnly,
  DateTime lastResetTime,
) {
  if (eventLog == null ||
      eventLog.isEmpty ||
      timeunit == null ||
      pickedday == null) {
    return null;
  }

  // Filter the eventLog based on the pickedday and timeunit
  DateTimeRange dateRange;
  switch (timeunit) {
    case '1D':
      final startOfDay =
          DateTime(pickedday.year, pickedday.month, pickedday.day);
      final endOfDay = startOfDay.add(Duration(days: 1));
      dateRange = DateTimeRange(
        start: startOfDay,
        end: endOfDay,
      );
      break;
    case '7D':
      final startOfNextDay =
          DateTime(pickedday.year, pickedday.month, pickedday.day)
              .add(Duration(days: 1));
      final start = startOfNextDay.subtract(Duration(days: 7));
      dateRange = DateTimeRange(
        start: start,
        end: startOfNextDay,
      );
      break;
    case '30D':
      final startOfNextDay =
          DateTime(pickedday.year, pickedday.month, pickedday.day)
              .add(Duration(days: 1));
      final start = startOfNextDay.subtract(Duration(days: 30));
      dateRange = DateTimeRange(
        start: start,
        end: startOfNextDay,
      );
      break;
    default:
      return null;
  }

  // Filter the eventLog based on the date range
  List<EventLogRecord> filteredEventLog = eventLog.where((record) {
    if (record.hasCreatedTime()) {
      DateTime createdTime = record.createdTime!;
      bool withinDateRange = createdTime.isAfter(dateRange.start) &&
          createdTime.isBefore(dateRange.end);

      // If showAfterResetOnly is true, also check if the event is after lastResetTime
      if (showAfterResetOnly == true && lastResetTime != null) {
        return withinDateRange && createdTime.isAfter(lastResetTime);
      }

      return withinDateRange;
    }
    return false;
  }).toList();

  // Group the filteredEventLog by hour or day based on the timeunit parameter
  Map<String, int> groupedData = {};
  for (var record in filteredEventLog) {
    String timeUnitValue = '';
    if (timeunit == '1D') {
      timeUnitValue = record.createdTime!.hour.toString().padLeft(2, '0');
    } else {
      timeUnitValue = '${record.createdTime!.month}/${record.createdTime!.day}';
    }
    groupedData.update(timeUnitValue, (value) => value + record.increment,
        ifAbsent: () => record.increment);
  }

  // Calculate the max count of the period
  if (groupedData.isEmpty) return 0;
  int maxCount = groupedData.values.reduce((a, b) => a > b ? a : b);
  return maxCount;
}

int? totalincrementsMin(
  List<EventLogRecord>? eventLog,
  String? timeunit,
  DateTime? pickedday,
  bool showAfterResetOnly,
  DateTime lastResetTime,
) {
  if (eventLog == null ||
      eventLog.isEmpty ||
      timeunit == null ||
      pickedday == null) {
    return null;
  }

  // Filter the eventLog based on the pickedday and timeunit
  DateTimeRange dateRange;
  switch (timeunit) {
    case '1D':
      final startOfDay =
          DateTime(pickedday.year, pickedday.month, pickedday.day);
      final endOfDay = startOfDay.add(Duration(days: 1));
      dateRange = DateTimeRange(
        start: startOfDay,
        end: endOfDay,
      );
      break;
    case '7D':
      final startOfNextDay =
          DateTime(pickedday.year, pickedday.month, pickedday.day)
              .add(Duration(days: 1));
      final start = startOfNextDay.subtract(Duration(days: 7));
      dateRange = DateTimeRange(
        start: start,
        end: startOfNextDay,
      );
      break;
    case '30D':
      final startOfNextDay =
          DateTime(pickedday.year, pickedday.month, pickedday.day)
              .add(Duration(days: 1));
      final start = startOfNextDay.subtract(Duration(days: 30));
      dateRange = DateTimeRange(
        start: start,
        end: startOfNextDay,
      );
      break;
    default:
      return null;
  }

  // Filter the eventLog based on the date range
  List<EventLogRecord> filteredEventLog = eventLog.where((record) {
    if (record.hasCreatedTime()) {
      DateTime createdTime = record.createdTime!;
      return createdTime.isAfter(dateRange.start) &&
          createdTime.isBefore(dateRange.end);
    }
    return false;
  }).toList();

  // Apply reset filter if showAfterResetOnly is true
  if (showAfterResetOnly == true && lastResetTime != null) {
    filteredEventLog = filteredEventLog.where((record) {
      if (record.hasCreatedTime()) {
        DateTime createdTime = record.createdTime!;
        return createdTime.isAfter(lastResetTime);
      }
      return false;
    }).toList();
  }

  // Initialize groupedData with all possible time units set to 0
  Map<String, int> groupedData = {};

  // Pre-populate all possible time units with 0
  if (timeunit == '1D') {
    // For daily view, include all 24 hours
    for (int hour = 0; hour < 24; hour++) {
      groupedData[hour.toString().padLeft(2, '0')] = 0;
    }
  } else {
    // For 7D and 30D views, include all days in the range
    DateTime current = dateRange.start;
    while (current.isBefore(dateRange.end)) {
      String dayKey = '${current.month}/${current.day}';
      groupedData[dayKey] = 0;
      current = current.add(Duration(days: 1));
    }
  }

  // Group the filteredEventLog by hour or day and add to the initialized values
  for (var record in filteredEventLog) {
    String timeUnitValue = '';
    if (timeunit == '1D') {
      timeUnitValue = record.createdTime!.hour.toString().padLeft(2, '0');
    } else {
      timeUnitValue = '${record.createdTime!.month}/${record.createdTime!.day}';
    }
    groupedData.update(timeUnitValue, (value) => value + record.increment,
        ifAbsent: () => record.increment);
  }

  // Calculate the min count of the period
  if (groupedData.isEmpty) return 0;
  int minCount = groupedData.values.reduce((a, b) => a < b ? a : b);
  return minCount;
}
