import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../charts/domain/entities/chart_data.dart';
import '../../../charts/presentation/bloc/charts_bloc.dart';
import '../../../charts/presentation/bloc/charts_event.dart';
import '../../../events/presentation/bloc/events_bloc.dart';
import '../../../events/presentation/bloc/events_event.dart';
import '../../../events/presentation/bloc/events_state.dart';
import '../../domain/entities/item.dart';
import '../../domain/utils/stats_calculator.dart';
import '../widgets/item_detail/dynamic_stats.dart';
import '../widgets/item_detail/filter_section.dart';
import '../widgets/item_detail/shimmer_skeletons.dart';
import '../widgets/item_detail/static_header.dart';
import '../widgets/item_detail/stats_section.dart';

/// Page displaying detailed information about an item.
///
/// Layout structure (semantic separation):
/// - Static header: Current count, initial value, goal (unaffected by filters)
/// - Filter section: Aggregation, reset toggle, date picker (sticky)
/// - Chart section: Chart toggle and chart display (affected by filters)
/// - Dynamic stats: Period stats like increments, trend, avg (affected by filters)
///
/// Integrates with EventsBloc and ChartsBloc for data management.
class ItemDetailPage extends StatefulWidget {
  static String routeName = 'ItemDetailPage';
  static String routePath = '/items/:id';

  /// The ID of the item to display.
  final String itemId;

  /// Optional item name for the app bar.
  final String? itemName;

  /// Current count of the item.
  final int? currentCount;

  /// Last reset time of the item.
  final DateTime? lastResetTime;

  /// Initial count when the item was created.
  final int? initialCount;

  /// Target goal for this item.
  final int? goal;

  /// Amount incremented per event.
  final int? incrementBy;

  /// Type of reminder configured for this item.
  final ReminderType? reminderType;

  const ItemDetailPage({
    super.key,
    required this.itemId,
    this.itemName,
    this.currentCount,
    this.lastResetTime,
    this.initialCount,
    this.goal,
    this.incrementBy,
    this.reminderType,
  });

  @override
  State<ItemDetailPage> createState() => _ItemDetailPageState();
}

class _ItemDetailPageState extends State<ItemDetailPage> {
  // Filter state
  String _aggregation = '1D';
  bool _showSinceReset = true; // Default to "Since Last Reset" for clearer context
  DateTime _selectedDate = DateTime.now();

  // UI state
  bool _showCumulative = false;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primaryBackground = AppColors.primaryBackground(brightness);
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final alternate = AppColors.alternate(brightness);

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
        builder: (context) => GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
            FocusManager.instance.primaryFocus?.unfocus();
          },
          child: Scaffold(
            backgroundColor: primaryBackground,
            appBar: AppBar(
              backgroundColor: primaryBackground,
              automaticallyImplyLeading: false,
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: primaryText,
                  size: 30.0,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Text(
                widget.itemName ?? 'None',
                style: GoogleFonts.interTight(
                  color: primaryText,
                  fontWeight: FontWeight.w600,
                  fontSize: 22.0,
                ),
              ),
              centerTitle: true,
              elevation: 0.0,
            ),
            body: SafeArea(
              top: true,
              child: CustomScrollView(
                slivers: [
                  // Static Header (Current Count, Initial, Goal)
                  // NOT affected by filters - shows item's current state
                  SliverToBoxAdapter(
                    child: StaticHeader(
                      currentCount: widget.currentCount ?? 0,
                      initialCount: widget.initialCount ?? 0,
                      goal: widget.goal,
                      incrementBy: widget.incrementBy ?? 1,
                      lastResetTime: widget.lastResetTime,
                      reminderType: widget.reminderType ?? ReminderType.none,
                    ),
                  ),
                  // Sticky Filter Section (part of filtered zone)
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _StickyFilterHeaderDelegate(
                      backgroundColor: brightness == Brightness.light
                          ? const Color(0xFFF8F9FB)
                          : primaryText.withValues(alpha: 0.03),
                      child: Container(
                        decoration: BoxDecoration(
                          color: brightness == Brightness.light
                              ? const Color(0xFFF8F9FB)
                              : primaryText.withValues(alpha: 0.03),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(24.0),
                            topRight: Radius.circular(24.0),
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(20.0, 12.0, 20.0, 8.0),
                        child: FilterSection(
                          aggregation: _aggregation,
                          selectedDate: _selectedDate,
                          onAggregationChanged: (value) {
                            setState(() {
                              _aggregation = value;
                            });
                            _reloadChart(context);
                          },
                          onDateChanged: (date) {
                            setState(() {
                              _selectedDate = date;
                            });
                            _reloadChart(context);
                          },
                        ),
                      ),
                      maxHeight: 100.0,
                      minHeight: 100.0,
                    ),
                  ),
                  // Filtered Content Zone (continues from filter section)
                  // ALL content below is affected by filters
                  SliverToBoxAdapter(
                    child: Container(
                      color: brightness == Brightness.light
                          ? const Color(0xFFF8F9FB)
                          : primaryText.withValues(alpha: 0.03),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 24.0),
                        child: BlocBuilder<EventsBloc, EventsState>(
                              builder: (context, eventsState) {
                                // Show shimmer skeleton while loading
                                if (eventsState is EventsLoading) {
                                  return const Column(
                                    children: [
                                      ChartSectionSkeleton(),
                                      SizedBox(height: 16.0),
                                      DynamicStatsSkeleton(),
                                    ],
                                  );
                                }

                                final stats = _calculateStats(eventsState);
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Shared header with period badge + Since Reset toggle
                                    Padding(
                                      padding: const EdgeInsets.only(left: 4.0, right: 4.0, bottom: 14.0),
                                      child: Row(
                                        children: [
                                          Text(
                                            'Results',
                                            style: GoogleFonts.interTight(
                                              fontSize: 16.0,
                                              fontWeight: FontWeight.w600,
                                              color: primaryText,
                                            ),
                                          ),
                                          const SizedBox(width: 8.0),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8.0,
                                              vertical: 3.0,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(6.0),
                                            ),
                                            child: Text(
                                              _getPeriodLabel(),
                                              style: GoogleFonts.inter(
                                                fontSize: 11.0,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ),
                                          const Spacer(),
                                          // Since Reset toggle
                                          GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _showSinceReset = !_showSinceReset;
                                              });
                                              _reloadChart(context);
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 10.0,
                                                vertical: 5.0,
                                              ),
                                              decoration: BoxDecoration(
                                                color: _showSinceReset
                                                    ? AppColors.primary.withValues(alpha: 0.12)
                                                    : secondaryText.withValues(alpha: 0.08),
                                                borderRadius: BorderRadius.circular(6.0),
                                                border: Border.all(
                                                  color: _showSinceReset
                                                      ? AppColors.primary.withValues(alpha: 0.3)
                                                      : Colors.transparent,
                                                  width: 1.0,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    _showSinceReset
                                                        ? Icons.history_rounded
                                                        : Icons.all_inclusive_rounded,
                                                    size: 12.0,
                                                    color: _showSinceReset
                                                        ? AppColors.primary
                                                        : secondaryText,
                                                  ),
                                                  const SizedBox(width: 4.0),
                                                  Text(
                                                    _showSinceReset ? 'Since Reset' : 'All Time',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 11.0,
                                                      fontWeight: FontWeight.w500,
                                                      color: _showSinceReset
                                                          ? AppColors.primary
                                                          : secondaryText,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Activity sub-header
                                    Padding(
                                      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
                                      child: Text(
                                        'Activity',
                                        style: GoogleFonts.inter(
                                          fontSize: 13.0,
                                          fontWeight: FontWeight.w500,
                                          color: secondaryText,
                                        ),
                                      ),
                                    ),
                                    // Chart Section
                                    Container(
                                      decoration: BoxDecoration(
                                        color: alternate,
                                        borderRadius: BorderRadius.circular(12.0),
                                        border: Border.all(
                                          color: AppColors.primary.withValues(alpha: 0.1),
                                          width: 1.0,
                                        ),
                                      ),
                                      padding: const EdgeInsets.only(top: 12.0),
                                      child: ChartSection(
                                        showCumulative: _showCumulative,
                                        onChartTypeChanged: (value) {
                                          setState(() {
                                            _showCumulative = value;
                                          });
                                          _reloadChart(context);
                                        },
                                        range: _aggregation,
                                        selectedDate: _selectedDate,
                                        periodTotal: stats.totalCount,
                                      ),
                                    ),
                                    const SizedBox(height: 16.0),
                                    // Dynamic Stats Section
                                    DynamicStats(
                                      stats: stats,
                                      range: _aggregation,
                                      initialCount: widget.initialCount ?? 0,
                                      lastResetTime: widget.lastResetTime,
                                      showSinceReset: _showSinceReset,
                                    ),
                                  ],
                                );
                              },
                            ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Calculate statistics from the events state.
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
    // Return empty stats if not loaded
    return const StatsResult(
      totalCount: 0,
      priorPeriodCount: 0,
      percentChange: null,
      periodLabel: 'DoD',
      average: 0.0,
      maxCount: 0,
      minCount: 0,
    );
  }

  /// Create a chart event based on current filters.
  ChartsEvent _createChartEvent() {
    // Calculate date range based on aggregation
    final periodDays = _aggregation == '1D' ? 1 : (_aggregation == '7D' ? 7 : 30);
    final endDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      23,
      59,
      59,
    );
    final startDate = endDate.subtract(Duration(days: periodDays));

    // Map aggregation string to AggregationLevel
    // 1D = hourly (24 bars), 7D/30D = daily (7/30 bars)
    final aggregationLevel = _aggregation == '1D'
        ? AggregationLevel.hourly
        : (_aggregation == '7D' ? AggregationLevel.daily : AggregationLevel.daily);

    // Use lastResetTime filter when "Since Last Reset" is selected
    final sinceResetTime = _showSinceReset ? widget.lastResetTime : null;

    if (_showCumulative) {
      return LoadCumulativeChart(
        startDate: startDate,
        endDate: endDate,
        aggregationLevel: aggregationLevel,
        itemId: widget.itemId,
        sinceResetTime: sinceResetTime,
      );
    } else {
      return LoadBarChart(
        startDate: startDate,
        endDate: endDate,
        aggregationLevel: aggregationLevel,
        itemId: widget.itemId,
        sinceResetTime: sinceResetTime,
      );
    }
  }

  /// Reload the chart based on current settings.
  void _reloadChart(BuildContext context) {
    context.read<ChartsBloc>().add(_createChartEvent());
  }

  /// Returns human-readable period label for the current aggregation.
  String _getPeriodLabel() {
    switch (_aggregation) {
      case '1D':
        return 'Today';
      case '7D':
        return 'Last 7 days';
      case '30D':
        return 'Last 30 days';
      default:
        return _aggregation;
    }
  }
}

/// Delegate for the sticky filter header.
///
/// When pinned (scrolled), shows a flat background matching the filtered zone.
/// When not pinned (at rest), shows the rounded top corners.
class _StickyFilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double maxHeight;
  final double minHeight;
  final Color backgroundColor;

  _StickyFilterHeaderDelegate({
    required this.child,
    required this.maxHeight,
    required this.minHeight,
    required this.backgroundColor,
  });

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    // When pinned (shrinkOffset > 0), use flat background
    // When at rest, show the child with rounded corners
    final isPinned = shrinkOffset > 0;

    if (isPinned) {
      // Pinned state: flat background, no rounded corners
      return Container(
        color: backgroundColor,
        child: child is Container
            ? Container(
                color: backgroundColor,
                padding: (child as Container).padding,
                child: (child as Container).child,
              )
            : child,
      );
    }

    return SizedBox.expand(child: child);
  }

  @override
  double get maxExtent => maxHeight;

  @override
  double get minExtent => minHeight;

  @override
  bool shouldRebuild(covariant _StickyFilterHeaderDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child ||
        backgroundColor != oldDelegate.backgroundColor;
  }
}
