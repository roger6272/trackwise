import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../charts/presentation/bloc/charts_bloc.dart';
import '../../../charts/presentation/bloc/charts_state.dart';

/// Bar chart widget displaying aggregated event data.
///
/// Custom implementation matching FlutterFlow design:
/// - Purple bars with tap-to-select
/// - Y-axis labels on left
/// - X-axis date labels on bottom
/// - Tooltip showing date and count on tap
class BarChartWidget extends StatefulWidget {
  const BarChartWidget({super.key});

  @override
  State<BarChartWidget> createState() => _BarChartWidgetState();
}

class _BarChartWidgetState extends State<BarChartWidget> {
  int? selectedIndex;
  Offset? tooltipPosition;
  int? tooltipValue;
  DateTime? tooltipDate;

  // Layout constants
  static const double yAxisLabelWidth = 30.0;
  static const double chartContentHorizontalPadding = 40.0;
  static const double minBarHeight = 3.0;
  static const double barAreaVerticalPadding = 30.0;
  static const int divisions = 5;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChartsBloc, ChartsState>(
      buildWhen: (previous, current) {
        if (current is ChartsLoaded) {
          return current.isBarChart;
        }
        return true;
      },
      builder: (context, state) {
        if (state is ChartsLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is ChartsError) {
          return Center(
            child: Text(
              'Error: ${state.message}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        if (state is ChartsLoaded && state.isBarChart) {
          if (state.chartData.isEmpty) {
            return const Center(child: Text('No data for selected range'));
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final usableWidth = constraints.maxWidth;
              final usableHeight = constraints.maxHeight;
              final fontScale = (usableWidth / 375).clamp(0.8, 1.4);
              final chartContentWidth = usableWidth - chartContentHorizontalPadding;

              return _buildChart(
                state: state,
                usableWidth: usableWidth,
                usableHeight: usableHeight,
                chartContentWidth: chartContentWidth,
                fontScale: fontScale,
              );
            },
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildChart({
    required ChartsLoaded state,
    required double usableWidth,
    required double usableHeight,
    required double chartContentWidth,
    required double fontScale,
  }) {
    final dataPoints = state.chartData.dataPoints;
    final values = dataPoints.map((dp) => dp.value).toList();
    final dates = dataPoints.map((dp) => dp.date).toList();

    final totalBars = values.length;
    final maxY = values.isEmpty ? 0 : values.reduce((a, b) => a > b ? a : b);
    final stepSize = ((maxY / divisions).ceil()).clamp(1, double.infinity).toInt();
    final adjustedMaxY = stepSize * divisions;

    final barAreaHeight = usableHeight - barAreaVerticalPadding - 20;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        setState(() {
          selectedIndex = null;
          tooltipPosition = null;
          tooltipValue = null;
          tooltipDate = null;
        });
      },
      child: SizedBox(
        width: usableWidth,
        height: usableHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              children: [
                SizedBox(
                  height: barAreaHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Y-axis labels
                      SizedBox(
                        width: yAxisLabelWidth,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(divisions + 1, (i) {
                            final label = ((adjustedMaxY / divisions) * i).round();
                            return Text(
                              '$label',
                              style: TextStyle(fontSize: 8 * fontScale),
                            );
                          }).reversed.toList(),
                        ),
                      ),
                      // Bars
                      SizedBox(
                        width: chartContentWidth,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: _buildBars(
                            totalBars: totalBars,
                            barAreaHeight: barAreaHeight,
                            values: values,
                            dates: dates,
                            adjustedMaxY: adjustedMaxY,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // X-axis labels
                SizedBox(
                  height: 20,
                  child: Padding(
                    padding: EdgeInsets.only(left: yAxisLabelWidth),
                    child: Row(
                      children: List.generate(totalBars, (i) {
                        final date = dates[i];
                        final showLabel = totalBars > 14
                            ? (totalBars - 1 - i) % 5 == 0
                            : true;
                        return Expanded(
                          child: Container(
                            alignment: Alignment.topCenter,
                            child: Text(
                              showLabel ? DateFormat('dd').format(date) : '',
                              style: TextStyle(fontSize: 7 * fontScale),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
            // Tooltip
            if (selectedIndex != null && tooltipPosition != null)
              Positioned(
                left: (tooltipPosition!.dx - 30).clamp(0, usableWidth - 80),
                top: (tooltipPosition!.dy - 60).clamp(0, usableHeight - 50),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tooltipDate != null
                              ? DateFormat('MMM dd, yy').format(tooltipDate!)
                              : '',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        Text(
                          'Count: ${tooltipValue ?? ''}',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildBars({
    required int totalBars,
    required double barAreaHeight,
    required List<int> values,
    required List<DateTime> dates,
    required int adjustedMaxY,
  }) {
    return List.generate(totalBars, (i) {
      final isSelected = selectedIndex == i;
      final barHeight = adjustedMaxY > 0
          ? max((values[i] / adjustedMaxY) * barAreaHeight, minBarHeight)
          : minBarHeight;

      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              final RenderBox box = context.findRenderObject() as RenderBox;
              final localPosition = box.globalToLocal(details.globalPosition);
              setState(() {
                selectedIndex = isSelected ? null : i;
                tooltipValue = values[i];
                tooltipDate = dates[i];
                tooltipPosition = localPosition;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              width: double.infinity,
              height: barHeight,
              color: isSelected ? Colors.grey : Colors.purple,
            ),
          ),
        ),
      );
    });
  }

  @override
  void didUpdateWidget(covariant BarChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Clear selection when widget updates
    setState(() {
      selectedIndex = null;
      tooltipPosition = null;
      tooltipValue = null;
      tooltipDate = null;
    });
  }
}
