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
/// - Generates all time buckets (24 for 1D, 7 for 7D, 30 for 30D)
/// - Shows 0 count bars for missing data
class BarChartWidget extends StatefulWidget {
  /// The aggregation range: '1D', '7D', or '30D'.
  final String range;

  /// The selected end date for the chart.
  final DateTime selectedDate;

  const BarChartWidget({
    super.key,
    required this.range,
    required this.selectedDate,
  });

  @override
  State<BarChartWidget> createState() => _BarChartWidgetState();
}

class _BarChartWidgetState extends State<BarChartWidget> {
  int? selectedIndex;
  Offset? tooltipPosition;
  int? tooltipValue;
  int? tooltipInitialCount;
  bool tooltipIsInitialBar = false;
  DateTime? tooltipDate;

  // Layout constants
  static const double yAxisLabelWidth = 30.0;
  static const double chartContentHorizontalPadding = 40.0;
  static const double minBarHeight = 3.0;
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

  /// Map chart data to time buckets, filling 0 for missing data.
  Map<String, int> _mapDataToBuckets(
    List<DateTime> timeBuckets,
    ChartsLoaded state,
  ) {
    final config = rangeConfig[widget.range] ?? rangeConfig['7D']!;
    final String keyFormat = config['keyFormat'];

    // Initialize all buckets with 0
    final Map<String, int> timeToCount = {
      for (var t in timeBuckets) DateFormat(keyFormat).format(t): 0
    };

    // Fill in actual data from chart state
    for (var dataPoint in state.chartData.dataPoints) {
      String key;
      if (widget.range == '1D') {
        // For hourly, use the hour key format
        key = DateFormat(keyFormat).format(dataPoint.date);
      } else {
        // For daily, use the day key format
        key = DateFormat(keyFormat).format(dataPoint.date);
      }
      if (timeToCount.containsKey(key)) {
        timeToCount[key] = (timeToCount[key] ?? 0) + dataPoint.value;
      }
    }

    return timeToCount;
  }

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

    // Get values and labels in order
    final values = timeBuckets.map((t) {
      final k = DateFormat(keyFormat).format(t);
      return timeToCount[k] ?? 0;
    }).toList();

    final labels = timeBuckets.map((t) => DateFormat(labelFormat).format(t)).toList();

    // Get initial count and creation time from chart data
    final initialCount = state.chartData.initialCount;
    final createdAt = state.chartData.createdAt;

    // Find which bucket index the creation time falls into
    int? initialCountBucketIndex;
    if (initialCount > 0 && createdAt != null) {
      final createdKey = DateFormat(keyFormat).format(createdAt);
      for (int i = 0; i < timeBuckets.length; i++) {
        final bucketKey = DateFormat(keyFormat).format(timeBuckets[i]);
        if (bucketKey == createdKey) {
          initialCountBucketIndex = i;
          break;
        }
      }
    }

    final totalBars = values.length;
    // Max Y needs to account for the bucket with initial count stacked
    int maxY;
    if (initialCountBucketIndex != null) {
      final initialBarTotal = values[initialCountBucketIndex] + initialCount;
      final maxActivity = values.isEmpty ? 0 : values.reduce((a, b) => a > b ? a : b);
      maxY = max(maxActivity, initialBarTotal);
    } else {
      maxY = values.isEmpty ? 0 : values.reduce((a, b) => a > b ? a : b);
    }
    final stepSize = ((maxY / divisions).ceil()).clamp(1, double.infinity).toInt();
    final adjustedMaxY = stepSize * divisions;

    final barAreaHeight = usableHeight - barAreaVerticalPadding - 32;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        if (!mounted) return;
        setState(() {
          selectedIndex = null;
          tooltipPosition = null;
          tooltipValue = null;
          tooltipInitialCount = null;
          tooltipIsInitialBar = false;
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
                            initialCountBucketIndex: initialCountBucketIndex,
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
                              color: Colors.grey[600],
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
                      color: Colors.black.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tooltipDate != null
                              ? DateFormat(widget.range == '1D' ? 'MMM dd, h a' : 'MMM dd, yy').format(tooltipDate!)
                              : '',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        // Show total, start, add for initial bar; just activity for others
                        if (tooltipIsInitialBar && tooltipInitialCount != null && tooltipInitialCount! > 0) ...[
                          Text(
                            'Total: ${(tooltipValue ?? 0) + tooltipInitialCount!}',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'Earned: ${tooltipValue ?? 0}',
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                          Text(
                            'Initial: $tooltipInitialCount',
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ] else
                          Text(
                            'Activity: ${tooltipValue ?? 0}',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
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
    required List<DateTime> timeBuckets,
    required int adjustedMaxY,
    required int initialCount,
    required int? initialCountBucketIndex,
  }) {
    // Colors for the stacked bars
    const Color initialColor = Color(0xFF9E9E9E); // Gray for initial count
    const Color activityColor = Colors.purple; // Purple for activity
    const Color selectedColor = Color(0xFF757575); // Darker gray when selected

    return List.generate(totalBars, (i) {
      final isSelected = selectedIndex == i;
      final isInitialBar = initialCountBucketIndex != null && i == initialCountBucketIndex;
      final activityValue = values[i];

      // Show initial count section only at the creation time bucket
      final showInitialSection = isInitialBar && initialCount > 0;

      // Calculate total height including initial count for first bar
      final totalValue = showInitialSection ? activityValue + initialCount : activityValue;

      double totalBarHeight = minBarHeight;
      double initialBarHeight = 0;
      double activityBarHeight = 0;

      if (adjustedMaxY > 0 && totalValue > 0) {
        totalBarHeight = max((totalValue / adjustedMaxY) * barAreaHeight, minBarHeight);

        if (showInitialSection) {
          // Proportionally divide the bar height
          final initialRatio = initialCount / totalValue;
          initialBarHeight = totalBarHeight * initialRatio;
          activityBarHeight = totalBarHeight - initialBarHeight;
        } else {
          activityBarHeight = totalBarHeight;
        }
      } else if (adjustedMaxY > 0) {
        // Zero activity but might have initial count on first bar
        if (showInitialSection) {
          totalBarHeight = max((initialCount / adjustedMaxY) * barAreaHeight, minBarHeight);
          initialBarHeight = totalBarHeight;
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
                tooltipValue = activityValue;
                tooltipInitialCount = initialCount;
                tooltipIsInitialBar = isInitialBar;
                tooltipDate = timeBuckets[i];
                tooltipPosition = localPosition;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              width: double.infinity,
              height: totalBarHeight,
              child: showInitialSection
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Activity portion (top) - purple
                        if (activityBarHeight > 0)
                          Container(
                            width: double.infinity,
                            height: activityBarHeight,
                            color: isSelected ? selectedColor : activityColor,
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
                    )
                  : Container(
                      color: isSelected ? Colors.grey : activityColor,
                    ),
            ),
          ),
        ),
      );
    });
  }

  @override
  void didUpdateWidget(covariant BarChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.range != widget.range || oldWidget.selectedDate != widget.selectedDate) {
      if (!mounted) return;
      setState(() {
        selectedIndex = null;
        tooltipPosition = null;
        tooltipValue = null;
        tooltipInitialCount = null;
        tooltipIsInitialBar = false;
        tooltipDate = null;
      });
    }
  }
}
