// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:intl/intl.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

class EventLogBarChart extends StatefulWidget {
  final String range;
  final double width;
  final double height;
  final DocumentReference itemRef;
  final bool showAfterResetOnly;

  const EventLogBarChart({
    Key? key,
    required this.width,
    required this.height,
    required this.range,
    required this.itemRef,
    this.showAfterResetOnly = false,
  }) : super(key: key);

  @override
  _EventLogBarChartState createState() => _EventLogBarChartState();
}

class _EventLogBarChartState extends State<EventLogBarChart> {
  int? selectedIndex;
  Offset? tooltipPosition;
  int? tooltipValue;
  String? tooltipLabel;

  // Layout constants for chart sizing and spacing
  static const double yAxisLabelWidth = 20.0;
  static const double chartContentHorizontalPadding =
      40.0; // Padding for chart content width calculation
  static const double minBarHeight = 3.0;
  static const double barAreaVerticalPadding =
      30.0; // Padding for bar area height calculation
  static const int divisions = 5;

  // Configuration for supported ranges
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

  List<DateTime> _generateTimeBuckets(DateTime now) {
    final config = rangeConfig[widget.range] ?? rangeConfig['7D']!;
    final int bucketCount = config['bucketCount'];
    final String bucketType = config['bucketType'];
    if (bucketType == 'hour') {
      return List.generate(
          bucketCount, (i) => DateTime(now.year, now.month, now.day, i));
    } else if (bucketType == 'day') {
      return List.generate(bucketCount, (i) {
        return DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: bucketCount - 1 - i));
      });
    }
    return [];
  }

/////////////////////////////////////////Prepare data/////////////////////////////////////////
  Map<String, int> _calculateTimeToCount(
      List<DateTime> timeBuckets, List logs, DateTime? lastResetTime) {
    final config = rangeConfig[widget.range] ?? rangeConfig['7D']!;
    final String keyFormat = config['keyFormat'];
    final Map<String, int> timeToCount = {
      for (var t in timeBuckets) DateFormat(keyFormat).format(t): 0
    };

    for (var doc in logs) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) continue; // Skip if data is missing
      // Safely extract fields with null checks and defaults
      final dynamic createdTime = data['created_time'];
      final String eventType = (data['event_name'] ?? 'unknown').toString();
      if (eventType == 'reset') continue;
      final int increment = (data['increment'] is int)
          ? data['increment'] as int
          : int.tryParse(data['increment']?.toString() ?? '0') ?? 0;
      DateTime? time;
      if (createdTime is DateTime) {
        time = createdTime;
      } else if (createdTime is Timestamp) {
        time = createdTime.toDate();
      } else if (createdTime is String) {
        // Attempt to parse string date
        time = DateTime.tryParse(createdTime);
      }
      if (time != null) {
        // Skip data before the last reset if showAfterResetOnly is true
        if (widget.showAfterResetOnly &&
            lastResetTime != null &&
            time.isBefore(lastResetTime)) {
          continue;
        }
        final key = DateFormat(keyFormat).format(time);
        if (timeToCount.containsKey(key)) {
          timeToCount[key] = (timeToCount[key] ?? 0) + increment;
        }
      }
    }
    return timeToCount;
  }

////////////////////////////////////////////Bar Building///////////////////////////////////
  List<Widget> _buildBars({
    required int totalBars,
    required double barAreaHeight,
    required List<int> values,
    required List<String> labels,
    required int adjustedMaxY,
    List<DateTime>? timeBuckets,
  }) {
    return List.generate(totalBars, (i) {
      final isSelected = selectedIndex == i;
      final barHeight = max(
        (values[i] / adjustedMaxY) * barAreaHeight,
        minBarHeight,
      );
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              // Bar
              Semantics(
                label: 'Bar for ${labels[i]}, value ${values[i]}',
                selected: isSelected,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) {
                    final RenderBox box =
                        context.findRenderObject() as RenderBox;
                    final localPosition =
                        box.globalToLocal(details.globalPosition);
                    setState(() {
                      selectedIndex = isSelected ? null : i;
                      tooltipValue = values[i];
                      tooltipLabel = labels[i];
                      tooltipPosition = localPosition;
                    });
                  },
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    width: double.infinity,
                    height: barHeight,
                    color: isSelected ? Colors.grey : Colors.purple,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildChart(Map<String, int> timeToCount, List<DateTime> timeBuckets,
      double usableWidth, double chartContentWidth, double fontScale) {
    final config = rangeConfig[widget.range] ?? rangeConfig['7D']!;
    if (config != null) {
      print(config['key']);
    }
    final String labelFormat = config['labelFormat'];
    final labels =
        timeBuckets.map((t) => DateFormat(labelFormat).format(t)).toList();

    final values = timeBuckets.map((t) {
      final k = DateFormat(config['keyFormat']).format(t);
      return timeToCount[k] ?? 0;
    }).toList();

    final totalBars = values.length;
    final totalGaps = totalBars > 1 ? totalBars - 1 : 0;
    final maxY = values.isEmpty ? 0 : values.reduce((a, b) => a > b ? a : b);
    final stepSize = ((maxY / 5).ceil()).clamp(1, double.infinity).toInt();
    final adjustedMaxY = stepSize * 5;

    const barToGapRatio = 0.8;
    final totalUnits =
        (totalBars * barToGapRatio) + (totalGaps * (1 - barToGapRatio));
    final unitWidth = chartContentWidth / totalUnits;
    final barWidth = unitWidth * barToGapRatio;
    final barGap = unitWidth * (1 - barToGapRatio);
    final barAreaHeight = widget.height - barAreaVerticalPadding;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        setState(() {
          selectedIndex = null;
          tooltipPosition = null;
          tooltipValue = null;
          tooltipLabel = null;
        });
      },
      child: SizedBox(
        width: usableWidth,
        height: widget.height + 30,
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
                      Container(
                        width: yAxisLabelWidth,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(divisions + 1, (i) {
                            final label =
                                ((adjustedMaxY / divisions) * i).round();
                            return Text(
                              '$label',
                              style: TextStyle(fontSize: 8 * fontScale),
                            );
                          }).reversed.toList(),
                        ),
                      ),
                      SizedBox(
                        width: chartContentWidth,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: _buildBars(
                            totalBars: totalBars,
                            barAreaHeight: barAreaHeight,
                            values: values,
                            labels: labels,
                            adjustedMaxY: adjustedMaxY,
                            timeBuckets: timeBuckets,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 20,
                  child: Padding(
                    padding: EdgeInsets.only(left: yAxisLabelWidth),
                    child: Row(
                      children: List.generate(totalBars, (i) {
                        final label = labels[i];
                        final showLabel = widget.range == '30D'
                            ? (totalBars - 1 - i) % 5 == 0
                            : true;
                        return Container(
                          width: barWidth + (i == totalBars - 1 ? 0 : barGap),
                          alignment: Alignment.topCenter,
                          child: Text(
                            showLabel ? label : '',
                            style: TextStyle(fontSize: 7 * fontScale),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),

            // Tooltip overlay (global)
            if (selectedIndex != null && tooltipPosition != null)
              Positioned(
                left: tooltipPosition!.dx - 30,
                top: tooltipPosition!.dy - 60,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tooltipLabel != null &&
                                  selectedIndex != null &&
                                  timeBuckets != null
                              ? DateFormat('MMM dd, yy')
                                  .format(timeBuckets[selectedIndex!])
                              : '',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        Text(
                          'Count: ${tooltipValue ?? ''}',
                          style: TextStyle(color: Colors.white, fontSize: 12),
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final usableWidth = constraints.maxWidth;
      //final screenWidth = MediaQuery.of(context).size.width;
      //final usableWidth = screenWidth; //need to substract padding
      final fontScale = (usableWidth / 375).clamp(0.8, 1.4);

      // Use named constants for layout calculations
      final chartContentWidth = usableWidth - chartContentHorizontalPadding;

      return StreamBuilder<QuerySnapshot>(
        stream: (() {
          final now = FFAppState().datePicked ?? DateTime.now();
          final int numberOfDays =
              (widget.range == '7D' || widget.range == '1D') ? 7 : 30;
          DateTime startDate;
          if (widget.range == '1D') {
            startDate = DateTime(now.year, now.month, now.day);
          } else {
            startDate = DateTime(now.year, now.month, now.day)
                .subtract(Duration(days: numberOfDays - 1));
          }
          return FirebaseFirestore.instance
              .collection('EventLog')
              .where('item', isEqualTo: widget.itemRef)
              .where('created_time',
                  isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
              .orderBy('created_time', descending: false)
              .snapshots();
        })(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final logs = snapshot.data!.docs;
          final now = FFAppState().datePicked ?? DateTime.now();
          final timeBuckets = _generateTimeBuckets(now);

          // If showAfterResetOnly is true, we need to get the Item data
          if (widget.showAfterResetOnly) {
            return StreamBuilder<DocumentSnapshot>(
              stream: widget.itemRef.snapshots(),
              builder: (context, itemSnapshot) {
                if (!itemSnapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                DateTime? lastResetTime;
                if (itemSnapshot.data!.exists) {
                  final itemData =
                      itemSnapshot.data!.data() as Map<String, dynamic>?;
                  if (itemData != null) {
                    final dynamic lastResetTimeData = itemData['lastResetTime'];
                    if (lastResetTimeData is DateTime) {
                      lastResetTime = lastResetTimeData;
                    } else if (lastResetTimeData is Timestamp) {
                      lastResetTime = lastResetTimeData.toDate();
                    } else if (lastResetTimeData is String) {
                      lastResetTime = DateTime.tryParse(lastResetTimeData);
                    }
                  }
                }

                final timeToCount =
                    _calculateTimeToCount(timeBuckets, logs, lastResetTime);
                return _buildChart(timeToCount, timeBuckets, usableWidth,
                    chartContentWidth, fontScale);
              },
            );
          } else {
            final timeToCount = _calculateTimeToCount(timeBuckets, logs, null);
            return _buildChart(timeToCount, timeBuckets, usableWidth,
                chartContentWidth, fontScale);
          }
        },
      );
    });
  }

  @override
  void didUpdateWidget(covariant EventLogBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.range != widget.range ||
        oldWidget.showAfterResetOnly != widget.showAfterResetOnly) {
      setState(() {
        selectedIndex = null;
        tooltipPosition = null;
        tooltipValue = null;
        tooltipLabel = null;
      });
    }
  }
}
