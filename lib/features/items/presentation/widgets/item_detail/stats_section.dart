import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../charts/presentation/bloc/charts_bloc.dart';
import '../../../../charts/presentation/bloc/charts_state.dart';
import '../../../domain/utils/stats_calculator.dart';
import '../bar_chart_widget.dart';
import '../cumulative_chart_widget.dart';

/// Section displaying stats summary and chart with toggle.
///
/// Shows:
/// - Stats header with total count and period comparison
/// - Chart toggle switch (Increments / Cumulative)
/// - Chart display area (bar or cumulative based on toggle)
class StatsSection extends StatelessWidget {
  /// Pre-calculated statistics for the selected period.
  final StatsResult stats;

  /// Whether to show cumulative chart (true) or bar chart (false).
  final bool showCumulative;

  /// Callback when chart type is toggled.
  final ValueChanged<bool> onChartTypeChanged;

  const StatsSection({
    super.key,
    required this.stats,
    required this.showCumulative,
    required this.onChartTypeChanged,
  });

  // FlutterFlow colors
  static const Color _primary = Color(0xFF4B39EF);
  static const Color _alternate = Color(0xFFE0E3E7);
  static const Color _primaryText = Color(0xFF14181B);
  static const Color _positiveColor = Color(0xFF017400);
  static const Color _negativeColor = Color(0xFF9F0202);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: _alternate,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsHeader(),
          const SizedBox(height: 16.0),
          _buildChartToggle(),
          const SizedBox(height: 16.0),
          _buildChartArea(),
        ],
      ),
    );
  }

  /// Builds the stats header with total count and period comparison.
  Widget _buildStatsHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Total count row
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '${stats.totalCount}',
              style: GoogleFonts.outfit(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: _primary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Total',
              style: GoogleFonts.outfit(
                fontSize: 26,
                color: _primaryText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Comparison line
        _buildComparisonLine(),
      ],
    );
  }

  /// Builds the comparison line with prior count and percent change.
  Widget _buildComparisonLine() {
    final percentChange = stats.percentChange;
    final percentText = percentChange != null
        ? '${percentChange >= 0 ? '+' : ''}${(percentChange * 100).toStringAsFixed(1)}%'
        : '--';

    final percentColor = stats.isPositive
        ? _positiveColor
        : stats.isNegative
            ? _negativeColor
            : _primaryText;

    return Row(
      children: [
        Text(
          'vs ${stats.priorPeriodCount}',
          style: GoogleFonts.outfit(
            fontSize: 15,
            color: _primaryText,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          percentText,
          style: GoogleFonts.outfit(
            fontSize: 15,
            color: percentColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          stats.periodLabel,
          style: GoogleFonts.outfit(
            fontSize: 15,
            color: _primaryText,
          ),
        ),
      ],
    );
  }

  /// Builds the chart type toggle switch.
  Widget _buildChartToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Increments',
          style: GoogleFonts.outfit(
            fontSize: 14,
            color: _primaryText,
            fontWeight: showCumulative ? FontWeight.normal : FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Switch(
          value: showCumulative,
          onChanged: onChartTypeChanged,
          activeColor: _primary,
          inactiveTrackColor: const Color(0xFFA158FF),
        ),
        const SizedBox(width: 8),
        Text(
          'Cumulative',
          style: GoogleFonts.outfit(
            fontSize: 14,
            color: _primaryText,
            fontWeight: showCumulative ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  /// Builds the chart area with BlocBuilder for loading/error/chart states.
  Widget _buildChartArea() {
    return SizedBox(
      height: 220.0,
      child: BlocBuilder<ChartsBloc, ChartsState>(
        builder: (context, state) {
          if (state is ChartsLoading) {
            return const Center(
              child: CircularProgressIndicator(color: _primary),
            );
          }

          if (state is ChartsError) {
            return Center(
              child: Text(
                'Error: ${state.message}',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: _negativeColor,
                ),
              ),
            );
          }

          // Show appropriate chart based on toggle
          if (showCumulative) {
            return const CumulativeChartWidget();
          } else {
            return const BarChartWidget();
          }
        },
      ),
    );
  }
}
