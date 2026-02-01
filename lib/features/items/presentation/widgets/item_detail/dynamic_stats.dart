import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../domain/utils/stats_calculator.dart';

/// Dynamic stats section showing period-dependent statistics.
///
/// All values in this section are affected by the selected filters
/// (date, aggregation period, reset toggle).
///
/// Shows:
/// - Initial count (actual value if never reset, 0 if reset occurred)
/// - Period increments with trend comparison
/// - Average and range for the period
class DynamicStats extends StatelessWidget {
  /// Pre-calculated statistics for the selected period.
  final StatsResult stats;

  /// The aggregation range label: '1D', '7D', or '30D'.
  final String range;

  /// The initial count when item was created.
  final int initialCount;

  /// Last reset time - null means item was never reset.
  final DateTime? lastResetTime;

  /// Whether "Since Last Reset" filter is active.
  final bool showSinceReset;

  const DynamicStats({
    super.key,
    required this.stats,
    required this.range,
    required this.initialCount,
    required this.lastResetTime,
    required this.showSinceReset,
  });


  /// Returns the initial count display value based on filters.
  /// - All time (toggle OFF): show actual initialCount
  /// - Since Reset (toggle ON) + was reset: show 0
  /// - Since Reset (toggle ON) + never reset: show initialCount
  String _getInitialCountDisplay() {
    if (!showSinceReset) {
      // All time mode - show actual initial count
      return initialCount.toString();
    }
    // Since Reset mode - show 0 only if actually reset
    if (lastResetTime != null) {
      return '0';
    }
    return initialCount.toString();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textTheme = Theme.of(context).textTheme;
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final alternate = AppColors.alternate(brightness);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section sub-header (period badge is now in shared Results header)
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
          child: Text(
            'Statistics',
            style: textTheme.bodyMedium?.copyWith(
              fontSize: 13.0,
              fontWeight: FontWeight.w500,
              color: secondaryText,
            ),
          ),
        ),
        // Stats grid (2x2)
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
              // Row 1: Initial Count + Trend
              IntrinsicHeight(
                child: Row(
                  children: [
                    // Initial count (0 when since reset)
                    Expanded(
                      child: _buildStatCell(
                        value: _getInitialCountDisplay(),
                        label: 'Initial Count',
                        icon: Icons.start_rounded,
                        iconColor: secondaryText,
                        primaryText: primaryText,
                        secondaryText: secondaryText,
                        showRightBorder: true,
                        textTheme: textTheme,
                      ),
                    ),
                    // Trend comparison
                    Expanded(
                      child: _buildTrendCell(
                        primaryText: primaryText,
                        secondaryText: secondaryText,
                        textTheme: textTheme,
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
                        textTheme: textTheme,
                      ),
                    ),
                    // Range
                    Expanded(
                      child: _buildStatCell(
                        value: '${stats.minCount} – ${stats.maxCount}',
                        label: 'Range',
                        icon: Icons.swap_vert_rounded,
                        iconColor: secondaryText,
                        primaryText: primaryText,
                        secondaryText: secondaryText,
                        showRightBorder: false,
                        textTheme: textTheme,
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
    required TextTheme textTheme,
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
                  style: textTheme.titleSmall?.copyWith(
                    color: primaryText,
                  ),
                ),
                Text(
                  label,
                  style: textTheme.bodySmall?.copyWith(
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
    required TextTheme textTheme,
  }) {
    final percentChange = stats.percentChange;
    final isPositive = percentChange != null && percentChange > 0;
    final isNegative = percentChange != null && percentChange < 0;

    // Determine colors and icon
    final Color trendColor;
    final IconData trendIcon;

    if (isPositive) {
      trendColor = AppColors.positive;
      trendIcon = Icons.trending_up_rounded;
    } else if (isNegative) {
      trendColor = AppColors.negative;
      trendIcon = Icons.trending_down_rounded;
    } else {
      trendColor = AppColors.neutral;
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
                  style: textTheme.titleSmall?.copyWith(
                    color: trendColor,
                  ),
                ),
                Text(
                  'vs ${stats.priorPeriodCount} ${stats.periodLabel}',
                  style: textTheme.bodySmall?.copyWith(
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
