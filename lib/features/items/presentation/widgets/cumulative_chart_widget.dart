import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../charts/domain/entities/chart_data.dart';
import '../../../charts/presentation/bloc/charts_bloc.dart';
import '../../../charts/presentation/bloc/charts_event.dart';
import '../../../charts/presentation/bloc/charts_state.dart';

/// Line chart widget displaying cumulative (running total) data.
///
/// Uses fl_chart to render a line chart showing growth over time.
/// Shows the running total of events across the selected date range.
class CumulativeChartWidget extends StatelessWidget {
  const CumulativeChartWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChartsBloc, ChartsState>(
      buildWhen: (previous, current) {
        // Only rebuild for cumulative chart states
        if (current is ChartsLoaded) {
          return current.isCumulativeChart;
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

        if (state is ChartsLoaded && state.isCumulativeChart) {
          if (state.chartData.isEmpty) {
            return const _ChartContainer(
              child: Center(child: Text('No data for selected range')),
            );
          }

          return _ChartContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ChartHeader(chartData: state.chartData),
                const SizedBox(height: 16),
                Expanded(
                  child: _LineChartContent(chartData: state.chartData),
                ),
              ],
            ),
          );
        }

        // Show button to switch to cumulative view if viewing bar chart
        if (state is ChartsLoaded && state.isBarChart) {
          return _SwitchToCumulativeButton(state: state);
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
      height: 280,
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

/// Header with title and total.
class _ChartHeader extends StatelessWidget {
  final ChartData chartData;

  const _ChartHeader({required this.chartData});

  @override
  Widget build(BuildContext context) {
    final lastValue = chartData.dataPoints.isNotEmpty
        ? chartData.dataPoints.last.value
        : 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cumulative Total',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              'Running total: $lastValue',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.secondary,
                  ),
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.bar_chart),
          tooltip: 'Switch to bar chart',
          onPressed: () => _switchToBarChart(context),
        ),
      ],
    );
  }

  void _switchToBarChart(BuildContext context) {
    final bloc = context.read<ChartsBloc>();
    final state = bloc.state;
    if (state is ChartsLoaded) {
      bloc.add(LoadBarChart(
        startDate: state.startDate,
        endDate: state.endDate,
        itemId: state.itemId,
      ));
    }
  }
}

/// Button to switch from bar chart to cumulative view.
class _SwitchToCumulativeButton extends StatelessWidget {
  final ChartsLoaded state;

  const _SwitchToCumulativeButton({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: OutlinedButton.icon(
        onPressed: () {
          context.read<ChartsBloc>().add(LoadCumulativeChart(
                startDate: state.startDate,
                endDate: state.endDate,
                itemId: state.itemId,
              ));
        },
        icon: const Icon(Icons.show_chart),
        label: const Text('Show Cumulative Chart'),
      ),
    );
  }
}

/// The actual line chart using fl_chart.
class _LineChartContent extends StatelessWidget {
  final ChartData chartData;

  const _LineChartContent({required this.chartData});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final maxY = chartData.maxValue.toDouble() * 1.1; // Add 10% padding
    final minY = 0.0;

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY > 0 ? maxY : 10,
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: colorScheme.inverseSurface,
            tooltipPadding: const EdgeInsets.all(8),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.x.toInt();
                if (index < 0 || index >= chartData.dataPoints.length) {
                  return null;
                }
                final dataPoint = chartData.dataPoints[index];
                final dateStr = DateFormat('MMM d, y').format(dataPoint.date);
                return LineTooltipItem(
                  '$dateStr\nTotal: ${dataPoint.value}',
                  TextStyle(
                    color: colorScheme.onInverseSurface,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }).toList();
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
                    ? (chartData.count / 5).ceil()
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
                    DateFormat('M/d').format(date),
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
        lineBarsData: [
          LineChartBarData(
            spots: chartData.dataPoints.asMap().entries.map((entry) {
              return FlSpot(
                entry.key.toDouble(),
                entry.value.value.toDouble(),
              );
            }).toList(),
            isCurved: true,
            curveSmoothness: 0.3,
            color: colorScheme.secondary,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: chartData.count <= 30,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: colorScheme.secondary,
                  strokeWidth: 2,
                  strokeColor: colorScheme.surface,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: colorScheme.secondary.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }
}
