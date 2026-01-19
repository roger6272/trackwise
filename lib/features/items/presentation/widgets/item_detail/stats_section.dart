import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/shimmer.dart';
import '../../../../charts/presentation/bloc/charts_bloc.dart';
import '../../../../charts/presentation/bloc/charts_state.dart';
import '../bar_chart_widget.dart';
import '../cumulative_chart_widget.dart';

/// Section displaying chart with toggle.
///
/// Shows:
/// - Chart header with title, key stat, and toggle
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

  /// The selected end date for the chart.
  final DateTime selectedDate;

  /// Total count for the period (key stat to display).
  final int periodTotal;

  const ChartSection({
    super.key,
    required this.showCumulative,
    required this.onChartTypeChanged,
    required this.range,
    required this.selectedDate,
    this.periodTotal = 0,
  });

  // Error color for chart error state
  static const Color _negativeColor = Color(0xFF9F0202);

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primary = AppColors.primaryAdaptive(brightness);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildChartHeader(context, primary),
        const SizedBox(height: 8.0),
        _buildChartArea(context, primary),
      ],
    );
  }

  /// Builds the chart header with hero stat and toggle.
  Widget _buildChartHeader(BuildContext context, Color primary) {
    final brightness = Theme.of(context).brightness;
    final secondaryText = AppColors.secondaryText(brightness);
    final alternate = AppColors.alternate(brightness);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          // Hero stat: +X increments
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
          const Spacer(),
          // Toggle
          _buildChartToggle(context, primary, alternate, secondaryText),
        ],
      ),
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
