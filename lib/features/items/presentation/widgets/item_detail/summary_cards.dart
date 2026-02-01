import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';

/// Widget displaying summary statistics cards with slide/fade animations.
///
/// Shows a balanced 2x2 grid of stat cards:
/// - Row 1: Current Count, Initial Count
/// - Row 2: Average, Range (High-Low)
class SummaryCards extends StatefulWidget {
  const SummaryCards({
    super.key,
    required this.currentCount,
    required this.average,
    required this.highestCount,
    required this.lowestCount,
    required this.initialCount,
    this.goal,
  });

  final int currentCount;
  final double average;
  final int highestCount;
  final int lowestCount;
  final int initialCount;
  final int? goal;

  @override
  State<SummaryCards> createState() => _SummaryCardsState();
}

class _SummaryCardsState extends State<SummaryCards>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textTheme = Theme.of(context).textTheme;
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final secondaryBackground = AppColors.secondaryBackground(brightness);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Padding(
              padding: const EdgeInsets.only(left: 4.0, bottom: 12.0),
              child: Text(
                'Statistics',
                style: textTheme.titleSmall?.copyWith(
                  color: primaryText,
                ),
              ),
            ),
            // Progress bar (only shown when goal is set)
            if (widget.goal != null)
              _buildProgressBar(
                context: context,
                textTheme: textTheme,
                currentCount: widget.currentCount,
                initialCount: widget.initialCount,
                goal: widget.goal!,
                primaryText: primaryText,
                secondaryText: secondaryText,
                secondaryBackground: secondaryBackground,
              ),
            // 2x2 Grid of stat cards
            _buildStatsGrid(context),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final alternate = AppColors.alternate(brightness);
    final primaryText = AppColors.primaryText(brightness);

    return Container(
      decoration: BoxDecoration(
        color: alternate,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(
          color: primaryText.withValues(alpha: 0.06),
          width: 1.0,
        ),
      ),
      child: Column(
        children: [
          // Row 1
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _GridStatCell(
                    value: widget.currentCount.toString(),
                    label: 'Current',
                    icon: Icons.tag_rounded,
                    showRightBorder: true,
                  ),
                ),
                Expanded(
                  child: _GridStatCell(
                    value: widget.initialCount.toString(),
                    label: 'Initial',
                    icon: Icons.start_rounded,
                    showRightBorder: false,
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
          // Row 2
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _GridStatCell(
                    value: widget.average.toStringAsFixed(1),
                    label: 'Average',
                    icon: Icons.analytics_outlined,
                    showRightBorder: true,
                  ),
                ),
                Expanded(
                  child: _GridStatCell(
                    value: '${widget.lowestCount} - ${widget.highestCount}',
                    label: 'Range',
                    icon: Icons.swap_vert_rounded,
                    showRightBorder: false,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar({
    required BuildContext context,
    required TextTheme textTheme,
    required int currentCount,
    required int initialCount,
    required int goal,
    required Color primaryText,
    required Color secondaryText,
    required Color secondaryBackground,
  }) {
    final brightness = Theme.of(context).brightness;
    final alternate = AppColors.alternate(brightness);

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

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Container(
        padding: const EdgeInsets.all(14.0),
        decoration: BoxDecoration(
          color: alternate,
          borderRadius: BorderRadius.circular(10.0),
          border: Border.all(
            color: (isComplete ? AppColors.success : AppColors.primary).withValues(alpha: 0.2),
            width: 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Goal Progress',
                  style: textTheme.bodyMedium?.copyWith(
                    fontSize: 13.0,
                    fontWeight: FontWeight.w500,
                    color: secondaryText,
                  ),
                ),
                Text(
                  '$currentCount / $goal',
                  style: textTheme.titleSmall?.copyWith(
                    fontSize: 14.0,
                    color: primaryText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10.0),
            ClipRRect(
              borderRadius: BorderRadius.circular(4.0),
              child: LinearProgressIndicator(
                value: progressFraction,
                minHeight: 6.0,
                backgroundColor: secondaryText.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isComplete ? AppColors.success : AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 6.0),
            Text(
              isComplete
                  ? 'Goal reached!'
                  : '$progressPercent% complete \u2022 $remaining remaining',
              style: textTheme.bodySmall?.copyWith(
                fontSize: 11.0,
                color: isComplete ? AppColors.success : secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single cell in the 2x2 stats grid.
class _GridStatCell extends StatelessWidget {
  const _GridStatCell({
    required this.value,
    required this.label,
    required this.icon,
    required this.showRightBorder,
  });

  final String value;
  final String label;
  final IconData icon;
  final bool showRightBorder;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textTheme = Theme.of(context).textTheme;
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
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
          // Icon container
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Icon(
              icon,
              size: 16.0,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12.0),
          // Value and label
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: textTheme.titleMedium?.copyWith(
                    color: primaryText,
                  ),
                ),
                const SizedBox(height: 1.0),
                Text(
                  label,
                  style: textTheme.bodySmall?.copyWith(
                    fontSize: 11.0,
                    fontWeight: FontWeight.w500,
                    color: secondaryText,
                    letterSpacing: 0.2,
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
