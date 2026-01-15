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

  // FlutterFlow colors
  static const Color _primary = Color(0xFF4B39EF);
  static const Color _alternate = Color(0xFFE0E3E7);
  static const Color _primaryText = Color(0xFF14181B);
  static const Color _positiveColor = Color(0xFF017400);
  static const Color _negativeColor = Color(0xFF9F0202);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatsHeader(),
        _buildComparisonLine(),
        const SizedBox(height: 0.0),
        _buildChartToggle(),
        const SizedBox(height: 10.0),
        _buildChartArea(context),
      ],
    );
  }

  /// Builds the stats header with total count.
  Widget _buildStatsHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 5.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 5.0),
              child: Text(
                '${stats.totalCount}',
                style: GoogleFonts.interTight(
                  fontSize: 30.0,
                  fontWeight: FontWeight.w600,
                  color: _primary,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 5.0, top: 5.0),
              child: Text(
                'Total',
                style: GoogleFonts.interTight(
                  fontSize: 26.0,
                  color: _primaryText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the comparison line with prior count and percent change.
  Widget _buildComparisonLine() {
    final percentChange = stats.percentChange;
    final showPercent = percentChange != null && percentChange != 0;
    final percentText = percentChange != null
        ? '${(percentChange * 100).toStringAsFixed(1)}%'
        : '';

    final percentColor = stats.isPositive
        ? _positiveColor
        : stats.isNegative
            ? _negativeColor
            : _primaryText;

    return Padding(
      padding: const EdgeInsets.fromLTRB(15.0, 0.0, 15.0, 0.0),
      child: Row(
        children: [
          Text(
            'vs ',
            style: GoogleFonts.interTight(
              fontSize: 15.0,
              color: _primaryText,
            ),
          ),
          Text(
            '${stats.priorPeriodCount}',
            style: GoogleFonts.interTight(
              fontSize: 15.0,
              color: _primaryText,
            ),
          ),
          if (showPercent) ...[
            Padding(
              padding: const EdgeInsets.only(left: 10.0),
              child: Text(
                percentText,
                style: GoogleFonts.interTight(
                  fontSize: 15.0,
                  color: percentColor,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 5.0),
              child: Text(
                stats.periodLabel,
                style: GoogleFonts.inter(
                  fontSize: 15.0,
                  color: _primaryText,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Builds the chart type toggle switch.
  Widget _buildChartToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10.0, 0.0, 10.0, 0.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            'Increments',
            style: GoogleFonts.inter(
              fontSize: 12.0,
              color: _primaryText,
            ),
          ),
          Switch.adaptive(
            value: showCumulative,
            onChanged: onChartTypeChanged,
            activeColor: _primary,
            inactiveTrackColor: const Color(0xFFA158FF),
          ),
          Text(
            'Cumulative',
            style: GoogleFonts.inter(
              fontSize: 12.0,
              color: _primaryText,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the chart area with BlocBuilder for loading/error/chart states.
  Widget _buildChartArea(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: SizedBox(
        width: MediaQuery.of(context).size.width - 40,
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
}
