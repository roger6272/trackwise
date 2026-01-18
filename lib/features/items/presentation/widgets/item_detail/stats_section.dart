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
/// - Chart toggle (Increments / Cumulative)
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
    const primary = AppColors.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        HeroStats(
          totalCount: stats.totalCount,
          priorPeriodCount: stats.priorPeriodCount,
          percentChange: stats.percentChange,
          periodLabel: stats.periodLabel,
        ),
        _buildChartToggle(context, primary),
        const SizedBox(height: 10.0),
        _buildChartArea(context, primary),
      ],
    );
  }

  /// Builds the chart type toggle as matching pill buttons.
  Widget _buildChartToggle(BuildContext context, Color primary) {
    final brightness = Theme.of(context).brightness;
    final alternate = AppColors.alternate(brightness);
    final secondaryText = AppColors.secondaryText(brightness);

    return Padding(
      padding: const EdgeInsets.fromLTRB(10.0, 0.0, 10.0, 0.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            decoration: BoxDecoration(
              color: alternate,
              borderRadius: BorderRadius.circular(10.0),
            ),
            padding: const EdgeInsets.all(3.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildToggleOption(
                  label: 'Increments',
                  icon: Icons.bar_chart_rounded,
                  isSelected: !showCumulative,
                  onTap: () => onChartTypeChanged(false),
                  primary: primary,
                  secondaryText: secondaryText,
                ),
                _buildToggleOption(
                  label: 'Cumulative',
                  icon: Icons.show_chart_rounded,
                  isSelected: showCumulative,
                  onTap: () => onChartTypeChanged(true),
                  primary: primary,
                  secondaryText: secondaryText,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleOption({
    required String label,
    required IconData icon,
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
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: isSelected ? primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8.0),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primary.withValues(alpha: 0.25),
                    blurRadius: 6.0,
                    offset: const Offset(0, 2),
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
                fontSize: 11.0,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
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
