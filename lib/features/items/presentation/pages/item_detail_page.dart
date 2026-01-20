import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../bluetooth/domain/entities/ble_message.dart';
import '../../../bluetooth/presentation/bloc/bluetooth_bloc.dart';
import '../../../bluetooth/presentation/bloc/bluetooth_state.dart';
import '../../../charts/domain/entities/chart_data.dart';
import '../../../charts/presentation/bloc/charts_bloc.dart';
import '../../../charts/presentation/bloc/charts_event.dart';
import '../../../events/domain/entities/event_log.dart';
import '../../../events/presentation/bloc/events_bloc.dart';
import '../../../events/presentation/bloc/events_event.dart';
import '../../../events/presentation/bloc/events_state.dart';
import '../../domain/entities/item.dart';
import '../../domain/repositories/item_repository.dart';
import '../../domain/utils/interval_calculator.dart';
import '../../domain/utils/stats_calculator.dart';
import '../widgets/item_detail/filter_section.dart';
import '../widgets/item_detail/period_stats_section.dart';
import '../widgets/item_detail/periods_table.dart';
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

  /// Value for the reminder (target count or interval).
  final int? reminderValue;

  /// Current reset number for this item.
  final int? resetNumber;

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
    this.reminderValue,
    this.resetNumber,
  });

  @override
  State<ItemDetailPage> createState() => _ItemDetailPageState();
}

class _ItemDetailPageState extends State<ItemDetailPage> {
  // Filter state
  String _aggregation = '1D';
  DateTime _selectedDate = DateTime.now();

  /// Selected interval number (-1 = All Time, 0+ = specific interval).
  /// Defaults to current interval (will be set when events load).
  int? _selectedInterval;

  // UI state
  bool _showCumulative = false;
  DateTime _lastUpdated = DateTime.now();

  /// Cached interval data from events.
  List<IntervalData> _intervals = [];

  // Mutable item data (initialized from widget, updated on refresh)
  late int _currentCount;
  late int _initialCount;
  int? _goal;
  late int _incrementBy;
  late ReminderType _reminderType;
  late int _reminderValue;
  late int _resetNumber;

  /// Flag to trigger data reload after widget update.
  bool _needsDataReload = false;

  @override
  void initState() {
    super.initState();
    // Initialize mutable state from widget parameters
    _currentCount = widget.currentCount ?? 0;
    _initialCount = widget.initialCount ?? 0;
    _goal = widget.goal;
    _incrementBy = widget.incrementBy ?? 1;
    _reminderType = widget.reminderType ?? ReminderType.none;
    _reminderValue = widget.reminderValue ?? 0;
    _resetNumber = widget.resetNumber ?? 0;
  }

  @override
  void didUpdateWidget(ItemDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Detect if any item data changed (e.g., from BLE sync or after editing)
    final dataChanged = oldWidget.currentCount != widget.currentCount ||
        oldWidget.resetNumber != widget.resetNumber ||
        oldWidget.itemName != widget.itemName ||
        oldWidget.goal != widget.goal ||
        oldWidget.incrementBy != widget.incrementBy ||
        oldWidget.initialCount != widget.initialCount;

    if (dataChanged) {
      // Update local state
      _currentCount = widget.currentCount ?? 0;
      _initialCount = widget.initialCount ?? 0;
      _goal = widget.goal;
      _incrementBy = widget.incrementBy ?? 1;
      _reminderType = widget.reminderType ?? ReminderType.none;
      _reminderValue = widget.reminderValue ?? 0;
      _resetNumber = widget.resetNumber ?? 0;
      // Flag for reload (will be handled in build via post-frame callback)
      _needsDataReload = true;
    }
  }

  /// Refresh item data, events, and chart.
  Future<void> _onRefresh(BuildContext context) async {
    // Capture blocs before async gap
    final eventsBloc = context.read<EventsBloc>();
    final chartsBloc = context.read<ChartsBloc>();

    // Fetch latest item data from database
    final itemRepository = sl<ItemRepository>();
    final result = await itemRepository.getItem(widget.itemId);

    if (!mounted) return;

    result.fold(
      (failure) {
        // Silently fail - keep existing data
      },
      (item) {
        setState(() {
          _currentCount = item.count;
          _initialCount = item.initialCount;
          _goal = item.goal;
          _incrementBy = item.incrementBy;
          _reminderType = item.reminder;
          _reminderValue = item.reminderValue;
          _resetNumber = item.resetNumber;
        });
      },
    );

    // Reload events from database
    eventsBloc.add(LoadEvents(itemId: widget.itemId));
    // Reload chart data
    chartsBloc.add(_createChartEvent());
    // Update timestamp
    setState(() {
      _lastUpdated = DateTime.now();
    });
    // Wait a brief moment for the UI to update
    await Future.delayed(const Duration(milliseconds: 300));
  }

  /// Format the last updated time as a relative or absolute string.
  String _formatLastUpdated() {
    final now = DateTime.now();
    final diff = now.difference(_lastUpdated);

    if (diff.inSeconds < 10) {
      return 'Just now';
    } else if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else {
      // Show time if more than an hour
      final hour = _lastUpdated.hour;
      final minute = _lastUpdated.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '$hour12:$minute $period';
    }
  }

  /// Update intervals when events are loaded.
  void _updateIntervalsFromEvents(EventsState eventsState) {
    if (eventsState is EventsLoaded) {
      var newIntervals = IntervalCalculator.calculate(
        events: eventsState.events,
        maxIntervals: 100, // Get all for dropdown
      );

      // Check if the item has a higher resetNumber than any event
      // This happens right after a reset - the new period has no events yet
      final maxEventResetNumber = newIntervals
          .where((i) => i.intervalNumber >= 0)
          .map((i) => i.intervalNumber)
          .fold<int>(-1, (max, n) => n > max ? n : max);

      if (_resetNumber > maxEventResetNumber) {
        // Create a virtual current interval for the new period (no events yet)
        final virtualCurrentInterval = IntervalData(
          intervalNumber: _resetNumber,
          count: 0,
          startTime: widget.lastResetTime ?? DateTime.now(),
          endTime: null, // Current period
        );

        // Insert after "All Time" (index 0) as the new current period
        if (newIntervals.isNotEmpty) {
          newIntervals = [
            newIntervals.first, // All Time
            virtualCurrentInterval,
            ...newIntervals.skip(1), // Previous intervals
          ];
        } else {
          // No intervals at all - create All Time and current
          final allTimeInterval = IntervalData(
            intervalNumber: -1,
            count: 0,
            startTime: widget.lastResetTime ?? DateTime.now(),
            endTime: null,
          );
          newIntervals = [allTimeInterval, virtualCurrentInterval];
        }
      }

      // Get the current interval number (most recent, after "All Time")
      final currentIntervalNumber = newIntervals.length > 1
          ? newIntervals[1].intervalNumber
          : null;

      // Check what the old current interval was (before this update)
      final oldCurrentIntervalNumber = _intervals.length > 1
          ? _intervals[1].intervalNumber
          : null;

      setState(() {
        _intervals = newIntervals;

        // Update selected interval if:
        // 1. Not set yet
        if (_selectedInterval == null) {
          _selectedInterval = currentIntervalNumber;
        }
        // 2. Selected interval no longer exists in new intervals
        else if (_selectedInterval != -1 &&
            !newIntervals.any((i) => i.intervalNumber == _selectedInterval)) {
          _selectedInterval = currentIntervalNumber;
        }
        // 3. A new current interval appeared (reset happened) and we were viewing current
        else if (_selectedInterval != -1 &&
            currentIntervalNumber != null &&
            oldCurrentIntervalNumber != null &&
            currentIntervalNumber > oldCurrentIntervalNumber &&
            _selectedInterval == oldCurrentIntervalNumber) {
          // We were viewing the current interval and a reset created a new one
          _selectedInterval = currentIntervalNumber;
        }
      });
    }
  }

  /// Handle interval selection - auto-snap date and reload chart.
  void _onIntervalSelected(int intervalNumber, BuildContext context) {
    setState(() {
      _selectedInterval = intervalNumber;
    });

    // Auto-snap date to interval's end date
    if (intervalNumber == -1) {
      // All Time - snap to today
      setState(() {
        _selectedDate = DateTime.now();
      });
    } else {
      // Find the interval data
      final interval = _intervals.firstWhere(
        (i) => i.intervalNumber == intervalNumber,
        orElse: () => _intervals.first,
      );
      // Snap to end date (reset time) or today if current
      final snapDate = interval.endTime ?? DateTime.now();
      setState(() {
        _selectedDate = snapDate;
      });
    }

    _reloadChart(context);
  }

  /// Filter events by selected interval.
  List<EventLog> _filterEventsByInterval(List<EventLog> events) {
    if (_selectedInterval == null || _selectedInterval == -1) {
      // All Time - no filtering
      return events;
    }
    // Filter by resetNumber
    return events
        .where((e) => e.resetNumber == _selectedInterval)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primaryBackground = AppColors.primaryBackground(brightness);
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final alternate = AppColors.alternate(brightness);
    final primary = AppColors.primaryAdaptive(brightness);

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => sl<EventsBloc>()..add(LoadEvents(itemId: widget.itemId)),
        ),
        BlocProvider(
          create: (_) => sl<ChartsBloc>()..add(_createChartEvent()),
        ),
      ],
      child: BlocListener<BluetoothBloc, BluetoothState>(
        listener: (context, state) {
          // Listen for delta messages that affect the current item
          final message = state.lastMessage;
          if (message != null && message.type == BleMessageType.itemDelta) {
            // Extract item ID from delta message data
            final data = message.data;
            final deltaItemId = data is Map ? data['id']?.toString() : null;
            if (deltaItemId == widget.itemId) {
              // Device sent a delta update for this item - refresh to get latest data
              debugPrint('📱 Delta received for current item, refreshing...');
              _onRefresh(context);
            }
          }
        },
        child: BlocListener<EventsBloc, EventsState>(
          listener: (context, state) {
            _updateIntervalsFromEvents(state);
            if (state is EventsLoaded) {
              // Always reload chart when events are loaded to ensure sync
              _reloadChart(context);
            }
          },
          child: Builder(
          builder: (context) {
            // Handle deferred data reload after widget update (e.g., BLE sync)
            if (_needsDataReload) {
              _needsDataReload = false;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  // Reload events - chart will be reloaded by BlocListener
                  context.read<EventsBloc>().add(LoadEvents(itemId: widget.itemId));
                }
              });
            }
            return GestureDetector(
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
              child: RefreshIndicator(
                onRefresh: () => _onRefresh(context),
                color: primary,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                  // Last updated indicator at top
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
                      child: Center(
                        child: Text(
                          'Updated ${_formatLastUpdated()} \u2022 Pull to refresh',
                          style: GoogleFonts.inter(
                            fontSize: 11.0,
                            color: secondaryText.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Static Header (Current Count, Initial, Goal)
                  // Now updates on refresh
                  SliverToBoxAdapter(
                    child: StaticHeader(
                      currentCount: _currentCount,
                      initialCount: _initialCount,
                      goal: _goal,
                      incrementBy: _incrementBy,
                      reminderType: _reminderType,
                      reminderValue: _reminderValue,
                    ),
                  ),
                  // Gap between static header and filtered zone
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 24.0),
                  ),
                  // Sticky Filter Section (part of filtered zone)
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _StickyFilterHeaderDelegate(
                      backgroundColor: brightness == Brightness.light
                          ? const Color(0xFFF8F9FB)
                          : const Color(0xFF1C1C1E),
                      child: Container(
                        decoration: BoxDecoration(
                          color: brightness == Brightness.light
                              ? const Color(0xFFF8F9FB)
                              : const Color(0xFF1C1C1E),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(24.0),
                            topRight: Radius.circular(24.0),
                          ),
                          boxShadow: [
                            // Top shadow to separate from header section
                            BoxShadow(
                              color: brightness == Brightness.light
                                  ? Colors.black.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.4),
                              blurRadius: 12.0,
                              offset: const Offset(0, -6),
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 8.0),
                        child: FilterSection(
                          intervals: _intervals,
                          selectedInterval: _selectedInterval ?? -1,
                          onIntervalChanged: (interval) =>
                              _onIntervalSelected(interval, context),
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
                          : const Color(0xFF1C1C1E),
                      child: Column(
                        children: [
                          // Divider between filter and content
                          Container(
                            height: 1.0,
                            margin: const EdgeInsets.symmetric(horizontal: 20.0),
                            color: secondaryText.withValues(alpha: 0.12),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 24.0),
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

                                // Filter events by selected interval
                                final filteredEvents = eventsState is EventsLoaded
                                    ? _filterEventsByInterval(eventsState.events)
                                    : <EventLog>[];
                                final stats = _calculateStats(filteredEvents);
                                // Get the selected interval data for period stats
                                // For "All Time" (-1), use the first interval which is the Total row
                                // For specific intervals, find the matching one
                                // Create fallback for newly created items with no events
                                final fallbackInterval = IntervalData(
                                  intervalNumber: -1,
                                  count: 0,
                                  startTime: widget.lastResetTime ?? DateTime.now(),
                                  endTime: null,
                                );
                                final selectedIntervalData = _intervals.isNotEmpty
                                    ? _intervals.firstWhere(
                                        (i) => i.intervalNumber == (_selectedInterval ?? -1),
                                        orElse: () => _intervals.first,
                                      )
                                    : fallbackInterval;

                                // Use intervals or create fallback list for table
                                final displayIntervals = _intervals.isNotEmpty
                                    ? _intervals
                                    : [fallbackInterval];

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Summary card (total + time range)
                                    PeriodStatsSection(
                                      interval: selectedIntervalData,
                                      initialCount: widget.initialCount ?? 0,
                                    ),
                                    const SizedBox(height: 16.0),
                                    // Chart Section
                                    Container(
                                      decoration: BoxDecoration(
                                        color: alternate,
                                        borderRadius: BorderRadius.circular(12.0),
                                        border: Border.all(
                                          color: primary.withValues(alpha: 0.1),
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
                                        onAggregationChanged: (value) {
                                          setState(() {
                                            _aggregation = value;
                                          });
                                          _reloadChart(context);
                                        },
                                        selectedDate: _selectedDate,
                                        onDateChanged: (date) {
                                          setState(() {
                                            _selectedDate = date;
                                          });
                                          _reloadChart(context);
                                        },
                                        periodTotal: stats.totalCount,
                                        percentChange: stats.percentChange,
                                        priorPeriodCount: stats.priorPeriodCount,
                                        periodLabel: stats.periodLabel,
                                      ),
                                    ),
                                    // Periods comparison table
                                    const SizedBox(height: 16.0),
                                    PeriodsTable(
                                      intervals: displayIntervals,
                                      selectedInterval: _selectedInterval ?? -1,
                                      onIntervalSelected: (interval) =>
                                          _onIntervalSelected(interval, context),
                                      initialCount: widget.initialCount ?? 0,
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                ),
              ),
            ),
          ),
        );
      },
        ),
        ),
      ),
    );
  }

  /// Calculate statistics from filtered events.
  StatsResult _calculateStats(List<EventLog> events) {
    if (events.isEmpty) {
      // Return empty stats if no events
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
    return StatsCalculator.calculate(
      events: events,
      aggregation: _aggregation,
      endDate: _selectedDate,
      lastResetTime: null, // No longer using lastResetTime filter
      sinceResetOnly: false, // Interval filtering handles this now
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

    // Get the interval's boundaries for filtering (if specific interval selected)
    DateTime? sinceResetTime;
    DateTime? untilResetTime;
    if (_selectedInterval != null && _selectedInterval! >= 0) {
      final interval = _intervals.firstWhere(
        (i) => i.intervalNumber == _selectedInterval,
        orElse: () => _intervals.first,
      );
      sinceResetTime = interval.startTime;
      // Only set end time for completed (non-current) intervals
      if (!interval.isCurrent && interval.endTime != null) {
        untilResetTime = interval.endTime;
      }
    }

    if (_showCumulative) {
      return LoadCumulativeChart(
        startDate: startDate,
        endDate: endDate,
        aggregationLevel: aggregationLevel,
        itemId: widget.itemId,
        sinceResetTime: sinceResetTime,
        untilResetTime: untilResetTime,
      );
    } else {
      return LoadBarChart(
        startDate: startDate,
        endDate: endDate,
        aggregationLevel: aggregationLevel,
        itemId: widget.itemId,
        sinceResetTime: sinceResetTime,
        untilResetTime: untilResetTime,
      );
    }
  }

  /// Reload the chart based on current settings.
  void _reloadChart(BuildContext context) {
    context.read<ChartsBloc>().add(_createChartEvent());
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
