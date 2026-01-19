import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../events/domain/entities/event_log.dart';
import '../../../domain/utils/interval_calculator.dart';

/// Section showing interval (reset period) statistics.
///
/// Displays a list of intervals with:
/// - Total row (all intervals combined)
/// - Individual intervals (most recent first)
///
/// Each row shows: interval number, duration, count.
class IntervalsSection extends StatelessWidget {
  /// All events for the item (used to calculate intervals).
  final List<EventLog> events;

  /// Maximum number of intervals to display (excluding total).
  final int maxIntervals;

  const IntervalsSection({
    super.key,
    required this.events,
    this.maxIntervals = 10,
  });

  @override
  Widget build(BuildContext context) {
    final intervals = IntervalCalculator.calculate(
      events: events,
      maxIntervals: maxIntervals,
    );

    if (intervals.isEmpty) {
      return const SizedBox.shrink();
    }

    final brightness = Theme.of(context).brightness;
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final alternate = AppColors.alternate(brightness);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
          child: Text(
            'Intervals',
            style: GoogleFonts.inter(
              fontSize: 13.0,
              fontWeight: FontWeight.w500,
              color: secondaryText,
            ),
          ),
        ),
        // Intervals list
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
              // Header row
              _buildHeaderRow(primaryText, secondaryText),
              Container(
                height: 1.0,
                color: primaryText.withValues(alpha: 0.06),
              ),
              // Data rows
              ...intervals.asMap().entries.map((entry) {
                final index = entry.key;
                final interval = entry.value;
                final isLast = index == intervals.length - 1;
                return Column(
                  children: [
                    _buildIntervalRow(
                      interval: interval,
                      primaryText: primaryText,
                      secondaryText: secondaryText,
                      brightness: brightness,
                    ),
                    if (!isLast)
                      Container(
                        height: 1.0,
                        margin: const EdgeInsets.symmetric(horizontal: 14.0),
                        color: primaryText.withValues(alpha: 0.04),
                      ),
                  ],
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderRow(Color primaryText, Color secondaryText) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
      child: Row(
        children: [
          // Interval column
          SizedBox(
            width: 70,
            child: Text(
              'Interval',
              style: GoogleFonts.inter(
                fontSize: 11.0,
                fontWeight: FontWeight.w600,
                color: secondaryText,
              ),
            ),
          ),
          // Duration column
          Expanded(
            child: Text(
              'Duration',
              style: GoogleFonts.inter(
                fontSize: 11.0,
                fontWeight: FontWeight.w600,
                color: secondaryText,
              ),
            ),
          ),
          // Count column
          SizedBox(
            width: 70,
            child: Text(
              'Count',
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 11.0,
                fontWeight: FontWeight.w600,
                color: secondaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntervalRow({
    required IntervalData interval,
    required Color primaryText,
    required Color secondaryText,
    required Brightness brightness,
  }) {
    final isTotal = interval.intervalNumber == -1;
    final isCurrent = interval.isCurrent && !isTotal;

    // Format interval label
    final String intervalLabel;
    if (isTotal) {
      intervalLabel = 'Total';
    } else if (isCurrent) {
      intervalLabel = '#${interval.intervalNumber}';
    } else {
      intervalLabel = '#${interval.intervalNumber}';
    }

    // Format duration
    final durationText = IntervalCalculator.formatDuration(interval.duration);

    // Calculate max count for visual bar (excluding total)
    // We'll use the count value directly for now

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
      child: Row(
        children: [
          // Interval number/label
          SizedBox(
            width: 70,
            child: Row(
              children: [
                if (isTotal)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 3.0,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryAdaptive(brightness).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                    child: Text(
                      intervalLabel,
                      style: GoogleFonts.inter(
                        fontSize: 12.0,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryAdaptive(brightness),
                      ),
                    ),
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        intervalLabel,
                        style: GoogleFonts.inter(
                          fontSize: 13.0,
                          fontWeight: FontWeight.w500,
                          color: primaryText,
                        ),
                      ),
                      if (isCurrent) ...[
                        const SizedBox(width: 4),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
          // Duration
          Expanded(
            child: Text(
              isCurrent ? '$durationText (ongoing)' : durationText,
              style: GoogleFonts.inter(
                fontSize: 13.0,
                fontWeight: FontWeight.w400,
                color: isCurrent ? secondaryText : primaryText.withValues(alpha: 0.7),
              ),
            ),
          ),
          // Count
          SizedBox(
            width: 70,
            child: Text(
              interval.count.toString(),
              textAlign: TextAlign.right,
              style: GoogleFonts.interTight(
                fontSize: 14.0,
                fontWeight: isTotal ? FontWeight.w700 : FontWeight.w600,
                color: isTotal
                    ? AppColors.primaryAdaptive(brightness)
                    : primaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
