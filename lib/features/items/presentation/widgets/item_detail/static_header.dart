import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../domain/entities/item.dart';
import '../../../domain/utils/interval_calculator.dart';

/// Item overview card displaying count ring, goal, date info, and config stats.
class StaticHeader extends StatelessWidget {
  /// The current count (initial + all increments).
  final int currentCount;

  /// The initial count when item was created.
  final int initialCount;

  /// Optional goal for progress display.
  final int? goal;

  /// Number of times the item has been reset.
  final int resetNumber;

  /// Whether the user is viewing the current (most recent) cycle.
  final bool isCurrentCycle;

  /// Whether the user is viewing "All Time" (summary across all cycles).
  final bool isAllTime;

  /// Count for the selected cycle (used when viewing a non-current cycle).
  final int? selectedCycleCount;

  /// Interval data for displaying date info below the ring.
  final IntervalData? selectedInterval;

  /// Amount incremented per press.
  final int incrementBy;

  /// Type of reminder configured for this item.
  final ReminderType reminderType;

  /// Value for the reminder (target count or interval).
  final int reminderValue;

  const StaticHeader({
    super.key,
    required this.currentCount,
    required this.initialCount,
    this.goal,
    this.resetNumber = 0,
    this.isCurrentCycle = true,
    this.isAllTime = false,
    this.selectedCycleCount,
    this.selectedInterval,
    this.incrementBy = 1,
    this.reminderType = ReminderType.none,
    this.reminderValue = 0,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primary = AppColors.primaryAdaptive(brightness);
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final secondaryBg = AppColors.secondaryBackground(brightness);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      decoration: BoxDecoration(
        color: secondaryBg,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: primary.withValues(alpha: 0.10),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.04),
            blurRadius: 12.0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: _buildGoalRing(context, primary, primaryText, secondaryText),
    );
  }

  Widget _buildGoalRing(
    BuildContext context,
    Color primary,
    Color primaryText,
    Color secondaryText,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final hasGoal = goal != null && isCurrentCycle;

    // Display count: for non-current cycles, show the cycle's count
    final displayCount = isCurrentCycle
        ? currentCount
        : (selectedCycleCount ?? 0);

    // Calculate progress
    double progressFraction = 0.0;
    int remaining = 0;
    bool isComplete = false;

    if (hasGoal) {
      progressFraction = goal! > 0
          ? (currentCount / goal!).clamp(0.0, 1.0)
          : (currentCount > 0 ? 1.0 : 0.0);
      remaining = goal! - currentCount;
      isComplete = currentCount >= goal!;
    }

    // Use teal-green success color which complements purple better
    const successColor = AppColors.success;
    final ringColor = isCurrentCycle
        ? (hasGoal
            ? (isComplete ? successColor : primary)
            : secondaryText.withValues(alpha: 0.2))
        : secondaryText.withValues(alpha: 0.2);

    return Column(
      children: [
        // Ring with count
        SizedBox(
          width: 190.0,
          height: 190.0,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background ring
              SizedBox(
                width: 190.0,
                height: 190.0,
                child: CustomPaint(
                  painter: _GoalRingPainter(
                    progress: hasGoal ? progressFraction : 0.0,
                    ringColor: ringColor,
                    backgroundColor: secondaryText.withValues(alpha: 0.08),
                    strokeWidth: 12.0,
                    hasGoal: hasGoal,
                  ),
                ),
              ),
              // Center content
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayCount.toString(),
                    style: textTheme.displayLarge?.copyWith(
                      fontSize: 52.0,
                      fontWeight: FontWeight.w800,
                      color: isCurrentCycle ? primary : secondaryText,
                      height: 1.0,
                      letterSpacing: -1.0,
                    ),
                  ),
                  const SizedBox(height: 6.0),
                  Text(
                    isCurrentCycle
                        ? ((initialCount > 0 && resetNumber == 0) ? 'from $initialCount' : 'Current Count')
                        : (isAllTime ? 'Total' : 'Cycle Total'),
                    style: textTheme.labelSmall?.copyWith(
                      fontSize: 12.0,
                      fontWeight: FontWeight.w600,
                      color: secondaryText,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Goal stats (only when goal is set AND viewing current cycle)
        if (hasGoal) ...[
          const SizedBox(height: 12.0),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: (isComplete ? successColor : primary)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isComplete ? Icons.check_circle_rounded : Icons.flag_rounded,
                  size: 16.0,
                  color: isComplete ? successColor : primary,
                ),
                const SizedBox(width: 6.0),
                Text(
                  isComplete
                      ? '$currentCount/${goal!} \u2022 Complete!'
                      : '${(progressFraction * 100).toInt()}% \u2022 $remaining to goal',
                  style: textTheme.bodyMedium?.copyWith(
                    fontSize: 13.0,
                    fontWeight: FontWeight.w600,
                    color: isComplete ? successColor : primary,
                  ),
                ),
              ],
            ),
          ),
        ],
        // Date info below ring
        if (selectedInterval != null) ...[
          const SizedBox(height: 10.0),
          _buildDateInfo(textTheme, secondaryText, primary),
        ],
        // Config stats (Per Press | Reminder) — grayed out for non-current cycles
        const SizedBox(height: 14.0),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.only(top: 14.0),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: secondaryText.withValues(alpha: 0.10),
                width: 1.0,
              ),
            ),
          ),
          child: Opacity(
            opacity: isCurrentCycle ? 1.0 : 0.4,
            child: _buildConfigStats(textTheme, primaryText, secondaryText),
          ),
        ),
      ],
    );
  }

  Widget _buildConfigStats(
    TextTheme textTheme,
    Color primaryText,
    Color secondaryText,
  ) {
    String reminderLabel;
    IconData reminderIcon;
    switch (reminderType) {
      case ReminderType.target:
        reminderLabel = '@ $reminderValue';
        reminderIcon = Icons.gps_fixed_rounded;
        break;
      case ReminderType.interval:
        reminderLabel = 'Every $reminderValue';
        reminderIcon = Icons.repeat_rounded;
        break;
      case ReminderType.none:
        reminderLabel = 'None';
        reminderIcon = Icons.notifications_off_outlined;
        break;
    }

    return Row(
      children: [
        Expanded(
          child: _buildStatItem(
            icon: Icons.add_rounded,
            label: 'Per Press',
            value: '+$incrementBy',
            primaryText: primaryText,
            secondaryText: secondaryText,
            textTheme: textTheme,
          ),
        ),
        Container(
          width: 1.0,
          height: 36.0,
          margin: const EdgeInsets.symmetric(horizontal: 12.0),
          color: secondaryText.withValues(alpha: 0.10),
        ),
        Expanded(
          child: _buildStatItem(
            icon: reminderIcon,
            label: 'Reminder',
            value: reminderLabel,
            primaryText: primaryText,
            secondaryText: secondaryText,
            textTheme: textTheme,
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color primaryText,
    required Color secondaryText,
    required TextTheme textTheme,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32.0,
          height: 32.0,
          decoration: BoxDecoration(
            color: secondaryText.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Icon(icon, size: 16.0, color: secondaryText),
        ),
        const SizedBox(width: 10.0),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: textTheme.titleSmall?.copyWith(
                fontSize: 14.0,
                color: primaryText,
              ),
            ),
            Text(
              label,
              style: textTheme.labelSmall?.copyWith(
                fontSize: 11.0,
                color: secondaryText,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDateInfo(
    TextTheme textTheme,
    Color secondaryText,
    Color primary,
  ) {
    final interval = selectedInterval!;

    if (isCurrentCycle) {
      // Current cycle: "Started [date]"
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today_rounded,
            size: 12.0,
            color: secondaryText.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 5.0),
          Text(
            'Started ${_formatDate(interval.startTime)}',
            style: textTheme.labelSmall?.copyWith(
              fontSize: 11.0,
              color: secondaryText.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    // Historical / All Time: "[date] → [date/Now] · X days"
    final startStr = _formatDate(interval.startTime);
    final endStr = isAllTime || interval.isCurrent
        ? 'Now'
        : _formatDate(interval.endTime!);
    final days = interval.duration.inDays;
    final daysLabel = days == 1 ? '1 day' : '$days days';

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.date_range_rounded,
          size: 12.0,
          color: secondaryText.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 5.0),
        Flexible(
          child: Text(
            '$startStr \u2192 $endStr \u2022 $daysLabel',
            style: textTheme.labelSmall?.copyWith(
              fontSize: 11.0,
              color: secondaryText.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, h:mm a').format(date);
  }

}

/// Custom painter for the goal progress ring.
class _GoalRingPainter extends CustomPainter {
  final double progress;
  final Color ringColor;
  final Color backgroundColor;
  final double strokeWidth;
  final bool hasGoal;

  _GoalRingPainter({
    required this.progress,
    required this.ringColor,
    required this.backgroundColor,
    required this.strokeWidth,
    required this.hasGoal,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background circle
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Progress arc (only if has goal and progress > 0)
    if (hasGoal && progress > 0) {
      final progressPaint = Paint()
        ..color = ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      final sweepAngle = 2 * math.pi * progress;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, // Start from top
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GoalRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.ringColor != ringColor ||
        oldDelegate.hasGoal != hasGoal;
  }
}
