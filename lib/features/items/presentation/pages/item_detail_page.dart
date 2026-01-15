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
/// - Filter section with aggregation, reset toggle, and date picker
/// - Stats section with chart toggle and chart display
/// - Summary cards showing current count and average
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
  bool _isCalendarCollapsed = true;

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
          appBar: AppBar(
            backgroundColor: _primaryBackground,
            automaticallyImplyLeading: false,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: _primaryText,
                size: 30.0,
              ),
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
                icon: const Icon(
                  Icons.refresh,
                  color: _primaryText,
                ),
                tooltip: 'Refresh',
                onPressed: () => _refreshData(context),
              ),
            ],
            centerTitle: true,
            elevation: 2.0,
          ),
          body: SafeArea(
            top: true,
            child: RefreshIndicator(
              color: _primary,
              onRefresh: () async => _refreshData(context),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20.0, 24.0, 20.0, 32.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilterSection(
                        aggregation: _aggregation,
                        showSinceReset: _showSinceReset,
                        selectedDate: _selectedDate,
                        isCalendarCollapsed: _isCalendarCollapsed,
                        onAggregationChanged: (value) {
                          setState(() {
                            _aggregation = value;
                          });
                          _reloadChart(context);
                        },
                        onShowSinceResetChanged: (value) {
                          setState(() {
                            _showSinceReset = value;
                          });
                        },
                        onDateChanged: (date) {
                          setState(() {
                            _selectedDate = date;
                          });
                          _reloadChart(context);
                        },
                        onToggleCalendar: () {
                          setState(() {
                            _isCalendarCollapsed = !_isCalendarCollapsed;
                          });
                        },
                      ),
                      const SizedBox(height: 16.0),
                      BlocBuilder<EventsBloc, EventsState>(
                        builder: (context, eventsState) {
                          final stats = _calculateStats(eventsState);
                          return Column(
                            children: [
                              StatsSection(
                                stats: stats,
                                showCumulative: _showCumulative,
                                onChartTypeChanged: (value) {
                                  setState(() {
                                    _showCumulative = value;
                                  });
                                  _reloadChart(context);
                                },
                              ),
                              const SizedBox(height: 16.0),
                              SummaryCards(
                                currentCount: widget.currentCount ?? 0,
                                average: stats.average,
                              ),
                            ],
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
    final aggregationLevel = _aggregation == '1D'
        ? AggregationLevel.daily
        : (_aggregation == '7D' ? AggregationLevel.daily : AggregationLevel.weekly);

    if (_showCumulative) {
      return LoadCumulativeChart(
        startDate: startDate,
        endDate: endDate,
        itemId: widget.itemId,
      );
    } else {
      return LoadBarChart(
        startDate: startDate,
        endDate: endDate,
        aggregationLevel: aggregationLevel,
        itemId: widget.itemId,
      );
    }
  }

  /// Reload the chart based on current settings.
  void _reloadChart(BuildContext context) {
    context.read<ChartsBloc>().add(_createChartEvent());
  }

  void _refreshData(BuildContext context) {
    // Refresh events
    context.read<EventsBloc>().add(LoadEvents(itemId: widget.itemId));

    // Refresh charts
    _reloadChart(context);
  }
}
