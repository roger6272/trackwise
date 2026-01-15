# Item Detail Page Revamp - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Revamp the Item Detail Page to match FlutterFlow's analytics features with clean architecture.

**Architecture:** StatefulWidget with local UI state, reusing existing EventsBloc and ChartsBloc. New StatsCalculator utility for period calculations. Three section widgets: FilterSection, StatsSection, SummaryCards.

**Tech Stack:** Flutter, flutter_bloc, fl_chart, google_fonts

---

## Task 1: Create StatsResult Model

**Files:**
- Create: `lib/features/items/domain/utils/stats_calculator.dart`

**Step 1: Create the stats result model and calculator stub**

```dart
import 'package:flutter/material.dart';
import '../../../events/domain/entities/event_log.dart';

/// Result of stats calculation for a given period.
class StatsResult {
  final int totalCount;
  final int priorPeriodCount;
  final double? percentChange;
  final String periodLabel;
  final double average;

  const StatsResult({
    required this.totalCount,
    required this.priorPeriodCount,
    this.percentChange,
    required this.periodLabel,
    required this.average,
  });

  /// Whether the percent change is positive
  bool get isPositive => (percentChange ?? 0) > 0;

  /// Whether the percent change is negative
  bool get isNegative => (percentChange ?? 0) < 0;
}

/// Calculates stats from event logs for display in ItemDetailPage.
class StatsCalculator {
  StatsCalculator._();

  /// Calculate all stats in one pass.
  ///
  /// [events] - List of all events for the item
  /// [aggregation] - '1D', '7D', or '30D'
  /// [endDate] - End date for the period (inclusive)
  /// [lastResetTime] - Item's last reset time (optional)
  /// [sinceResetOnly] - If true, only include events after lastResetTime
  static StatsResult calculate({
    required List<EventLog> events,
    required String aggregation,
    required DateTime endDate,
    DateTime? lastResetTime,
    bool sinceResetOnly = false,
  }) {
    final periodDays = _getPeriodDays(aggregation);
    final periodLabel = _getPeriodLabel(aggregation);

    // Calculate date ranges
    final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
    final currentStart = endOfDay.subtract(Duration(days: periodDays - 1));
    final currentStartDay = DateTime(currentStart.year, currentStart.month, currentStart.day);

    final priorEnd = currentStartDay.subtract(const Duration(seconds: 1));
    final priorStart = priorEnd.subtract(Duration(days: periodDays - 1));
    final priorStartDay = DateTime(priorStart.year, priorStart.month, priorStart.day);

    // Filter events
    final filteredEvents = _filterEvents(
      events: events,
      lastResetTime: lastResetTime,
      sinceResetOnly: sinceResetOnly,
    );

    // Calculate totals
    int currentTotal = 0;
    int priorTotal = 0;

    for (final event in filteredEvents) {
      if (event.eventName == 'reset') continue;

      final eventTime = event.createdTime;

      if (_isInRange(eventTime, currentStartDay, endOfDay)) {
        currentTotal += event.increment;
      } else if (_isInRange(eventTime, priorStartDay, priorEnd)) {
        priorTotal += event.increment;
      }
    }

    // Calculate percent change
    double? percentChange;
    if (priorTotal > 0) {
      percentChange = (currentTotal - priorTotal) / priorTotal;
    }

    // Calculate average
    final avgDivisor = aggregation == '1D' ? 24 : periodDays;
    final average = currentTotal / avgDivisor;

    return StatsResult(
      totalCount: currentTotal,
      priorPeriodCount: priorTotal,
      percentChange: percentChange,
      periodLabel: periodLabel,
      average: average,
    );
  }

  static int _getPeriodDays(String aggregation) {
    switch (aggregation) {
      case '1D':
        return 1;
      case '7D':
        return 7;
      case '30D':
        return 30;
      default:
        return 1;
    }
  }

  static String _getPeriodLabel(String aggregation) {
    switch (aggregation) {
      case '1D':
        return 'DoD';
      case '7D':
        return 'WoW';
      case '30D':
        return 'MoM';
      default:
        return 'DoD';
    }
  }

  static List<EventLog> _filterEvents({
    required List<EventLog> events,
    DateTime? lastResetTime,
    bool sinceResetOnly = false,
  }) {
    if (!sinceResetOnly || lastResetTime == null) {
      return events;
    }
    return events.where((e) => e.createdTime.isAfter(lastResetTime)).toList();
  }

  static bool _isInRange(DateTime time, DateTime start, DateTime end) {
    return (time.isAfter(start) || time.isAtSameMomentAs(start)) &&
        (time.isBefore(end) || time.isAtSameMomentAs(end));
  }
}
```

**Step 2: Verify file compiles**

Run: `cd C:\Users\weich\Documents\FlutterProjects\trackwise && flutter analyze lib/features/items/domain/utils/stats_calculator.dart`
Expected: No errors

**Step 3: Commit**

```bash
git add lib/features/items/domain/utils/stats_calculator.dart
git commit -m "feat: add StatsCalculator utility for period stats"
```

---

## Task 2: Create FilterSection Widget

**Files:**
- Create: `lib/features/items/presentation/widgets/item_detail/filter_section.dart`

**Step 1: Create the filter section widget**

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Filter section with aggregation chips, reset toggle, and calendar.
class FilterSection extends StatelessWidget {
  static const Color _primary = Color(0xFF4B39EF);
  static const Color _alternate = Color(0xFFE0E3E7);
  static const Color _primaryBackground = Color(0xFFF1F4F8);
  static const Color _primaryText = Color(0xFF14181B);

  final String aggregation;
  final bool showSinceReset;
  final DateTime selectedDate;
  final bool showCalendar;
  final ValueChanged<String> onAggregationChanged;
  final ValueChanged<bool> onShowSinceResetChanged;
  final ValueChanged<DateTime> onDateChanged;
  final VoidCallback onToggleCalendar;

  const FilterSection({
    super.key,
    required this.aggregation,
    required this.showSinceReset,
    required this.selectedDate,
    required this.showCalendar,
    required this.onAggregationChanged,
    required this.onShowSinceResetChanged,
    required this.onDateChanged,
    required this.onToggleCalendar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _alternate,
        borderRadius: BorderRadius.circular(8.0),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Aggregation chips (1D, 7D, 30D)
          _buildAggregationChips(),
          const SizedBox(height: 16.0),
          // Reset toggle (Total / Since Last Reset)
          _buildResetToggle(),
          const SizedBox(height: 16.0),
          // Date picker
          _buildDatePicker(context),
          // Calendar (collapsible)
          if (!showCalendar) _buildCalendar(context),
        ],
      ),
    );
  }

  Widget _buildAggregationChips() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: ['1D', '7D', '30D'].map((value) {
        final isSelected = aggregation == value;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: ChoiceChip(
            label: Text(value),
            selected: isSelected,
            onSelected: (_) => onAggregationChanged(value),
            selectedColor: _primary,
            backgroundColor: _primaryBackground,
            labelStyle: GoogleFonts.inter(
              color: isSelected ? Colors.white : _primaryText,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildResetToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildToggleChip('Total', !showSinceReset, () => onShowSinceResetChanged(false)),
        const SizedBox(width: 8.0),
        _buildToggleChip('Since Last Reset', showSinceReset, () => onShowSinceResetChanged(true)),
      ],
    );
  }

  Widget _buildToggleChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: isSelected ? _primary : _primaryBackground,
          borderRadius: BorderRadius.circular(5.0),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: isSelected ? Colors.white : _primaryText,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildDatePicker(BuildContext context) {
    final dateStr = DateFormat('yMMMd').format(selectedDate);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (aggregation != '1D')
          Text(
            'Ends on',
            style: GoogleFonts.inter(
              color: _primaryText,
              fontSize: 12.0,
            ),
          ),
        const SizedBox(height: 4.0),
        GestureDetector(
          onTap: onToggleCalendar,
          child: Row(
            children: [
              Text(
                dateStr,
                style: GoogleFonts.interTight(
                  color: _primaryText,
                  fontWeight: FontWeight.w500,
                  fontSize: 16.0,
                ),
              ),
              const SizedBox(width: 8.0),
              Icon(
                showCalendar ? Icons.expand_more : Icons.expand_less,
                color: _primaryText,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCalendar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Column(
        children: [
          CalendarDatePicker(
            initialDate: selectedDate,
            firstDate: DateTime(2020),
            lastDate: DateTime.now(),
            onDateChanged: (date) {
              onDateChanged(date);
              onToggleCalendar(); // Collapse after selection
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onToggleCalendar,
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

**Step 2: Verify file compiles**

Run: `cd C:\Users\weich\Documents\FlutterProjects\trackwise && flutter analyze lib/features/items/presentation/widgets/item_detail/filter_section.dart`
Expected: No errors

**Step 3: Commit**

```bash
git add lib/features/items/presentation/widgets/item_detail/filter_section.dart
git commit -m "feat: add FilterSection widget for item detail page"
```

---

## Task 3: Create StatsSection Widget

**Files:**
- Create: `lib/features/items/presentation/widgets/item_detail/stats_section.dart`

**Step 1: Create the stats section widget**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../charts/presentation/bloc/charts_bloc.dart';
import '../../../../charts/presentation/bloc/charts_state.dart';
import '../../../domain/utils/stats_calculator.dart';
import '../bar_chart_widget.dart';
import '../cumulative_chart_widget.dart';

/// Stats section with header, chart toggle, and chart display.
class StatsSection extends StatelessWidget {
  static const Color _primary = Color(0xFF4B39EF);
  static const Color _alternate = Color(0xFFE0E3E7);
  static const Color _primaryText = Color(0xFF14181B);
  static const Color _positiveColor = Color(0xFF017400);
  static const Color _negativeColor = Color(0xFF9F0202);

  final StatsResult stats;
  final bool showCumulative;
  final ValueChanged<bool> onChartTypeChanged;

  const StatsSection({
    super.key,
    required this.stats,
    required this.showCumulative,
    required this.onChartTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _alternate,
        borderRadius: BorderRadius.circular(8.0),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats header
          _buildStatsHeader(),
          const SizedBox(height: 16.0),
          // Chart toggle
          _buildChartToggle(),
          const SizedBox(height: 16.0),
          // Chart
          SizedBox(
            height: 220.0,
            child: _buildChart(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Total count
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              stats.totalCount.toString(),
              style: GoogleFonts.interTight(
                color: _primary,
                fontWeight: FontWeight.bold,
                fontSize: 30.0,
              ),
            ),
            const SizedBox(width: 8.0),
            Text(
              'Total',
              style: GoogleFonts.interTight(
                color: _primaryText,
                fontSize: 26.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4.0),
        // Prior period comparison
        Row(
          children: [
            Text(
              'vs ${stats.priorPeriodCount}',
              style: GoogleFonts.interTight(
                color: _primaryText,
                fontSize: 15.0,
              ),
            ),
            if (stats.percentChange != null) ...[
              const SizedBox(width: 10.0),
              Text(
                _formatPercent(stats.percentChange!),
                style: GoogleFonts.interTight(
                  color: _getPercentColor(),
                  fontSize: 15.0,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4.0),
              Text(
                stats.periodLabel,
                style: GoogleFonts.inter(
                  color: _primaryText,
                  fontSize: 15.0,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildChartToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          'Increments',
          style: GoogleFonts.inter(
            color: _primaryText,
            fontSize: 12.0,
          ),
        ),
        Switch(
          value: showCumulative,
          onChanged: onChartTypeChanged,
          activeColor: _primary,
          inactiveTrackColor: const Color(0xFFA158FF),
        ),
        Text(
          'Cumulative',
          style: GoogleFonts.inter(
            color: _primaryText,
            fontSize: 12.0,
          ),
        ),
      ],
    );
  }

  Widget _buildChart() {
    return BlocBuilder<ChartsBloc, ChartsState>(
      builder: (context, state) {
        if (state is ChartsLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is ChartsError) {
          return Center(child: Text('Error: ${state.message}'));
        }

        if (state is ChartsLoaded) {
          // We render the existing chart widgets which read from ChartsBloc
          if (showCumulative) {
            return const CumulativeChartWidget();
          } else {
            return const _SimpleBarChart();
          }
        }

        return const Center(child: Text('No data'));
      },
    );
  }

  String _formatPercent(double value) {
    final percent = (value * 100).toStringAsFixed(1);
    final sign = value > 0 ? '+' : '';
    return '$sign$percent%';
  }

  Color _getPercentColor() {
    if (stats.isPositive) return _positiveColor;
    if (stats.isNegative) return _negativeColor;
    return _primaryText;
  }
}

/// Simplified bar chart that doesn't include the header (header is in StatsSection).
class _SimpleBarChart extends StatelessWidget {
  const _SimpleBarChart();

  @override
  Widget build(BuildContext context) {
    // Reuse the existing BarChartWidget but it includes its own header.
    // For now, use it as-is. Can refactor later if needed.
    return const BarChartWidget();
  }
}
```

**Step 2: Verify file compiles**

Run: `cd C:\Users\weich\Documents\FlutterProjects\trackwise && flutter analyze lib/features/items/presentation/widgets/item_detail/stats_section.dart`
Expected: No errors

**Step 3: Commit**

```bash
git add lib/features/items/presentation/widgets/item_detail/stats_section.dart
git commit -m "feat: add StatsSection widget with chart toggle"
```

---

## Task 4: Create SummaryCards Widget

**Files:**
- Create: `lib/features/items/presentation/widgets/item_detail/summary_cards.dart`

**Step 1: Create the summary cards widget with animations**

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Summary cards showing current count and average with animations.
class SummaryCards extends StatefulWidget {
  final int currentCount;
  final double average;

  const SummaryCards({
    super.key,
    required this.currentCount,
    required this.average,
  });

  @override
  State<SummaryCards> createState() => _SummaryCardsState();
}

class _SummaryCardsState extends State<SummaryCards>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Row(
          children: [
            Expanded(
              child: _SummaryCard(
                value: widget.currentCount.toString(),
                label: 'Current Count',
              ),
            ),
            const SizedBox(width: 16.0),
            Expanded(
              child: _SummaryCard(
                value: widget.average.toStringAsFixed(1),
                label: 'Average',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  static const Color _alternate = Color(0xFFE0E3E7);
  static const Color _secondaryBackground = Color(0xFFFFFFFF);
  static const Color _primaryText = Color(0xFF14181B);
  static const Color _secondaryText = Color(0xFF57636C);

  final String value;
  final String label;

  const _SummaryCard({
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80.0,
      decoration: BoxDecoration(
        color: _secondaryBackground,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: _alternate, width: 0.0),
      ),
      padding: const EdgeInsets.all(12.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            style: GoogleFonts.interTight(
              color: _primaryText,
              fontWeight: FontWeight.bold,
              fontSize: 20.0,
            ),
          ),
          const SizedBox(height: 4.0),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: _secondaryText,
              fontSize: 12.0,
            ),
          ),
        ],
      ),
    );
  }
}
```

**Step 2: Verify file compiles**

Run: `cd C:\Users\weich\Documents\FlutterProjects\trackwise && flutter analyze lib/features/items/presentation/widgets/item_detail/summary_cards.dart`
Expected: No errors

**Step 3: Commit**

```bash
git add lib/features/items/presentation/widgets/item_detail/summary_cards.dart
git commit -m "feat: add SummaryCards widget with slide/fade animations"
```

---

## Task 5: Rewrite ItemDetailPage

**Files:**
- Modify: `lib/features/items/presentation/pages/item_detail_page.dart`

**Step 1: Rewrite the item detail page**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/di/injection.dart';
import '../../../charts/domain/entities/chart_data.dart';
import '../../../charts/presentation/bloc/charts_bloc.dart';
import '../../../charts/presentation/bloc/charts_event.dart';
import '../../../events/presentation/bloc/events_bloc.dart';
import '../../../events/presentation/bloc/events_event.dart';
import '../../../events/presentation/bloc/events_state.dart';
import '../../domain/utils/stats_calculator.dart';
import '../widgets/item_detail/filter_section.dart';
import '../widgets/item_detail/stats_section.dart';
import '../widgets/item_detail/summary_cards.dart';

/// Page displaying detailed information about an item.
///
/// Shows:
/// - Filter section (aggregation, reset toggle, calendar)
/// - Stats section (totals, comparison, chart)
/// - Summary cards (current count, average)
class ItemDetailPage extends StatefulWidget {
  static String routeName = 'ItemDetailPage';
  static String routePath = '/items/:id';

  final String itemId;
  final String? itemName;
  final int? currentCount;
  final DateTime? lastResetTime;

  const ItemDetailPage({
    super.key,
    required this.itemId,
    this.itemName,
    this.currentCount,
    this.lastResetTime,
  });

  @override
  State<ItemDetailPage> createState() => _ItemDetailPageState();
}

class _ItemDetailPageState extends State<ItemDetailPage> {
  // FF Colors
  static const Color _primary = Color(0xFF4B39EF);
  static const Color _primaryBackground = Color(0xFFF1F4F8);
  static const Color _primaryText = Color(0xFF14181B);

  // Filter state
  String _aggregation = '1D';
  bool _showSinceReset = false;
  DateTime _selectedDate = DateTime.now();
  bool _showCalendar = true; // true = collapsed

  // UI state
  bool _showCumulative = false;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => sl<EventsBloc>()..add(LoadEvents(itemId: widget.itemId)),
        ),
        BlocProvider(
          create: (_) => sl<ChartsBloc>()..add(_createChartEvent()),
        ),
      ],
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: _primaryBackground,
          appBar: _buildAppBar(context),
          body: SafeArea(
            child: RefreshIndicator(
              color: _primary,
              onRefresh: () async => _refreshData(context),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20.0, 24.0, 20.0, 32.0),
                  child: Column(
                    children: [
                      // Filter section
                      FilterSection(
                        aggregation: _aggregation,
                        showSinceReset: _showSinceReset,
                        selectedDate: _selectedDate,
                        showCalendar: _showCalendar,
                        onAggregationChanged: (value) => _onAggregationChanged(context, value),
                        onShowSinceResetChanged: (value) => _onShowSinceResetChanged(context, value),
                        onDateChanged: (value) => _onDateChanged(context, value),
                        onToggleCalendar: _onToggleCalendar,
                      ),
                      const SizedBox(height: 16.0),
                      // Stats section
                      BlocBuilder<EventsBloc, EventsState>(
                        builder: (context, eventsState) {
                          final stats = _calculateStats(eventsState);
                          return StatsSection(
                            stats: stats,
                            showCumulative: _showCumulative,
                            onChartTypeChanged: (value) => _onChartTypeChanged(context, value),
                          );
                        },
                      ),
                      const SizedBox(height: 16.0),
                      // Summary cards
                      BlocBuilder<EventsBloc, EventsState>(
                        builder: (context, eventsState) {
                          final stats = _calculateStats(eventsState);
                          return SummaryCards(
                            currentCount: widget.currentCount ?? 0,
                            average: stats.average,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: _primaryBackground,
      automaticallyImplyLeading: false,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: _primaryText, size: 30.0),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        widget.itemName ?? 'Item Details',
        style: GoogleFonts.interTight(
          color: _primaryText,
          fontWeight: FontWeight.w600,
          fontSize: 22.0,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: _primaryText),
          tooltip: 'Refresh',
          onPressed: () => _refreshData(context),
        ),
      ],
      centerTitle: true,
      elevation: 2.0,
    );
  }

  StatsResult _calculateStats(EventsState eventsState) {
    if (eventsState is EventsLoaded) {
      return StatsCalculator.calculate(
        events: eventsState.events,
        aggregation: _aggregation,
        endDate: _selectedDate,
        lastResetTime: widget.lastResetTime,
        sinceResetOnly: _showSinceReset,
      );
    }
    return const StatsResult(
      totalCount: 0,
      priorPeriodCount: 0,
      periodLabel: 'DoD',
      average: 0,
    );
  }

  LoadBarChart _createChartEvent() {
    final periodDays = _aggregation == '1D' ? 1 : (_aggregation == '7D' ? 7 : 30);
    final endDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);
    final startDate = endDate.subtract(Duration(days: periodDays - 1));

    final aggregationLevel = _aggregation == '1D'
        ? AggregationLevel.daily
        : (_aggregation == '7D' ? AggregationLevel.daily : AggregationLevel.daily);

    return LoadBarChart(
      startDate: startDate,
      endDate: endDate,
      aggregationLevel: aggregationLevel,
      itemId: widget.itemId,
    );
  }

  void _onAggregationChanged(BuildContext context, String value) {
    setState(() {
      _aggregation = value;
    });
    _reloadChart(context);
  }

  void _onShowSinceResetChanged(BuildContext context, bool value) {
    setState(() {
      _showSinceReset = value;
    });
    // Stats will recalculate automatically via BlocBuilder
  }

  void _onDateChanged(BuildContext context, DateTime value) {
    setState(() {
      _selectedDate = value;
    });
    _reloadChart(context);
  }

  void _onToggleCalendar() {
    setState(() {
      _showCalendar = !_showCalendar;
    });
  }

  void _onChartTypeChanged(BuildContext context, bool showCumulative) {
    setState(() {
      _showCumulative = showCumulative;
    });

    final periodDays = _aggregation == '1D' ? 1 : (_aggregation == '7D' ? 7 : 30);
    final endDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);
    final startDate = endDate.subtract(Duration(days: periodDays - 1));

    if (showCumulative) {
      context.read<ChartsBloc>().add(LoadCumulativeChart(
        startDate: startDate,
        endDate: endDate,
        itemId: widget.itemId,
      ));
    } else {
      context.read<ChartsBloc>().add(_createChartEvent());
    }
  }

  void _reloadChart(BuildContext context) {
    if (_showCumulative) {
      final periodDays = _aggregation == '1D' ? 1 : (_aggregation == '7D' ? 7 : 30);
      final endDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);
      final startDate = endDate.subtract(Duration(days: periodDays - 1));
      context.read<ChartsBloc>().add(LoadCumulativeChart(
        startDate: startDate,
        endDate: endDate,
        itemId: widget.itemId,
      ));
    } else {
      context.read<ChartsBloc>().add(_createChartEvent());
    }
  }

  void _refreshData(BuildContext context) {
    context.read<EventsBloc>().add(LoadEvents(itemId: widget.itemId));
    _reloadChart(context);
  }
}
```

**Step 2: Update router to pass additional params**

The router needs to pass currentCount and lastResetTime. Update `lib/core/router/app_router.dart` lines 98-109:

```dart
GoRoute(
  name: 'ItemDetailPage',
  path: 'items/:id',
  builder: (context, state) {
    final itemId = state.pathParameters['id'] ?? '';
    final itemName = state.uri.queryParameters['name'];
    final countStr = state.uri.queryParameters['count'];
    final resetStr = state.uri.queryParameters['resetTime'];
    return ItemDetailPage(
      itemId: itemId,
      itemName: itemName,
      currentCount: countStr != null ? int.tryParse(countStr) : null,
      lastResetTime: resetStr != null ? DateTime.tryParse(resetStr) : null,
    );
  },
),
```

**Step 3: Update items_list_page.dart to pass additional params**

Update the navigation in `lib/features/items/presentation/pages/items_list_page.dart` around line 357:

```dart
onTap: () {
  context.pushNamed(
    'ItemDetailPage',
    pathParameters: {'id': item.id},
    queryParameters: {
      'name': item.name,
      'count': item.count.toString(),
      if (item.lastResetTime != null)
        'resetTime': item.lastResetTime!.toIso8601String(),
    },
  );
},
```

**Step 4: Verify files compile**

Run: `cd C:\Users\weich\Documents\FlutterProjects\trackwise && flutter analyze lib/features/items/presentation/pages/item_detail_page.dart lib/core/router/app_router.dart lib/features/items/presentation/pages/items_list_page.dart`
Expected: No errors (or minor warnings)

**Step 5: Commit**

```bash
git add lib/features/items/presentation/pages/item_detail_page.dart lib/core/router/app_router.dart lib/features/items/presentation/pages/items_list_page.dart
git commit -m "feat: revamp ItemDetailPage with filter controls and stats"
```

---

## Task 6: Add lastResetTime to Item Entity

**Files:**
- Check: `lib/features/items/domain/entities/item.dart`
- Check: `lib/features/items/data/models/item_model.dart`

**Step 1: Verify Item entity has lastResetTime**

Read the Item entity to check if lastResetTime exists. If not, add it:

```dart
// In lib/features/items/domain/entities/item.dart
final DateTime? lastResetTime;
```

**Step 2: Verify ItemModel maps lastResetTime**

Ensure the model maps the Firestore field correctly.

**Step 3: Run build and test**

Run: `cd C:\Users\weich\Documents\FlutterProjects\trackwise && flutter build apk --debug`
Expected: BUILD SUCCESSFUL

**Step 4: Commit if changes were made**

```bash
git add lib/features/items/domain/entities/item.dart lib/features/items/data/models/item_model.dart
git commit -m "feat: add lastResetTime to Item entity"
```

---

## Task 7: Final Integration Test

**Step 1: Run the app**

Run: `cd C:\Users\weich\Documents\FlutterProjects\trackwise && flutter run`

**Step 2: Manual test checklist**

- [ ] Navigate to item detail page from items list
- [ ] Verify filter chips (1D/7D/30D) work
- [ ] Verify Total/Since Last Reset toggle works
- [ ] Verify calendar expands and date selection works
- [ ] Verify stats header shows total and comparison
- [ ] Verify chart toggle switches between bar and cumulative
- [ ] Verify summary cards show with animation
- [ ] Verify refresh button reloads data

**Step 3: Final commit**

```bash
git add .
git commit -m "feat: complete ItemDetailPage revamp with FF feature parity"
```

---

## Summary

| Task | Files | Description |
|------|-------|-------------|
| 1 | stats_calculator.dart | StatsResult model and calculation logic |
| 2 | filter_section.dart | Aggregation chips, reset toggle, calendar |
| 3 | stats_section.dart | Stats header with comparison, chart toggle |
| 4 | summary_cards.dart | Current count and average with animations |
| 5 | item_detail_page.dart, app_router.dart, items_list_page.dart | Page rewrite and router updates |
| 6 | item.dart, item_model.dart | Add lastResetTime if missing |
| 7 | - | Integration testing |
