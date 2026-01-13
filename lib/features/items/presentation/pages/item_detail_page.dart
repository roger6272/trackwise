import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
          appBar: AppBar(
            title: Text(itemName ?? 'Item Details'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: () => _refreshData(context),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async => _refreshData(context),
            child: const SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DateRangeSelector(),
                BarChartWidget(),
                CumulativeChartWidget(),
                EventLogListWidget(),
                SizedBox(height: 32), // Bottom padding
              ],
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
