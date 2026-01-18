import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/theme/app_colors.dart';

/// Widget displaying summary statistics cards with slide/fade animations.
///
/// Shows 5 cards:
/// - Row 1: Current Count, Initial Count
/// - Row 2: Average Count, Highest Count
/// - Row 3: Lowest Count (centered)
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
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
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
    final cardWidth = MediaQuery.sizeOf(context).width * 0.42;
    final brightness = Theme.of(context).brightness;
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
                style: GoogleFonts.interTight(
                  fontSize: 16.0,
                  fontWeight: FontWeight.w600,
                  color: primaryText,
                ),
              ),
            ),
            // Progress bar (only shown when goal is set)
            if (widget.goal != null) _buildProgressBar(
              context: context,
              currentCount: widget.currentCount,
              initialCount: widget.initialCount,
              goal: widget.goal!,
              primaryText: primaryText,
              secondaryText: secondaryText,
              secondaryBackground: secondaryBackground,
            ),
            // Row 1: Current Count, Initial Count
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: _SummaryCard(
                    value: widget.currentCount.toString(),
                    label: 'Current Count',
                    width: cardWidth,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: _SummaryCard(
                    value: widget.initialCount.toString(),
                    label: 'Initial Count',
                    width: cardWidth,
                  ),
                ),
              ],
            ),
            // Row 2: Average Count, Highest Count
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: _SummaryCard(
                    value: widget.average.toStringAsFixed(1),
                    label: 'Average',
                    width: cardWidth,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: _SummaryCard(
                    value: widget.highestCount.toString(),
                    label: 'Highest',
                    width: cardWidth,
                  ),
                ),
              ],
            ),
            // Row 3: Lowest Count (centered)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: _SummaryCard(
                    value: widget.lowestCount.toString(),
                    label: 'Lowest',
                    width: cardWidth,
                  ),
                ),
                // Empty space to maintain alignment
                SizedBox(width: cardWidth),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar({
    required BuildContext context,
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
            color: (isComplete ? Colors.green : AppColors.primary).withValues(alpha: 0.2),
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
                  style: GoogleFonts.inter(
                    fontSize: 13.0,
                    fontWeight: FontWeight.w500,
                    color: secondaryText,
                  ),
                ),
                Text(
                  '$currentCount / $goal',
                  style: GoogleFonts.interTight(
                    fontSize: 14.0,
                    fontWeight: FontWeight.w600,
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
                  isComplete ? Colors.green : AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 6.0),
            Text(
              isComplete
                  ? 'Goal reached!'
                  : '$progressPercent% complete \u2022 $remaining remaining',
              style: GoogleFonts.inter(
                fontSize: 11.0,
                color: isComplete ? Colors.green : secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.value,
    required this.label,
    required this.width,
  });

  final String value;
  final String label;
  final double width;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final alternate = AppColors.alternate(brightness);
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);

    return Container(
      width: width,
      height: 72.0,
      decoration: BoxDecoration(
        color: alternate,
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(
          color: primaryText.withValues(alpha: 0.06),
          width: 1.0,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.interTight(
              fontSize: 22.0,
              fontWeight: FontWeight.w600,
              color: primaryText,
            ),
          ),
          const SizedBox(height: 2.0),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12.0,
              color: secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}
