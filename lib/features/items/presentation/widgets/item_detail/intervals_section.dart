import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../events/domain/entities/event_log.dart';
import '../../../domain/utils/interval_calculator.dart';

/// Section showing interval (reset period) statistics.
///
/// Displays a list of intervals with:
/// - Total row (all intervals combined)
/// - Individual intervals (most recent first, limited to [visibleIntervals])
///
/// Each row shows: interval number, duration, count.
/// Selected interval is highlighted.
class IntervalsSection extends StatelessWidget {
  /// All events for the item (used to calculate intervals).
  final List<EventLog> events;

  /// Maximum number of intervals to calculate.
  final int maxIntervals;

  /// Number of intervals visible before scrolling (excluding total).
  final int visibleIntervals;

  /// Currently selected interval number (-1 for All Time/Total).
  final int selectedInterval;

  /// Callback when an interval row is tapped.
  final ValueChanged<int>? onIntervalTap;

  const IntervalsSection({
    super.key,
    required this.events,
    this.maxIntervals = 100,
    this.visibleIntervals = 5,
    this.selectedInterval = -1,
    this.onIntervalTap,
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

    // Calculate height for scrollable area
    // Total row + visibleIntervals individual intervals + header
    final rowHeight = 44.0;
    final headerHeight = 36.0;
    final totalRows = intervals.length;
    final maxVisibleRows = visibleIntervals + 1; // +1 for Total row
    final needsScroll = totalRows > maxVisibleRows;
    final contentHeight = needsScroll
        ? (maxVisibleRows * rowHeight) + headerHeight
        : (totalRows * rowHeight) + headerHeight;

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
          height: contentHeight,
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
              // Header row (fixed)
              _buildHeaderRow(primaryText, secondaryText),
              Container(
                height: 1.0,
                color: primaryText.withValues(alpha: 0.06),
              ),
              // Data rows (scrollable if needed)
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  physics: needsScroll
                      ? const AlwaysScrollableScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
                  itemCount: intervals.length,
                  separatorBuilder: (context, index) => Container(
                    height: 1.0,
                    margin: const EdgeInsets.symmetric(horizontal: 14.0),
                    color: primaryText.withValues(alpha: 0.04),
                  ),
                  itemBuilder: (context, index) {
                    final interval = intervals[index];
                    final isSelected =
                        interval.intervalNumber == selectedInterval;
                    return _buildIntervalRow(
                      interval: interval,
                      isSelected: isSelected,
                      primaryText: primaryText,
                      secondaryText: secondaryText,
                      brightness: brightness,
                      onTap: onIntervalTap != null
                          ? () => onIntervalTap!(interval.intervalNumber)
                          : null,
                    );
                  },
                ),
              ),
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
    required bool isSelected,
    required Color primaryText,
    required Color secondaryText,
    required Brightness brightness,
    VoidCallback? onTap,
  }) {
    final isTotal = interval.intervalNumber == -1;
    final isCurrent = interval.isCurrent && !isTotal;
    final primary = AppColors.primaryAdaptive(brightness);

    // Format interval label
    final String intervalLabel;
    if (isTotal) {
      intervalLabel = 'Total';
    } else {
      intervalLabel = '#${interval.intervalNumber}';
    }

    // Format duration
    final durationText = IntervalCalculator.formatDuration(interval.duration);

    return Material(
      color: isSelected ? primary.withValues(alpha: 0.08) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
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
                          color: isSelected
                              ? primary
                              : primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        child: Text(
                          intervalLabel,
                          style: GoogleFonts.inter(
                            fontSize: 12.0,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : primary,
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
                              fontWeight:
                                  isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected ? primary : primaryText,
                            ),
                          ),
                          if (isCurrent) ...[
                            const SizedBox(width: 4),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
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
                    color: isSelected
                        ? primary
                        : (isCurrent
                            ? secondaryText
                            : primaryText.withValues(alpha: 0.7)),
                  ),
                ),
              ),
              // Count
              SizedBox(
                width: 70,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      interval.count.toString(),
                      style: GoogleFonts.interTight(
                        fontSize: 14.0,
                        fontWeight: isTotal || isSelected
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: isTotal || isSelected ? primary : primaryText,
                      ),
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.check_rounded,
                        size: 14.0,
                        color: primary,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
