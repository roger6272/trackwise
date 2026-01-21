import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/shimmer.dart';
import '../../../../charts/presentation/bloc/charts_bloc.dart';
import '../../../../charts/presentation/bloc/charts_state.dart';
import '../bar_chart_widget.dart';
import '../cumulative_chart_widget.dart';

/// Section displaying chart with controls and toggle.
///
/// Shows:
/// - Chart controls (aggregation pills, date picker)
/// - Chart header with key stat and toggle
/// - Chart display area (bar or cumulative based on toggle)
///
/// Note: Stats are now shown in DynamicStats widget below.
class ChartSection extends StatelessWidget {
  /// Whether to show cumulative chart (true) or bar chart (false).
  final bool showCumulative;

  /// Callback when chart type is toggled.
  final ValueChanged<bool> onChartTypeChanged;

  /// The aggregation range: '1D', '7D', or '30D'.
  final String range;

  /// Callback when aggregation is changed.
  final ValueChanged<String> onAggregationChanged;

  /// The selected end date for the chart.
  final DateTime selectedDate;

  /// Callback when date is changed.
  final ValueChanged<DateTime> onDateChanged;

  /// Total count for the period (key stat to display).
  final int periodTotal;

  /// Percent change vs prior period (null if no prior data).
  final double? percentChange;

  /// Prior period count for comparison label.
  final int priorPeriodCount;

  /// Period label for comparison (e.g., "DoD", "WoW").
  final String periodLabel;

  const ChartSection({
    super.key,
    required this.showCumulative,
    required this.onChartTypeChanged,
    required this.range,
    required this.onAggregationChanged,
    required this.selectedDate,
    required this.onDateChanged,
    this.periodTotal = 0,
    this.percentChange,
    this.priorPeriodCount = 0,
    this.periodLabel = '',
  });

  // Trend colors
  static const Color _positiveColor = Color(0xFF017400);
  static const Color _negativeColor = Color(0xFF9F0202);
  static const Color _neutralColor = Color(0xFF6B7280);

  /// Get the chart window label based on range.
  String _getWindowLabel() {
    switch (range) {
      case '1D':
        return 'Today';
      case '7D':
        return 'Last 7 Days';
      case '30D':
        return 'Last 30 Days';
      default:
        return 'Activity';
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primary = AppColors.primaryAdaptive(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final alternate = AppColors.alternate(brightness);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section header (inside card) - matches PeriodStatsSection layout
        Padding(
          padding: const EdgeInsets.fromLTRB(12.0, 0, 12.0, 16.0),
          child: Row(
            children: [
              Icon(
                Icons.bar_chart_rounded,
                size: 16.0,
                color: primary,
              ),
              const SizedBox(width: 6.0),
              Text(
                _getWindowLabel(),
                style: GoogleFonts.inter(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w600,
                  color: secondaryText,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
        // Chart controls (aggregation + date picker)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: _buildChartControls(context, primary, secondaryText, alternate),
        ),
        const SizedBox(height: 12.0),
        _buildChartHeader(context, primary, alternate),
        const SizedBox(height: 8.0),
        _buildChartArea(context, primary),
      ],
    );
  }

  /// Builds the chart controls row (aggregation pills + date picker).
  Widget _buildChartControls(
    BuildContext context,
    Color primary,
    Color secondaryText,
    Color alternate,
  ) {
    final brightness = Theme.of(context).brightness;
    final primaryText = AppColors.primaryText(brightness);
    final primaryBackground = AppColors.primaryBackground(brightness);
    // Filter control background - blue tint to distinguish from content
    final baseBackground = Color.lerp(alternate, primaryBackground, 0.5)!;
    final controlBackground = Color.lerp(baseBackground, primary, 0.12)!;

    return Row(
      children: [
        // Aggregation pills (45% width)
        Expanded(
          flex: 45,
          child: _buildAggregationPills(
            primary,
            controlBackground,
            secondaryText,
          ),
        ),
        const SizedBox(width: 8.0),
        // Date picker (55% width)
        Expanded(
          flex: 55,
          child: _buildDatePicker(
            context,
            primary,
            primaryText,
            secondaryText,
            controlBackground,
          ),
        ),
      ],
    );
  }

  /// Builds the aggregation period pills (1D, 7D, 30D).
  Widget _buildAggregationPills(
    Color primary,
    Color background,
    Color secondaryText,
  ) {
    const periods = ['1D', '7D', '30D'];

    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(
          color: secondaryText.withValues(alpha: 0.08),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8.0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(3.0),
      child: Row(
        children: periods.map((period) {
          final isSelected = range == period;
          return Expanded(
            child: GestureDetector(
              onTap: () => onAggregationChanged(period),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                decoration: BoxDecoration(
                  color: isSelected ? primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(7.0),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: primary.withValues(alpha: 0.3),
                            blurRadius: 6.0,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    period,
                    style: GoogleFonts.inter(
                      fontSize: 12.0,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? Colors.white : secondaryText,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Builds the date picker with prev/next buttons.
  Widget _buildDatePicker(
    BuildContext context,
    Color primary,
    Color primaryText,
    Color secondaryText,
    Color background,
  ) {
    final dateFormat = DateFormat('EEE, MMM d');
    final isToday = _isToday(selectedDate);
    final canGoForward = !isToday;

    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(
          color: secondaryText.withValues(alpha: 0.08),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8.0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(3.0),
      child: Row(
        children: [
          // Previous day button
          GestureDetector(
            onTap: () => onDateChanged(
              selectedDate.subtract(const Duration(days: 1)),
            ),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 6.0),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6.0),
              ),
              child: Icon(
                Icons.chevron_left_rounded,
                size: 18.0,
                color: primary,
              ),
            ),
          ),
          // Date display (tappable, centered, fills space)
          Expanded(
            child: GestureDetector(
              onTap: () => _showDatePickerBottomSheet(context),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      range == '1D' ? 'Viewing' : 'Ending',
                      style: GoogleFonts.inter(
                        fontSize: 9.0,
                        fontWeight: FontWeight.w500,
                        color: secondaryText,
                        letterSpacing: 0.3,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            isToday ? 'Today' : dateFormat.format(selectedDate),
                            style: GoogleFonts.interTight(
                              fontSize: 12.0,
                              fontWeight: FontWeight.w600,
                              color: primaryText,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 2.0),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 14.0,
                          color: secondaryText,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Next day button
          GestureDetector(
            onTap: canGoForward
                ? () => onDateChanged(
                      selectedDate.add(const Duration(days: 1)),
                    )
                : null,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 6.0),
              decoration: BoxDecoration(
                color: canGoForward
                    ? primary.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6.0),
              ),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 18.0,
                color: canGoForward ? primary : secondaryText.withValues(alpha: 0.25),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  void _showDatePickerBottomSheet(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primary = AppColors.primaryAdaptive(brightness);
    final primaryBackground = AppColors.primaryBackground(brightness);
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);

    final title = range == '1D' ? 'Select Date' : 'Select End Date';
    DateTime tempSelectedDate = selectedDate;

    showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: primaryBackground,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20.0),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle bar
                    Container(
                      margin: const EdgeInsets.only(top: 12.0),
                      width: 40.0,
                      height: 4.0,
                      decoration: BoxDecoration(
                        color: secondaryText.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2.0),
                      ),
                    ),
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.interTight(
                              fontSize: 18.0,
                              fontWeight: FontWeight.w600,
                              color: primaryText,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(
                              Icons.close_rounded,
                              color: secondaryText,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                    // Calendar
                    CalendarDatePicker(
                      initialDate: tempSelectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      onDateChanged: (date) {
                        setModalState(() {
                          tempSelectedDate = date;
                        });
                      },
                    ),
                    // Action buttons
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24.0, 8.0, 24.0, 16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: secondaryText,
                                side: BorderSide(
                                  color: secondaryText.withValues(alpha: 0.3),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10.0),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 14.0),
                              ),
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.inter(
                                  fontSize: 15.0,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12.0),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                onDateChanged(tempSelectedDate);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10.0),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 14.0),
                              ),
                              child: Text(
                                'Confirm',
                                style: GoogleFonts.inter(
                                  fontSize: 15.0,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Builds the chart header with hero stat, trend, and toggle.
  Widget _buildChartHeader(BuildContext context, Color primary, Color alternate) {
    final brightness = Theme.of(context).brightness;
    final secondaryText = AppColors.secondaryText(brightness);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Hero stat: +X increments with trend
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '+$periodTotal',
                    style: GoogleFonts.interTight(
                      fontSize: 28.0,
                      fontWeight: FontWeight.w700,
                      color: primary,
                    ),
                  ),
                  const SizedBox(width: 6.0),
                  Text(
                    'increments',
                    style: GoogleFonts.inter(
                      fontSize: 14.0,
                      fontWeight: FontWeight.w500,
                      color: secondaryText,
                    ),
                  ),
                ],
              ),
              // Trend indicator
              if (periodLabel.isNotEmpty) ...[
                const SizedBox(height: 2.0),
                _buildTrendBadge(secondaryText),
              ],
            ],
          ),
          const Spacer(),
          // Toggle
          _buildChartToggle(context, primary, alternate, secondaryText),
        ],
      ),
    );
  }

  /// Builds the trend badge showing period-over-period change.
  Widget _buildTrendBadge(Color secondaryText) {
    final isPositive = percentChange != null && percentChange! > 0;
    final isNegative = percentChange != null && percentChange! < 0;

    final Color trendColor;
    final IconData trendIcon;

    if (isPositive) {
      trendColor = _positiveColor;
      trendIcon = Icons.trending_up_rounded;
    } else if (isNegative) {
      trendColor = _negativeColor;
      trendIcon = Icons.trending_down_rounded;
    } else {
      trendColor = _neutralColor;
      trendIcon = Icons.trending_flat_rounded;
    }

    final percentText = percentChange != null
        ? '${isPositive ? '+' : ''}${(percentChange! * 100).toStringAsFixed(0)}%'
        : '0%';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          trendIcon,
          size: 14.0,
          color: trendColor,
        ),
        const SizedBox(width: 4.0),
        Text(
          '$percentText vs $priorPeriodCount $periodLabel',
          style: GoogleFonts.inter(
            fontSize: 12.0,
            fontWeight: FontWeight.w500,
            color: secondaryText,
          ),
        ),
      ],
    );
  }

  /// Builds a compact chart type toggle with icons and labels.
  Widget _buildChartToggle(
    BuildContext context,
    Color primary,
    Color alternate,
    Color secondaryText,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: alternate,
        borderRadius: BorderRadius.circular(8.0),
      ),
      padding: const EdgeInsets.all(2.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleOption(
            icon: Icons.bar_chart_rounded,
            label: 'Add',
            isSelected: !showCumulative,
            onTap: () => onChartTypeChanged(false),
            primary: primary,
            secondaryText: secondaryText,
          ),
          _buildToggleOption(
            icon: Icons.show_chart_rounded,
            label: 'Sum',
            isSelected: showCumulative,
            onTap: () => onChartTypeChanged(true),
            primary: primary,
            secondaryText: secondaryText,
          ),
        ],
      ),
    );
  }

  Widget _buildToggleOption({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required Color primary,
    required Color secondaryText,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: isSelected ? primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6.0),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primary.withValues(alpha: 0.25),
                    blurRadius: 4.0,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14.0,
              color: isSelected ? Colors.white : secondaryText,
            ),
            const SizedBox(width: 4.0),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12.0,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the chart area with BlocBuilder for loading/error/chart states.
  Widget _buildChartArea(BuildContext context, Color primary) {
    final width = MediaQuery.of(context).size.width - 40;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: SizedBox(
        width: width,
        height: 200.0,
        child: BlocBuilder<ChartsBloc, ChartsState>(
          builder: (context, state) {
            if (state is ChartsLoading) {
              return _buildChartSkeleton(width);
            }

            if (state is ChartsError) {
              return Center(
                child: Text(
                  'Error: ${state.message}',
                  style: GoogleFonts.inter(
                    fontSize: 14.0,
                    color: _negativeColor,
                  ),
                ),
              );
            }

            // Show appropriate chart based on toggle
            if (showCumulative) {
              return CumulativeChartWidget(
                range: range,
                selectedDate: selectedDate,
              );
            } else {
              return BarChartWidget(
                range: range,
                selectedDate: selectedDate,
              );
            }
          },
        ),
      ),
    );
  }

  /// Builds a shimmer skeleton for the chart loading state.
  Widget _buildChartSkeleton(double width) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        children: [
          // Chart area placeholder
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Y-axis labels
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    5,
                    (index) => const ShimmerText(width: 24, height: 10),
                  ),
                ),
                const SizedBox(width: 12),
                // Bars
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(
                      7,
                      (index) => ShimmerBox(
                        width: 28,
                        height: 60.0 + ((index * 25) % 120),
                        borderRadius: 4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // X-axis labels
          Padding(
            padding: const EdgeInsets.only(left: 36.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                7,
                (index) => const ShimmerText(width: 28, height: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
