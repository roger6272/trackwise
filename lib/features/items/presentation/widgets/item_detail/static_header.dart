import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/theme/app_colors.dart';

/// Static header displaying current count and initial value.
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

  const StaticHeader({
    super.key,
    required this.currentCount,
    required this.initialCount,
    this.goal,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    const primary = AppColors.primary;
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final alternate = AppColors.alternate(brightness);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 12.0),
      child: Column(
        children: [
          // Main count row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Current count (hero number)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentCount.toString(),
                      style: GoogleFonts.interTight(
                        fontSize: 48.0,
                        fontWeight: FontWeight.w700,
                        color: primary,
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
              ),
              // Initial value badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12.0,
                  vertical: 8.0,
                ),
                decoration: BoxDecoration(
                  color: alternate,
                  borderRadius: BorderRadius.circular(10.0),
                  border: Border.all(
                    color: primaryText.withValues(alpha: 0.06),
                    width: 1.0,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      initialCount.toString(),
                      style: GoogleFonts.interTight(
                        fontSize: 20.0,
                        fontWeight: FontWeight.w600,
                        color: primaryText,
                      ),
                    ),
                    Text(
                      'Initial',
                      style: GoogleFonts.inter(
                        fontSize: 11.0,
                        fontWeight: FontWeight.w500,
                        color: secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Goal progress (if set)
          if (goal != null) ...[
            const SizedBox(height: 12.0),
            _buildGoalProgress(
              context: context,
              currentCount: currentCount,
              initialCount: initialCount,
              goal: goal!,
              primary: primary,
              primaryText: primaryText,
              secondaryText: secondaryText,
              alternate: alternate,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGoalProgress({
    required BuildContext context,
    required int currentCount,
    required int initialCount,
    required int goal,
    required Color primary,
    required Color primaryText,
    required Color secondaryText,
    required Color alternate,
  }) {
    // Calculate progress: how far from initial to goal
    final totalRange = goal - initialCount;
    final currentProgress = currentCount - initialCount;

    // Clamp progress between 0 and 1
    final progressFraction = totalRange > 0
        ? (currentProgress / totalRange).clamp(0.0, 1.0)
        : (currentCount >= goal ? 1.0 : 0.0);

    final progressPercent = (progressFraction * 100).toInt();
    final remaining = goal - currentCount;
    final isComplete = currentCount >= goal;

    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: alternate,
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(
          color: (isComplete ? Colors.green : primary).withValues(alpha: 0.15),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isComplete
                        ? Icons.check_circle_rounded
                        : Icons.flag_rounded,
                    size: 14.0,
                    color: isComplete ? Colors.green : primary,
                  ),
                  const SizedBox(width: 6.0),
                  Text(
                    'Goal',
                    style: GoogleFonts.inter(
                      fontSize: 12.0,
                      fontWeight: FontWeight.w500,
                      color: secondaryText,
                    ),
                  ),
                ],
              ),
              Text(
                '$currentCount / $goal',
                style: GoogleFonts.interTight(
                  fontSize: 13.0,
                  fontWeight: FontWeight.w600,
                  color: primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          ClipRRect(
            borderRadius: BorderRadius.circular(3.0),
            child: LinearProgressIndicator(
              value: progressFraction,
              minHeight: 5.0,
              backgroundColor: secondaryText.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(
                isComplete ? Colors.green : primary,
              ),
            ),
          ),
          const SizedBox(height: 6.0),
          Text(
            isComplete
                ? 'Goal reached!'
                : '$progressPercent% complete \u2022 $remaining to go',
            style: GoogleFonts.inter(
              fontSize: 11.0,
              color: isComplete ? Colors.green : secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}
