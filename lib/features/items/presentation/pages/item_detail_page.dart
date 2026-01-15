import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/di/injection.dart';
import '../../../charts/domain/entities/chart_data.dart';
import '../../../charts/presentation/bloc/charts_bloc.dart';
import '../../../charts/presentation/bloc/charts_event.dart';
import '../../../events/presentation/bloc/events_bloc.dart';
import '../../../events/presentation/bloc/events_event.dart';
import '../widgets/bar_chart_widget.dart';
import '../widgets/cumulative_chart_widget.dart';
import '../widgets/date_range_selector.dart';
import '../widgets/event_log_list_widget.dart';

/// Page displaying detailed information about an item.
///
/// Shows:
/// - Item header with name and current count
/// - Date range selector for filtering
/// - Bar chart with daily/weekly/monthly aggregation
/// - Cumulative chart showing running total
/// - List of event logs
///
/// Integrates with EventsBloc and ChartsBloc for data management.
class ItemDetailPage extends StatelessWidget {
  static String routeName = 'ItemDetailPage';
  static String routePath = '/item-detail';

  // FF Colors
  static const Color _primary = Color(0xFF4B39EF);
  static const Color _alternate = Color(0xFFE0E3E7);
  static const Color _primaryBackground = Color(0xFFF1F4F8);
  static const Color _primaryText = Color(0xFF14181B);
  static const Color _secondaryText = Color(0xFF57636C);

  /// The ID of the item to display.
  final String itemId;

  /// Optional item name for the app bar.
  final String? itemName;

  const ItemDetailPage({
    super.key,
    required this.itemId,
    this.itemName,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate default date range (last 30 days)
    final now = DateTime.now();
    final endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final startDate = endDate.subtract(const Duration(days: 30));

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => sl<EventsBloc>()
            ..add(LoadEvents(itemId: itemId)),
        ),
        BlocProvider(
          create: (_) => sl<ChartsBloc>()
            ..add(LoadBarChart(
              startDate: startDate,
              endDate: endDate,
              aggregationLevel: AggregationLevel.daily,
              itemId: itemId,
            )),
        ),
      ],
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: _primaryBackground,
          appBar: AppBar(
            backgroundColor: _primaryBackground,
            automaticallyImplyLeading: false,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_rounded,
                color: _primaryText,
                size: 30.0,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              itemName ?? 'Item Details',
              style: GoogleFonts.interTight(
                color: _primaryText,
                fontWeight: FontWeight.w600,
                fontSize: 22.0,
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(
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
                  padding: const EdgeInsets.fromLTRB(20.0, 24.0, 20.0, 0.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Date Range Selector Card
                      Container(
                        decoration: BoxDecoration(
                          color: _alternate,
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Date Range',
                                style: GoogleFonts.interTight(
                                  color: _primaryText,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16.0,
                                ),
                              ),
                              const SizedBox(height: 12.0),
                              const DateRangeSelector(),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16.0),
                      // Bar Chart Card
                      Container(
                        decoration: BoxDecoration(
                          color: _alternate,
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Activity',
                                style: GoogleFonts.interTight(
                                  color: _primaryText,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16.0,
                                ),
                              ),
                              const SizedBox(height: 12.0),
                              const SizedBox(
                                height: 200,
                                child: BarChartWidget(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16.0),
                      // Cumulative Chart Card
                      Container(
                        decoration: BoxDecoration(
                          color: _alternate,
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cumulative Total',
                                style: GoogleFonts.interTight(
                                  color: _primaryText,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16.0,
                                ),
                              ),
                              const SizedBox(height: 12.0),
                              const SizedBox(
                                height: 200,
                                child: CumulativeChartWidget(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16.0),
                      // Event Log Card
                      Container(
                        decoration: BoxDecoration(
                          color: _alternate,
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Event Log',
                                style: GoogleFonts.interTight(
                                  color: _primaryText,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16.0,
                                ),
                              ),
                              const SizedBox(height: 12.0),
                              const EventLogListWidget(),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32), // Bottom padding
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

  void _refreshData(BuildContext context) {
    // Refresh events
    context.read<EventsBloc>().add(LoadEvents(itemId: itemId));

    // Refresh charts
    context.read<ChartsBloc>().add(const RefreshChart());
  }
}

/// Simplified version of ItemDetailPage for use in navigation.
///
/// Use this when navigating from a list and you have all the info.
class ItemDetailPageRoute extends StatelessWidget {
  final String itemId;
  final String itemName;

  const ItemDetailPageRoute({
    super.key,
    required this.itemId,
    required this.itemName,
  });

  @override
  Widget build(BuildContext context) {
    return ItemDetailPage(
      itemId: itemId,
      itemName: itemName,
    );
  }
}
