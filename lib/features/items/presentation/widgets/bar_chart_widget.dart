import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../charts/domain/entities/chart_data.dart';
import '../../../charts/presentation/bloc/charts_bloc.dart';
import '../../../charts/presentation/bloc/charts_event.dart';
import '../../../charts/presentation/bloc/charts_state.dart';

/// Bar chart widget displaying aggregated event data.
///
/// Uses fl_chart to render professional-looking bar charts.
/// Supports daily, weekly, and monthly aggregation.
class BarChartWidget extends StatelessWidget {
  const BarChartWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChartsBloc, ChartsState>(
      buildWhen: (previous, current) {
        // Only rebuild for bar chart states
        if (current is ChartsLoaded) {
          return current.isBarChart;
        }
        return true;
      },
      builder: (context, state) {
        if (state is ChartsLoading) {
          return const _ChartContainer(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (state is ChartsError) {
          return _ChartContainer(
            child: Center(
              child: Text(
                'Error: ${state.message}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          );
        }

        if (state is ChartsLoaded && state.isBarChart) {
          if (state.chartData.isEmpty) {
            return const _ChartContainer(
              child: Center(child: Text('No data for selected range')),
            );
          }

          return _ChartContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ChartHeader(state: state),
                const SizedBox(height: 16),
                Expanded(
                  child: _BarChartContent(chartData: state.chartData),
                ),
              ],
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}

/// Container for chart with consistent styling.
class _ChartContainer extends StatelessWidget {
  final Widget child;

  const _ChartContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 320,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Header with title and aggregation level selector.
class _ChartHeader extends StatelessWidget {
  final ChartsLoaded state;

  const _ChartHeader({required this.state});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Activity',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              'Total: ${state.chartData.totalValue}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ],
        ),
        _AggregationSelector(currentLevel: state.aggregationLevel),
      ],
    );
  }
}

/// Dropdown to select aggregation level.
class _AggregationSelector extends StatelessWidget {
  final AggregationLevel currentLevel;

  const _AggregationSelector({required this.currentLevel});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<AggregationLevel>(
      segments: const [
        ButtonSegment(
          value: AggregationLevel.daily,
          label: Text('D'),
          tooltip: 'Daily',
        ),
        ButtonSegment(
          value: AggregationLevel.weekly,
          label: Text('W'),
          tooltip: 'Weekly',
        ),
        ButtonSegment(
          value: AggregationLevel.monthly,
          label: Text('M'),
          tooltip: 'Monthly',
        ),
      ],
      selected: {currentLevel},
      showSelectedIcon: false,
      onSelectionChanged: (selection) {
        context.read<ChartsBloc>().add(
              ChangeAggregationLevel(selection.first),
            );
      },
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

/// The actual bar chart using fl_chart.
class _BarChartContent extends StatelessWidget {
  final ChartData chartData;

  const _BarChartContent({required this.chartData});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final maxY = chartData.maxValue.toDouble() * 1.2; // Add 20% padding

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY > 0 ? maxY : 10,
        minY: 0,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: colorScheme.inverseSurface,
            tooltipPadding: const EdgeInsets.all(8),
            tooltipMargin: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final dataPoint = chartData.dataPoints[group.x.toInt()];
              final dateStr = _formatDate(dataPoint.date, chartData.aggregationLevel);
              return BarTooltipItem(
                '$dateStr\n${dataPoint.value}',
                TextStyle(
                  color: colorScheme.onInverseSurface,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                if (value == meta.max || value == meta.min) {
                  return const SizedBox.shrink();
                }
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= chartData.dataPoints.length) {
                  return const SizedBox.shrink();
                }

                // Show fewer labels if many data points
                final showEvery = chartData.count > 14
                    ? (chartData.count / 7).ceil()
                    : chartData.count > 7
                        ? 2
                        : 1;

                if (index % showEvery != 0) {
                  return const SizedBox.shrink();
                }

                final date = chartData.dataPoints[index].date;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _formatAxisLabel(date, chartData.aggregationLevel),
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY > 0 ? maxY / 4 : 2.5,
          getDrawingHorizontalLine: (value) => FlLine(
            color: colorScheme.outlineVariant.withOpacity(0.5),
            strokeWidth: 1,
          ),
        ),
        barGroups: chartData.dataPoints.asMap().entries.map((entry) {
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: entry.value.value.toDouble(),
                color: colorScheme.primary,
                width: _calculateBarWidth(chartData.count),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  double _calculateBarWidth(int count) {
    if (count <= 7) return 24;
    if (count <= 14) return 16;
    if (count <= 30) return 8;
    return 4;
  }

  String _formatAxisLabel(DateTime date, AggregationLevel level) {
    switch (level) {
      case AggregationLevel.daily:
        return DateFormat('M/d').format(date);
      case AggregationLevel.weekly:
        return 'W${_weekNumber(date)}';
      case AggregationLevel.monthly:
        return DateFormat('MMM').format(date);
    }
  }

  String _formatDate(DateTime date, AggregationLevel level) {
    switch (level) {
      case AggregationLevel.daily:
        return DateFormat('MMM d, y').format(date);
      case AggregationLevel.weekly:
        return 'Week of ${DateFormat('MMM d').format(date)}';
      case AggregationLevel.monthly:
        return DateFormat('MMMM y').format(date);
    }
  }

  int _weekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final daysDiff = date.difference(firstDayOfYear).inDays;
    return ((daysDiff + firstDayOfYear.weekday - 1) / 7).ceil();
  }
}
