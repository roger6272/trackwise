import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../domain/utils/interval_calculator.dart';

/// Summary card displaying total count and time range for the selected period.
///
/// Shows:
/// - Total count (hero stat)
/// - Time range stacked vertically (precise to minute)
class PeriodStatsSection extends StatelessWidget {
  /// The selected interval data.
  final IntervalData interval;

  const PeriodStatsSection({
    super.key,
    required this.interval,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final secondaryText = AppColors.secondaryText(brightness);
    final primary = AppColors.primaryAdaptive(brightness);
    final alternate = AppColors.alternate(brightness);

    final startDate = interval.startTime;
    final endDate = interval.endTime ?? DateTime.now();
    final isCurrent = interval.isCurrent;

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
          // Section header
          Row(
            children: [
              Icon(
                Icons.summarize_rounded,
                size: 16.0,
                color: primary,
              ),
              const SizedBox(width: 6.0),
              Text(
                'Summary',
                style: GoogleFonts.inter(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w600,
                  color: secondaryText,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0),
          // Stats row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Total count (hero stat)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '+${interval.count}',
                      style: GoogleFonts.interTight(
                        fontSize: 32.0,
                        fontWeight: FontWeight.w700,
                        color: primary,
                      ),
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      interval.intervalNumber == -1 ? 'lifetime' : 'total',
                      style: GoogleFonts.inter(
                        fontSize: 13.0,
                        fontWeight: FontWeight.w500,
                        color: secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              // Vertical divider
              Container(
                width: 1.0,
                height: 48.0,
                color: secondaryText.withValues(alpha: 0.15),
              ),
              // Time range stacked vertically
              Expanded(
                child: _TimeRangeDisplay(
                  startDate: startDate,
                  endDate: endDate,
                  isCurrent: isCurrent,
                  secondaryText: secondaryText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Displays time range stacked vertically with precise times.
class _TimeRangeDisplay extends StatelessWidget {
  final DateTime startDate;
  final DateTime endDate;
  final bool isCurrent;
  final Color secondaryText;

  const _TimeRangeDisplay({
    required this.startDate,
    required this.endDate,
    required this.isCurrent,
    required this.secondaryText,
  });

  @override
  Widget build(BuildContext context) {
    final dateTimeFormat = DateFormat('MMM d, h:mm a');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          dateTimeFormat.format(startDate),
          style: GoogleFonts.inter(
            fontSize: 14.0,
            fontWeight: FontWeight.w500,
            color: secondaryText,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3.0),
          child: Icon(
            Icons.arrow_downward_rounded,
            size: 14.0,
            color: secondaryText.withValues(alpha: 0.5),
          ),
        ),
        Text(
          isCurrent ? 'Now' : dateTimeFormat.format(endDate),
          style: GoogleFonts.inter(
            fontSize: 14.0,
            fontWeight: FontWeight.w600,
            color: secondaryText,
          ),
        ),
      ],
    );
  }
}
