import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/shimmer.dart';
import '../../../../charts/presentation/bloc/charts_bloc.dart';
import '../../../../charts/presentation/bloc/charts_state.dart';
import '../../../domain/utils/stats_calculator.dart';
import '../bar_chart_widget.dart';
import '../cumulative_chart_widget.dart';
import 'hero_stats.dart';

/// Section displaying stats summary and chart with toggle.
///
/// Shows:
/// - Hero stats with animated count and trend badge
/// - Chart toggle switch (Increments / Cumulative)
/// - Chart display area (bar or cumulative based on toggle)
class StatsSection extends StatelessWidget {
  /// Pre-calculated statistics for the selected period.
  final StatsResult stats;

  /// Whether to show cumulative chart (true) or bar chart (false).
  final bool showCumulative;

  /// Callback when chart type is toggled.
  final ValueChanged<bool> onChartTypeChanged;

  /// The aggregation range: '1D', '7D', or '30D'.
  final String range;

  /// The selected end date for the chart.
  final DateTime selectedDate;

  const StatsSection({
    super.key,
    required this.stats,
    required this.showCumulative,
    required this.onChartTypeChanged,
    required this.range,
    required this.selectedDate,
  });

  // Error color for chart error state
  static const Color _negativeColor = Color(0xFF9F0202);

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    const primary = AppColors.primary;
    final primaryText = AppColors.primaryText(brightness);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        HeroStats(
          totalCount: stats.totalCount,
          priorPeriodCount: stats.priorPeriodCount,
          percentChange: stats.percentChange,
          periodLabel: stats.periodLabel,
        ),
        _buildChartToggle(primary, primaryText),
        const SizedBox(height: 10.0),
        _buildChartArea(context, primary),
      ],
    );
  }

  /// Builds the chart type toggle switch.
  Widget _buildChartToggle(Color primary, Color primaryText) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10.0, 0.0, 10.0, 0.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            'Increments',
            style: GoogleFonts.inter(
              fontSize: 12.0,
              color: primaryText,
            ),
          ),
          Switch.adaptive(
            value: showCumulative,
            onChanged: onChartTypeChanged,
            activeColor: primary,
            inactiveTrackColor: const Color(0xFFA158FF),
          ),
          Text(
            'Cumulative',
            style: GoogleFonts.inter(
              fontSize: 12.0,
              color: primaryText,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the chart area with BlocBuilder for loading/error/chart states.
  Widget _buildChartArea(BuildContext context, Color primary) {
    final width = MediaQuery.of(context).size.width - 40;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: SizedBox(
        width: width,
        height: 220.0,
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
