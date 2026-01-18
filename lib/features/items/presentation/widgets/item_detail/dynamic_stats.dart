import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../domain/utils/stats_calculator.dart';

/// Dynamic stats section showing period-dependent statistics.
///
/// All values in this section are affected by the selected filters
/// (date, aggregation period, reset toggle).
///
/// Shows:
/// - Period increments with trend comparison
/// - Average and range for the period
class DynamicStats extends StatelessWidget {
  /// Pre-calculated statistics for the selected period.
  final StatsResult stats;

  /// The aggregation range label: '1D', '7D', or '30D'.
  final String range;

  const DynamicStats({
    super.key,
    required this.stats,
    required this.range,
  });

  // Semantic colors for trend indicators
  static const Color _positiveColor = Color(0xFF017400);
  static const Color _negativeColor = Color(0xFF9F0202);
  static const Color _neutralColor = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final alternate = AppColors.alternate(brightness);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 10.0),
          child: Row(
            children: [
              Text(
                'Period Statistics',
                style: GoogleFonts.interTight(
                  fontSize: 15.0,
                  fontWeight: FontWeight.w600,
                  color: primaryText,
                ),
              ),
              const SizedBox(width: 8.0),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6.0,
                  vertical: 2.0,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: Text(
                  _getPeriodLabel(),
                  style: GoogleFonts.inter(
                    fontSize: 10.0,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Stats grid
        Container(
          decoration: BoxDecoration(
            color: alternate,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(
              color: primaryText.withValues(alpha: 0.06),
              width: 1.0,
            ),
          ),
          child: Column(
            children: [
              // Row 1: Period Increments + Trend
              IntrinsicHeight(
                child: Row(
                  children: [
                    // Period increments
                    Expanded(
                      child: _buildStatCell(
                        value: '+${stats.totalCount}',
                        label: 'Increments',
                        icon: Icons.add_circle_outline_rounded,
                        iconColor: AppColors.primary,
                        primaryText: primaryText,
                        secondaryText: secondaryText,
                        showRightBorder: true,
                      ),
                    ),
                    // Trend comparison
                    Expanded(
                      child: _buildTrendCell(
                        primaryText: primaryText,
                        secondaryText: secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              // Divider
              Container(
                height: 1.0,
                color: primaryText.withValues(alpha: 0.06),
              ),
              // Row 2: Average + Range
              IntrinsicHeight(
                child: Row(
                  children: [
                    // Average
                    Expanded(
                      child: _buildStatCell(
                        value: stats.average.toStringAsFixed(1),
                        label: 'Avg / ${_getIntervalLabel()}',
                        icon: Icons.analytics_outlined,
                        iconColor: secondaryText,
                        primaryText: primaryText,
                        secondaryText: secondaryText,
                        showRightBorder: true,
                      ),
                    ),
                    // Range
                    Expanded(
                      child: _buildStatCell(
                        value: '${stats.minCount} - ${stats.maxCount}',
                        label: 'Range',
                        icon: Icons.swap_vert_rounded,
                        iconColor: secondaryText,
                        primaryText: primaryText,
                        secondaryText: secondaryText,
                        showRightBorder: false,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getPeriodLabel() {
    switch (range) {
      case '1D':
        return 'Today';
      case '7D':
        return 'Last 7 days';
      case '30D':
        return 'Last 30 days';
      default:
        return range;
    }
  }

  String _getIntervalLabel() {
    switch (range) {
      case '1D':
        return 'hour';
      case '7D':
      case '30D':
        return 'day';
      default:
        return 'interval';
    }
  }

  Widget _buildStatCell({
    required String value,
    required String label,
    required IconData icon,
    required Color iconColor,
    required Color primaryText,
    required Color secondaryText,
    required bool showRightBorder,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
      decoration: BoxDecoration(
        border: showRightBorder
            ? Border(
                right: BorderSide(
                  color: primaryText.withValues(alpha: 0.06),
                  width: 1.0,
                ),
              )
            : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6.0),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6.0),
            ),
            child: Icon(
              icon,
              size: 14.0,
              color: iconColor,
            ),
          ),
          const SizedBox(width: 10.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: GoogleFonts.interTight(
                    fontSize: 16.0,
                    fontWeight: FontWeight.w600,
                    color: primaryText,
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 10.0,
                    fontWeight: FontWeight.w500,
                    color: secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendCell({
    required Color primaryText,
    required Color secondaryText,
  }) {
    final percentChange = stats.percentChange;
    final isPositive = percentChange != null && percentChange > 0;
    final isNegative = percentChange != null && percentChange < 0;

    // Determine colors and icon
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

    // Format percent text
    final percentText = percentChange != null
        ? '${isPositive ? '+' : ''}${(percentChange * 100).toStringAsFixed(1)}%'
        : '0%';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6.0),
            decoration: BoxDecoration(
              color: trendColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6.0),
            ),
            child: Icon(
              trendIcon,
              size: 14.0,
              color: trendColor,
            ),
          ),
          const SizedBox(width: 10.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  percentText,
                  style: GoogleFonts.interTight(
                    fontSize: 16.0,
                    fontWeight: FontWeight.w600,
                    color: trendColor,
                  ),
                ),
                Text(
                  'vs ${stats.priorPeriodCount} ${stats.periodLabel}',
                  style: GoogleFonts.inter(
                    fontSize: 10.0,
                    fontWeight: FontWeight.w500,
                    color: secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
