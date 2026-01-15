# Item Detail Page Revamp - Design Document

**Date:** 2026-01-15
**Status:** Approved

## Overview

Revamp the Item Detail Page to match FlutterFlow's feature set while using clean architecture patterns. The current new page is missing key analytics features that users expect.

## Goals

- Match FlutterFlow detail page functionality
- Use clean architecture patterns (BLoC, domain utilities)
- Reuse existing infrastructure where possible
- Keep implementation simple (YAGNI)

## Layout Structure

```
┌─────────────────────────────────────┐
│  AppBar (Item Name + Back button)   │
├─────────────────────────────────────┤
│  Filter Section                     │
│  ┌─────────────────────────────────┐│
│  │ [1D] [7D] [30D]  (aggregation)  ││
│  │ [Total] [Since Last Reset]      ││
│  │ "Ends on: Jan 15, 2026" ▼       ││
│  │ (collapsible calendar)          ││
│  └─────────────────────────────────┘│
├─────────────────────────────────────┤
│  Stats Section                      │
│  ┌─────────────────────────────────┐│
│  │ 156 Total  vs 142  +9.8% DoD    ││
│  │                                 ││
│  │  [Increments ○──● Cumulative]   ││
│  │  ┌─────────────────────────┐   ││
│  │  │      CHART AREA         │   ││
│  │  └─────────────────────────┘   ││
│  └─────────────────────────────────┘│
├─────────────────────────────────────┤
│  Summary Cards                      │
│  ┌──────────┐  ┌──────────┐        │
│  │   245    │  │   8.2    │        │
│  │ Current  │  │ Average  │        │
│  └──────────┘  └──────────┘        │
└─────────────────────────────────────┘
```

## Features

### Filter Section
- **Aggregation chips**: 1D / 7D / 30D quick selection
- **Data scope chips**: Total / Since Last Reset toggle
- **Date picker**: Tappable date display that expands to calendar
- Calendar collapses after date selection

### Stats Section
- **Stats header**: Shows total count for period
- **Period comparison**: "vs [prior count]" with percentage change
- **Color coding**: Green for positive %, red for negative %
- **Period label**: DoD (day-over-day), WoW (week-over-week), MoM (month-over-month)
- **Chart toggle**: Switch between Increments and Cumulative views
- **Chart display**: Bar chart or cumulative line chart

### Summary Cards
- **Current Count**: Item's current total count
- **Average**: Average per period (day/week/month based on aggregation)
- **Animations**: Fade + slide-up on page load

## State Management

### Local State (StatefulWidget)
UI-only state that doesn't affect data:
- `showCalendar`: bool - expand/collapse calendar
- `showCumulative`: bool - which chart to display

### Filter State (StatefulWidget)
Page-specific filter state:
- `aggregation`: String - '1D', '7D', '30D'
- `selectedDate`: DateTime - end date for range
- `showSinceReset`: bool - filter by last reset

### Data Flow
1. Page loads → EventsBloc fetches events, ChartsBloc loads chart
2. Filter changes → Update local state → Dispatch to ChartsBloc → Call StatsCalculator
3. BLoC emits → Page rebuilds with new data

## Technical Design

### StatsCalculator Utility

Location: `lib/features/items/domain/utils/stats_calculator.dart`

```dart
class StatsResult {
  final int totalCount;
  final int priorPeriodCount;
  final double? percentChange;  // null if prior is 0
  final String periodLabel;     // 'DoD', 'WoW', 'MoM'
  final double average;
}

class StatsCalculator {
  static StatsResult calculate({
    required List<EventLog> events,
    required String aggregation,
    required DateTime endDate,
    DateTime? lastResetTime,
    bool sinceResetOnly = false,
  });
}
```

### UI Widgets

Location: `lib/features/items/presentation/widgets/item_detail/`

| Widget | Purpose |
|--------|---------|
| `filter_section.dart` | Aggregation chips + Reset chips + Collapsible calendar |
| `stats_section.dart` | Stats header + Chart toggle + Chart display |
| `summary_cards.dart` | Current Count + Average cards with animations |

### Animations

Use Flutter built-in animations:
- `SlideTransition` + `FadeTransition` for summary cards
- `AnimationController` in StatefulWidget
- No external dependencies needed

## Files to Create

```
lib/features/items/domain/utils/
└── stats_calculator.dart

lib/features/items/presentation/widgets/item_detail/
├── filter_section.dart
├── stats_section.dart
└── summary_cards.dart
```

## Files to Modify

```
lib/features/items/presentation/pages/
└── item_detail_page.dart  (complete rewrite)
```

## Reused Components

- `EventsBloc` - loads events for item
- `ChartsBloc` - generates chart data
- `BarChartWidget` - existing bar chart
- `CumulativeChartWidget` - existing cumulative chart

## Reference

FlutterFlow implementation: `lib/account_profile_creation/detail_page/detail_page_widget.dart`

Key functions to port from `lib/flutter_flow/custom_functions.dart`:
- `totalincrements()` - total for period
- `totalincrementsPrior()` - prior period total
- `totalincrementsPoP()` - percentage change
- `totalincrementsAverage()` - average calculation

## Out of Scope

- Event log list (not in FlutterFlow version)
- New BLoC creation (reuse existing)
- External animation libraries
