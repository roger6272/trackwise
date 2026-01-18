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
import '../../domain/utils/stats_calculator.dart';
import '../widgets/item_detail/filter_section.dart';
import '../widgets/item_detail/shimmer_skeletons.dart';
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

  /// Initial count when the item was created.
  final int? initialCount;

  /// Target goal for this item.
  final int? goal;

  const ItemDetailPage({
    super.key,
    required this.itemId,
    this.itemName,
    this.currentCount,
    this.lastResetTime,
    this.initialCount,
    this.goal,
  });

  @override
  State<ItemDetailPage> createState() => _ItemDetailPageState();
}

class _ItemDetailPageState extends State<ItemDetailPage> {
  // Filter state
  String _aggregation = '1D';
  bool _showSinceReset = false;
  DateTime _selectedDate = DateTime.now();

  // UI state
  bool _showCumulative = false;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primaryBackground = AppColors.primaryBackground(brightness);
    final primaryText = AppColors.primaryText(brightness);
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
                  // Sticky Filter Section
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _StickyFilterHeaderDelegate(
                      child: Container(
                        color: primaryBackground,
                        padding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 8.0),
                        child: FilterSection(
                          aggregation: _aggregation,
                          showSinceReset: _showSinceReset,
                          selectedDate: _selectedDate,
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
                      maxHeight: 130.0,
                      minHeight: 130.0,
                    ),
                  ),
                  // Stats and Summary Content
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 0.0),
                    sliver: SliverToBoxAdapter(
                      child: BlocBuilder<EventsBloc, EventsState>(
                        builder: (context, eventsState) {
                          // Show shimmer skeleton while loading
                          if (eventsState is EventsLoading) {
                            return const Column(
                              children: [
                                StatsSectionSkeleton(),
                                SizedBox(height: 16.0),
                                SummaryCardsSkeleton(),
                                SizedBox(height: 24.0),
                              ],
                            );
                          }

                          final stats = _calculateStats(eventsState);
                          return Column(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: alternate,
                                  borderRadius: BorderRadius.circular(12.0),
                                  border: Border.all(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    width: 1.0,
                                  ),
                                ),
                                child: StatsSection(
                                  stats: stats,
                                  showCumulative: _showCumulative,
                                  onChartTypeChanged: (value) {
                                    setState(() {
                                      _showCumulative = value;
                                    });
                                    _reloadChart(context);
                                  },
                                  range: _aggregation,
                                  selectedDate: _selectedDate,
                                ),
                              ),
                              const SizedBox(height: 16.0),
                              // Summary Cards - separate section
                              SummaryCards(
                                currentCount: widget.currentCount ?? 0,
                                average: stats.average,
                                highestCount: stats.maxCount,
                                lowestCount: stats.minCount,
                                initialCount: widget.initialCount ?? 0,
                                goal: widget.goal,
                              ),
                              const SizedBox(height: 24.0),
                            ],
                          );
                        },
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
}

/// Delegate for the sticky filter header.
class _StickyFilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double maxHeight;
  final double minHeight;

  _StickyFilterHeaderDelegate({
    required this.child,
    required this.maxHeight,
    required this.minHeight,
  });

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
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
        child != oldDelegate.child;
  }
}
