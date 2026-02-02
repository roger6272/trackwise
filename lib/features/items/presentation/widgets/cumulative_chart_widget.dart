import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../charts/presentation/bloc/charts_bloc.dart';
import '../../../charts/presentation/bloc/charts_state.dart';

/// Cumulative chart widget displaying running total data.
///
/// Custom implementation matching FlutterFlow design:
/// - Purple bars with tap-to-select (same as bar chart)
/// - Values are cumulative (running total)
/// - Y-axis labels on left
/// - X-axis date labels on bottom
/// - Tooltip showing date and cumulative count on tap
/// - Generates all time buckets (24 for 1D, 7 for 7D, 30 for 30D)
/// - Shows 0 count bars for missing data
class CumulativeChartWidget extends StatefulWidget {
  /// The aggregation range: '1D', '7D', or '30D'.
  final String range;

  /// The selected end date for the chart.
  final DateTime selectedDate;

  const CumulativeChartWidget({
    super.key,
    required this.range,
    required this.selectedDate,
  });

  @override
  State<CumulativeChartWidget> createState() => _CumulativeChartWidgetState();
}

class _CumulativeChartWidgetState extends State<CumulativeChartWidget> {
  int? selectedIndex;
  Offset? tooltipPosition;
  int? tooltipValue;
  int? tooltipInitialCount;
  DateTime? tooltipDate;

  // Layout constants
  static const double yAxisLabelWidth = 30.0;
  static const double chartContentHorizontalPadding = 40.0;
  static const double minBarHeight = 4.0;
  static const double barAreaVerticalPadding = 8.0;
  static const int divisions = 5;

  // Range configuration matching FlutterFlow
  static const Map<String, Map<String, dynamic>> rangeConfig = {
    '1D': {
      'bucketCount': 24,
      'bucketType': 'hour',
      'labelFormat': 'HH',
      'keyFormat': 'yyyy-MM-dd HH',
    },
    '7D': {
      'bucketCount': 7,
      'bucketType': 'day',
      'labelFormat': 'dd',
      'keyFormat': 'yyyy-MM-dd',
    },
    '30D': {
      'bucketCount': 30,
      'bucketType': 'day',
      'labelFormat': 'dd',
      'keyFormat': 'yyyy-MM-dd',
    },
  };

  /// Generate time buckets based on range and selected date.
  List<DateTime> _generateTimeBuckets() {
    final config = rangeConfig[widget.range] ?? rangeConfig['7D']!;
    final int bucketCount = config['bucketCount'];
    final String bucketType = config['bucketType'];
    final now = widget.selectedDate;

    if (bucketType == 'hour') {
      // 24 hourly buckets for the selected day
      return List.generate(
        bucketCount,
        (i) => DateTime(now.year, now.month, now.day, i),
      );
    } else {
      // Daily buckets ending on selected date
      return List.generate(bucketCount, (i) {
        return DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: bucketCount - 1 - i));
      });
    }
  }

  /// Map cumulative chart data to time buckets.
  /// For cumulative charts, values are running totals - missing buckets
  /// carry forward the last known value (not 0).
  Map<String, int> _mapDataToBuckets(
    List<DateTime> timeBuckets,
    ChartsLoaded state,
  ) {
    final config = rangeConfig[widget.range] ?? rangeConfig['7D']!;
    final String keyFormat = config['keyFormat'];

    // Get initial count and creation time
    final initialCount = state.chartData.initialCount;
    final createdAt = state.chartData.createdAt;
    final createdKey = createdAt != null ? DateFormat(keyFormat).format(createdAt) : null;

    // Build a map of available cumulative values from the usecase
    // These are already running totals, not increments
    final Map<String, int> dataPointMap = {};
    for (var dataPoint in state.chartData.dataPoints) {
      final key = DateFormat(keyFormat).format(dataPoint.date);
      // For cumulative data, just assign the value (it's already the running total)
      dataPointMap[key] = dataPoint.value;
    }

    // Map to buckets, carrying forward the last cumulative value
    // for buckets with no data. Start with initialCount from creation bucket.
    final Map<String, int> timeToCount = {};
    int lastCumulativeValue = 0;
    bool hasReachedCreation = false;

    for (var t in timeBuckets) {
      final key = DateFormat(keyFormat).format(t);

      // Check if we've reached or passed the creation bucket
      if (!hasReachedCreation && createdKey != null) {
        if (key == createdKey || (createdAt != null && !t.isBefore(createdAt))) {
          hasReachedCreation = true;
          // Start with initial count from creation
          lastCumulativeValue = initialCount;
        }
      } else if (createdKey == null && initialCount > 0) {
        // No createdAt but has initialCount - show it from start
        hasReachedCreation = true;
        lastCumulativeValue = initialCount;
      }

      if (dataPointMap.containsKey(key)) {
        // dataPoint.value is cumulative of increments only, add initialCount
        lastCumulativeValue = initialCount + dataPointMap[key]!;
      }
      timeToCount[key] = lastCumulativeValue;
    }

    return timeToCount;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChartsBloc, ChartsState>(
      buildWhen: (previous, current) {
        if (current is ChartsLoaded) {
          return current.isCumulativeChart;
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
              style: TextStyle(color: AppColors.error),
            ),
          );
        }

        if (state is ChartsLoaded && state.isCumulativeChart) {
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
    final config = rangeConfig[widget.range] ?? rangeConfig['7D']!;
    final String labelFormat = config['labelFormat'];
    final String keyFormat = config['keyFormat'];

    // Generate time buckets
    final timeBuckets = _generateTimeBuckets();

    // Map data to buckets
    final timeToCount = _mapDataToBuckets(timeBuckets, state);

    // Get values in order (already cumulative from use case)
    final values = timeBuckets.map((t) {
      final k = DateFormat(keyFormat).format(t);
      return timeToCount[k] ?? 0;
    }).toList();

    final labels = timeBuckets.map((t) => DateFormat(labelFormat).format(t)).toList();

    final totalBars = values.length;
    final maxY = values.isEmpty ? 0 : values.reduce((a, b) => a > b ? a : b);
    final stepSize = ((maxY / divisions).ceil()).clamp(1, double.infinity).toInt();
    final adjustedMaxY = stepSize * divisions;

    final barAreaHeight = usableHeight - barAreaVerticalPadding - 32;

    // Get initial count from chart data
    final initialCount = state.chartData.initialCount;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        if (!mounted) return;
        setState(() {
          selectedIndex = null;
          tooltipPosition = null;
          tooltipValue = null;
          tooltipInitialCount = null;
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
                            timeBuckets: timeBuckets,
                            adjustedMaxY: adjustedMaxY,
                            initialCount: initialCount,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // X-axis labels
                SizedBox(
                  height: 32,
                  child: Column(
                    children: [
                      SizedBox(
                        height: 16,
                        child: Row(
                          children: [
                            // Spacer matching y-axis label width
                            SizedBox(width: yAxisLabelWidth),
                            // Labels matching bar area width
                            SizedBox(
                              width: chartContentWidth,
                              child: Row(
                                children: List.generate(totalBars, (i) {
                                  // Show fewer labels for 30D to avoid crowding
                                  final showLabel = widget.range == '30D'
                                      ? (totalBars - 1 - i) % 5 == 0
                                      : true;
                                  return Expanded(
                                    child: Container(
                                      alignment: Alignment.topCenter,
                                      child: Text(
                                        showLabel ? labels[i] : '',
                                        style: TextStyle(fontSize: 7 * fontScale),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // X-axis label (Hour/Day)
                      SizedBox(
                        height: 16,
                        child: Center(
                          child: Text(
                            widget.range == '1D' ? 'Hour' : 'Day',
                            style: TextStyle(
                              fontSize: 9 * fontScale,
                              color: AppColors.neutral,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Tooltip
            if (selectedIndex != null && tooltipPosition != null)
              Positioned(
                left: (tooltipPosition!.dx - 40).clamp(0, usableWidth - 100),
                top: (tooltipPosition!.dy - 80).clamp(0, usableHeight - 70),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.chartTooltip,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tooltipDate != null
                              ? DateFormat('MMM dd, yy').format(tooltipDate!)
                              : '',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Total: ${tooltipValue ?? 0}',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        if (tooltipInitialCount != null && tooltipInitialCount! > 0) ...[
                          Text(
                            'Earned: ${(tooltipValue ?? 0) - tooltipInitialCount!}',
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                          Text(
                            'Initial: $tooltipInitialCount',
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
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
    required List<DateTime> timeBuckets,
    required int adjustedMaxY,
    required int initialCount,
  }) {
    // Colors for the stacked bars
    const Color initialColor = AppColors.chartInitial;
    const Color earnedColor = AppColors.primary;
    const Color selectedColor = AppColors.chartSelected;

    return List.generate(totalBars, (i) {
      final isSelected = selectedIndex == i;
      final totalValue = values[i];

      // Calculate heights for stacked bar
      // Initial count is the base, earned is on top
      final earnedValue = max(0, totalValue - initialCount);
      final initialDisplayValue = min(initialCount, totalValue);

      // Calculate pixel heights
      double totalBarHeight = minBarHeight;
      double initialBarHeight = 0;
      double earnedBarHeight = 0;

      if (adjustedMaxY > 0 && totalValue > 0) {
        totalBarHeight = max((totalValue / adjustedMaxY) * barAreaHeight, minBarHeight);

        if (initialCount > 0) {
          // Proportionally divide the bar height
          final initialRatio = initialDisplayValue / totalValue;
          initialBarHeight = totalBarHeight * initialRatio;
          earnedBarHeight = totalBarHeight - initialBarHeight;
        } else {
          // No initial count - entire bar is earned
          earnedBarHeight = totalBarHeight;
        }
      }

      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              if (!mounted) return;
              final RenderBox? box = context.findRenderObject() as RenderBox?;
              if (box == null) return;
              final localPosition = box.globalToLocal(details.globalPosition);
              setState(() {
                selectedIndex = isSelected ? null : i;
                tooltipValue = totalValue;
                tooltipInitialCount = initialCount;
                tooltipDate = timeBuckets[i];
                tooltipPosition = localPosition;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              width: double.infinity,
              height: totalBarHeight,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Earned portion (top) - purple
                  if (earnedBarHeight > 0)
                    Container(
                      width: double.infinity,
                      height: earnedBarHeight,
                      color: isSelected ? selectedColor : earnedColor,
                    ),
                  // Initial portion (bottom) - gray
                  if (initialBarHeight > 0)
                    Container(
                      width: double.infinity,
                      height: initialBarHeight,
                      color: isSelected
                          ? selectedColor.withOpacity(0.7)
                          : initialColor,
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  @override
  void didUpdateWidget(covariant CumulativeChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.range != widget.range || oldWidget.selectedDate != widget.selectedDate) {
      if (!mounted) return;
      setState(() {
        selectedIndex = null;
        tooltipPosition = null;
        tooltipValue = null;
        tooltipInitialCount = null;
        tooltipDate = null;
      });
    }
  }
}
