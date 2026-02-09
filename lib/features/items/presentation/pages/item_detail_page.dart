import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/logger.dart';
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
import '../widgets/item_detail/cycle_selection_bottom_sheet.dart';
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

  /// Timestamp when the item was last updated (used as creation time fallback).
  final DateTime? lastUpdated;

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
    this.lastUpdated,
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
  DateTime? _lastResetTime;

  /// User-defined cycle names.
  Map<String, String> _cycleNames = {};

  /// Flag to trigger data reload after widget update.
  bool _needsDataReload = false;

  /// Whether viewing the current (most recent) cycle.
  /// All Time (-1) is NOT considered current — it's a summary view.
  bool get _isViewingCurrentCycle {
    if (_selectedInterval == null) return true;
    if (_selectedInterval == -1) return false;
    if (_intervals.length > 1) {
      return _selectedInterval == _intervals[1].intervalNumber;
    }
    return true;
  }

  /// Whether viewing first cycle (All Time or Period 0).
  /// Initial count is only included in charts for the first cycle.
  bool get _isFirstCycle =>
      _selectedInterval == null || _selectedInterval == -1 || _selectedInterval == 0;

  /// Stream subscription for Bluetooth logs.
  StreamSubscription<BluetoothState>? _bluetoothSubscription;

  /// Blocs created in initState for access from stream subscription.
  late final EventsBloc _eventsBloc;
  late final ChartsBloc _chartsBloc;

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
    _lastResetTime = widget.lastResetTime;

    // Create blocs
    _eventsBloc = sl<EventsBloc>()..add(LoadEvents(itemId: widget.itemId));
    _chartsBloc = sl<ChartsBloc>()..add(_createChartEvent());

    // Note: We intentionally don't subscribe to real-time item updates here
    // to save power. The initial values are passed via widget parameters.
    // Charts and events are loaded separately via their blocs.

    // Load cycle names from the item
    _loadCycleNames();

    // Subscribe to Bluetooth logs - reload events when logs sync completes
    _subscribeToBluetoothLogs();

    // Reload events after delay if device is connected (catches recently synced logs)
    _reloadIfConnected();
  }

  /// Load cycle names from the item in Firestore.
  Future<void> _loadCycleNames() async {
    final result = await sl<ItemRepository>().getItem(widget.itemId);
    if (!mounted) return;
    result.fold(
      (_) {},
      (item) {
        if (item.cycleNames.isNotEmpty) {
          setState(() {
            _cycleNames = Map<String, String>.from(item.cycleNames);
          });
        }
      },
    );
  }

  /// Reload events if device is connected (to catch recently synced data).
  void _reloadIfConnected() {
    try {
      final bluetoothBloc = sl<BluetoothBloc>();
      if (bluetoothBloc.state.isConnected) {
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) {
            _eventsBloc.add(LoadEvents(itemId: widget.itemId));
          }
        });
      }
    } catch (e) {
      AppLogger.debug('BluetoothBloc not available for reload: $e');
    }
  }

  /// Subscribe to Bluetooth state to detect when logs are synced.
  void _subscribeToBluetoothLogs() {
    try {
      final bluetoothBloc = sl<BluetoothBloc>();
      _bluetoothSubscription = bluetoothBloc.stream.listen((state) {
        final lastMessage = state.lastMessage;

        // Reload events when logs sync completes (final page received)
        if (lastMessage?.type == BleMessageType.logs && !state.hasMoreLogs) {
          // Delay to allow Firestore write to complete
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _eventsBloc.add(LoadEvents(itemId: widget.itemId));
              setState(() {
                _lastUpdated = DateTime.now();
              });
            }
          });
        }
      });
    } catch (e) {
      AppLogger.debug('BluetoothBloc not available for log subscription: $e');
    }
  }

  @override
  void dispose() {
    _bluetoothSubscription?.cancel();
    _eventsBloc.close();
    _chartsBloc.close();
    super.dispose();
  }

  @override
  void didUpdateWidget(ItemDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Detect if any item data changed (e.g., from BLE sync or after editing)
    final dataChanged = oldWidget.currentCount != widget.currentCount ||
        oldWidget.resetNumber != widget.resetNumber ||
        oldWidget.lastResetTime != widget.lastResetTime ||
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
      _lastResetTime = widget.lastResetTime;
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
          _lastResetTime = item.lastResetTime;
          _cycleNames = Map<String, String>.from(item.cycleNames);
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
        // Fallback start time: lastResetTime (if reset), or lastUpdated (creation time), or now
        final fallbackStart = _lastResetTime ?? widget.lastUpdated ?? DateTime.now();

        // Create a virtual current interval for the new period (no events yet)
        final virtualCurrentInterval = IntervalData(
          intervalNumber: _resetNumber,
          count: 0,
          startTime: fallbackStart,
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
            startTime: fallbackStart,
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

  /// Get the display label for the currently selected cycle.
  String _getSelectedCycleLabel() {
    if (_selectedInterval == null || _selectedInterval == -1) return 'All Time';
    final periods = _intervals.where((i) => i.intervalNumber >= 0).toList();
    final totalPeriods = periods.length;
    final index = periods.indexWhere(
      (i) => i.intervalNumber == _selectedInterval,
    );
    if (index < 0) return 'All Time';
    return getCycleDisplayName(
      _selectedInterval!,
      index,
      totalPeriods,
      _cycleNames,
    );
  }

  /// Get the count for the selected interval.
  int _getSelectedCycleCount() {
    if (_selectedInterval == null) return _currentCount;
    if (_intervals.isEmpty) return _currentCount;
    if (_selectedInterval == -1) {
      // All Time: total increments across all cycles + initial count
      final allTime = _intervals.firstWhere(
        (i) => i.intervalNumber == -1,
        orElse: () => _intervals.first,
      );
      return allTime.count + _initialCount;
    }
    final interval = _intervals.firstWhere(
      (i) => i.intervalNumber == _selectedInterval,
      orElse: () => _intervals.first,
    );
    // First cycle (lowest intervalNumber) includes initial count
    final periods = _intervals.where((i) => i.intervalNumber >= 0);
    final firstIntervalNumber = periods.isNotEmpty
        ? periods.map((p) => p.intervalNumber).reduce((a, b) => a < b ? a : b)
        : -1;
    if (interval.intervalNumber == firstIntervalNumber && _initialCount > 0) {
      return interval.count + _initialCount;
    }
    return interval.count;
  }

  /// Show the cycle selection bottom sheet.
  void _showCycleSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CycleSelectionBottomSheet(
        intervals: _intervals,
        selectedInterval: _selectedInterval ?? -1,
        cycleNames: _cycleNames,
        onIntervalSelected: (interval) =>
            _onIntervalSelected(interval, context),
        onCycleRenamed: _onCycleRenamed,
      ),
    );
  }

  /// Handle cycle rename from bottom sheet.
  Future<void> _onCycleRenamed(int resetNumber, String newName) async {
    final updated = Map<String, String>.from(_cycleNames);
    if (newName.isEmpty) {
      updated.remove(resetNumber.toString());
    } else {
      updated[resetNumber.toString()] = newName;
    }
    setState(() {
      _cycleNames = updated;
    });
    await sl<ItemRepository>().updateCycleNames(widget.itemId, updated);
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
        BlocProvider.value(value: _eventsBloc),
        BlocProvider.value(value: _chartsBloc),
      ],
      child: BlocListener<EventsBloc, EventsState>(
        listener: (context, state) {
          _updateIntervalsFromEvents(state);
          if (state is EventsLoaded) {
            // Reload chart when events are loaded to ensure sync
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
                  _eventsBloc.add(LoadEvents(itemId: widget.itemId));
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
                tooltip: 'Back',
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: primaryText,
                  size: 30.0,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Text(
                widget.itemName ?? 'None',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: primaryText,
                  fontWeight: FontWeight.w600,
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
                  // Last updated indicator + cycle chip
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
                      child: Column(
                        children: [
                          Center(
                            child: Text(
                              'Updated ${_formatLastUpdated()} \u2022 Pull to refresh',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontSize: 11.0,
                                color: secondaryText.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8.0),
                          // Cycle selector chip
                          Center(
                            child: Semantics(
                              label: 'Select cycle period',
                              button: true,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20.0),
                                  onTap: () => _showCycleSelector(context),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14.0,
                                      vertical: 8.0,
                                    ),
                                    decoration: BoxDecoration(
                                      color: primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20.0),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.filter_list_rounded,
                                          size: 16.0,
                                          color: primary,
                                        ),
                                        const SizedBox(width: 6.0),
                                        Text(
                                          _getSelectedCycleLabel(),
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            fontSize: 13.0,
                                            fontWeight: FontWeight.w600,
                                            color: primary,
                                          ),
                                        ),
                                        const SizedBox(width: 4.0),
                                        Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          size: 18.0,
                                          color: primary,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Static Header (Current Count, Initial, Goal)
                  // Cycle-aware: grayed ring for non-current cycles
                  SliverToBoxAdapter(
                    child: StaticHeader(
                      currentCount: _currentCount,
                      initialCount: _initialCount,
                      goal: _goal,
                      incrementBy: _incrementBy,
                      reminderType: _reminderType,
                      reminderValue: _reminderValue,
                      resetNumber: _resetNumber,
                      isCurrentCycle: _isViewingCurrentCycle,
                      isAllTime: _selectedInterval == -1,
                      selectedCycleCount: _getSelectedCycleCount(),
                    ),
                  ),
                  // Gap between static header and content zone
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 16.0),
                  ),
                  // Filtered Content Zone
                  // ALL content below is affected by cycle selection
                  SliverToBoxAdapter(
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
                      child: Column(
                        children: [
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
                                  startTime: _lastResetTime ?? DateTime.now(),
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
                                        // Only show initial count in first cycle (All Time or Period 0)
                                        initialCount: _isFirstCycle ? (widget.initialCount ?? 0) : 0,
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
                                      cycleNames: _cycleNames,
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
        isFirstCycle: _isFirstCycle,
      );
    } else {
      return LoadBarChart(
        startDate: startDate,
        endDate: endDate,
        aggregationLevel: aggregationLevel,
        itemId: widget.itemId,
        sinceResetTime: sinceResetTime,
        untilResetTime: untilResetTime,
        isFirstCycle: _isFirstCycle,
      );
    }
  }

  /// Reload the chart based on current settings.
  void _reloadChart(BuildContext context) {
    _chartsBloc.add(_createChartEvent());
  }
}
