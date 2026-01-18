import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../domain/entities/item.dart';

/// Static header displaying current count with goal ring.
///
/// This section is NOT affected by filters - it shows the item's
/// current state regardless of date/aggregation selection.
class StaticHeader extends StatelessWidget {
  /// The current count (initial + all increments).
  final int currentCount;

  /// The initial count when item was created.
  final int initialCount;

  /// Optional goal for progress display.
  final int? goal;

  /// Amount incremented per event.
  final int incrementBy;

  /// Last reset timestamp.
  final DateTime? lastResetTime;

  /// Type of reminder configured.
  final ReminderType reminderType;

  /// Value for the reminder (target count or interval).
  final int reminderValue;

  const StaticHeader({
    super.key,
    required this.currentCount,
    required this.initialCount,
    this.goal,
    required this.incrementBy,
    this.lastResetTime,
    required this.reminderType,
    this.reminderValue = 0,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final alternate = AppColors.alternate(brightness);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 12.0),
      child: Container(
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          color: alternate,
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(
            color: primaryText.withValues(alpha: 0.06),
            width: 1.0,
          ),
        ),
        child: Column(
          children: [
            // Goal ring with current count
            _buildGoalRing(context, primaryText, secondaryText),
            const SizedBox(height: 20.0),
            // Item stats row
            _buildStatsRow(context, primaryText, secondaryText),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalRing(
    BuildContext context,
    Color primaryText,
    Color secondaryText,
  ) {
    final hasGoal = goal != null;

    // Calculate progress
    double progressFraction = 0.0;
    int remaining = 0;
    bool isComplete = false;

    if (hasGoal) {
      final totalRange = goal! - initialCount;
      final currentProgress = currentCount - initialCount;
      progressFraction = totalRange > 0
          ? (currentProgress / totalRange).clamp(0.0, 1.0)
          : (currentCount >= goal! ? 1.0 : 0.0);
      remaining = goal! - currentCount;
      isComplete = currentCount >= goal!;
    }

    final ringColor = hasGoal
        ? (isComplete ? Colors.green : AppColors.primary)
        : secondaryText.withValues(alpha: 0.2);

    return Column(
      children: [
        // Ring with count
        SizedBox(
          width: 180.0,
          height: 180.0,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background ring
              SizedBox(
                width: 180.0,
                height: 180.0,
                child: CustomPaint(
                  painter: _GoalRingPainter(
                    progress: hasGoal ? progressFraction : 0.0,
                    ringColor: ringColor,
                    backgroundColor: secondaryText.withValues(alpha: 0.1),
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
                    currentCount.toString(),
                    style: GoogleFonts.interTight(
                      fontSize: 48.0,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    'Current Count',
                    style: GoogleFonts.inter(
                      fontSize: 13.0,
                      fontWeight: FontWeight.w500,
                      color: secondaryText,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Goal stats (only when goal is set)
        if (hasGoal) ...[
          const SizedBox(height: 12.0),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: (isComplete ? Colors.green : AppColors.primary)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isComplete ? Icons.check_circle_rounded : Icons.flag_rounded,
                  size: 16.0,
                  color: isComplete ? Colors.green : AppColors.primary,
                ),
                const SizedBox(width: 6.0),
                Text(
                  isComplete
                      ? 'Goal reached!'
                      : '${(progressFraction * 100).toInt()}% \u2022 $remaining to goal',
                  style: GoogleFonts.inter(
                    fontSize: 13.0,
                    fontWeight: FontWeight.w600,
                    color: isComplete ? Colors.green : AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatsRow(
    BuildContext context,
    Color primaryText,
    Color secondaryText,
  ) {
    final dateFormat = DateFormat('MMM d');
    final lastResetLabel = lastResetTime != null
        ? dateFormat.format(lastResetTime!)
        : 'Never';

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
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatItem(
          icon: Icons.add_rounded,
          label: 'Increment',
          value: '+$incrementBy',
          primaryText: primaryText,
          secondaryText: secondaryText,
        ),
        _buildDivider(secondaryText),
        _buildStatItem(
          icon: Icons.refresh_rounded,
          label: 'Last Reset',
          value: lastResetLabel,
          primaryText: primaryText,
          secondaryText: secondaryText,
        ),
        _buildDivider(secondaryText),
        _buildStatItem(
          icon: reminderIcon,
          label: 'Reminder',
          value: reminderLabel,
          primaryText: primaryText,
          secondaryText: secondaryText,
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
  }) {
    return Column(
      children: [
        Icon(
          icon,
          size: 18.0,
          color: secondaryText,
        ),
        const SizedBox(height: 6.0),
        Text(
          value,
          style: GoogleFonts.interTight(
            fontSize: 14.0,
            fontWeight: FontWeight.w600,
            color: primaryText,
          ),
        ),
        const SizedBox(height: 2.0),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.0,
            color: secondaryText,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider(Color color) {
    return Container(
      width: 1.0,
      height: 36.0,
      color: color.withValues(alpha: 0.2),
    );
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
