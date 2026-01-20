import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../domain/utils/interval_calculator.dart';

/// Section displaying high-level stats for the selected period/interval.
///
/// Shows summary metrics that span the entire interval, complementing
/// the chart which only shows up to 30 days at a time.
///
/// Adapts content based on selection:
/// - Specific interval: shows interval stats (total, duration, avg/day)
/// - All Time: shows lifetime stats (total increments ever, days since created)
///
/// Always displayed for consistent layout.
class PeriodStatsSection extends StatelessWidget {
  /// The selected interval data.
  final IntervalData interval;

  /// Display label for the period (e.g., "Current Period", "Period 3").
  final String periodLabel;

  /// Whether "All Time" is selected (intervalNumber == -1).
  bool get isAllTime => interval.intervalNumber == -1;

  const PeriodStatsSection({
    super.key,
    required this.interval,
    required this.periodLabel,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final primary = AppColors.primaryAdaptive(brightness);
    final alternate = AppColors.alternate(brightness);

    // Calculate derived stats
    final duration = interval.duration;
    final days = duration.inDays.clamp(1, double.infinity).toInt();
    final avgPerDay = interval.count / days;

    // Date range values for badge
    final startDate = interval.startTime;
    final endDate = interval.endTime ?? DateTime.now();

    // Header text from parent (e.g., "All Time", "Current Period", "Period 3")
    final headerText = periodLabel;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: alternate,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: primary.withValues(alpha: 0.08),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header with period label
          Row(
            children: [
              Icon(
                isAllTime ? Icons.all_inclusive_rounded : Icons.insights_rounded,
                size: 16.0,
                color: primary,
              ),
              const SizedBox(width: 6.0),
              Text(
                headerText,
                style: GoogleFonts.inter(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w600,
                  color: secondaryText,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              // Date range badge (long-press for precise times)
              _DateRangeBadge(
                startDate: startDate,
                endDate: endDate,
                isCurrent: interval.isCurrent,
                primary: primary,
                secondaryText: secondaryText,
              ),
            ],
          ),
          const SizedBox(height: 16.0),
          // Stats row - 3 columns
          Row(
            children: [
              // Total increments (hero stat)
              Expanded(
                flex: 2,
                child: _StatTile(
                  value: '+${interval.count}',
                  label: isAllTime ? 'Lifetime' : 'Total',
                  valueColor: primary,
                  isHero: true,
                ),
              ),
              _VerticalDivider(color: secondaryText.withValues(alpha: 0.15)),
              // Duration
              Expanded(
                child: _StatTile(
                  value: IntervalCalculator.formatDuration(duration),
                  label: isAllTime ? 'Tracking' : 'Duration',
                  valueColor: primaryText,
                ),
              ),
              _VerticalDivider(color: secondaryText.withValues(alpha: 0.15)),
              // Average per day
              Expanded(
                child: _StatTile(
                  value: avgPerDay.toStringAsFixed(1),
                  label: 'Avg/day',
                  valueColor: primaryText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A single stat tile with value and label.
class _StatTile extends StatelessWidget {
  final String value;
  final String label;
  final Color valueColor;
  final bool isHero;

  const _StatTile({
    required this.value,
    required this.label,
    required this.valueColor,
    this.isHero = false,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final secondaryText = AppColors.secondaryText(brightness);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          style: GoogleFonts.interTight(
            fontSize: isHero ? 24.0 : 18.0,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
        const SizedBox(height: 2.0),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.0,
            fontWeight: FontWeight.w500,
            color: secondaryText,
          ),
        ),
      ],
    );
  }
}

/// Vertical divider between stat tiles.
class _VerticalDivider extends StatelessWidget {
  final Color color;

  const _VerticalDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1.0,
      height: 36.0,
      margin: const EdgeInsets.symmetric(horizontal: 12.0),
      color: color,
    );
  }
}

/// Date range badge with long-press for precise times.
class _DateRangeBadge extends StatelessWidget {
  final DateTime startDate;
  final DateTime endDate;
  final bool isCurrent;
  final Color primary;
  final Color secondaryText;

  const _DateRangeBadge({
    required this.startDate,
    required this.endDate,
    required this.isCurrent,
    required this.primary,
    required this.secondaryText,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final displayText =
        '${dateFormat.format(startDate)} - ${isCurrent ? 'Now' : dateFormat.format(endDate)}';

    return GestureDetector(
      onLongPress: () => _showPreciseRange(context),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 8.0,
          vertical: 4.0,
        ),
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6.0),
        ),
        child: Text(
          displayText,
          style: GoogleFonts.inter(
            fontSize: 10.0,
            fontWeight: FontWeight.w500,
            color: secondaryText,
          ),
        ),
      ),
    );
  }

  /// Shows a snackbar with the precise date range down to the minute.
  void _showPreciseRange(BuildContext context) {
    final preciseFormat = DateFormat('MMM d, yyyy \'at\' h:mm a');
    final startText = preciseFormat.format(startDate);
    final endText = isCurrent ? 'Now' : preciseFormat.format(endDate);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$startText  →  $endText',
          style: GoogleFonts.inter(
            fontSize: 13.0,
            fontWeight: FontWeight.w500,
          ),
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
        margin: const EdgeInsets.all(16.0),
      ),
    );
  }
}
