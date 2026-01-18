import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/theme/app_colors.dart';

/// Widget displaying summary statistics cards with slide/fade animations.
///
/// Shows 6 cards in 3 rows:
/// - Row 1: Current Count, Initial Count
/// - Row 2: Average Count, Highest Count
/// - Row 3: Lowest Count, Placeholder
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
    debugPrint('📊 SummaryCards - goal: ${widget.goal}, currentCount: ${widget.currentCount}, initialCount: ${widget.initialCount}');
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
          children: [
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
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: _SummaryCard(
                    value: widget.currentCount.toString(),
                    label: 'Current Count',
                    width: cardWidth,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
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
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: _SummaryCard(
                    value: widget.average.toStringAsFixed(1),
                    label: 'Average Count',
                    width: cardWidth,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: _SummaryCard(
                    value: widget.highestCount.toString(),
                    label: 'Highest Count',
                    width: cardWidth,
                  ),
                ),
              ],
            ),
            // Row 3: Lowest Count, Placeholder
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: _SummaryCard(
                    value: widget.lowestCount.toString(),
                    label: 'Lowest Count',
                    width: cardWidth,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: _SummaryCard(
                    value: '-',
                    label: 'Coming Soon',
                    width: cardWidth,
                  ),
                ),
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
      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: secondaryBackground,
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Progress to Goal',
                  style: GoogleFonts.inter(
                    fontSize: 14.0,
                    fontWeight: FontWeight.w600,
                    color: primaryText,
                  ),
                ),
                Text(
                  '$currentCount / $goal',
                  style: GoogleFonts.inter(
                    fontSize: 14.0,
                    fontWeight: FontWeight.w600,
                    color: primaryText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12.0),
            ClipRRect(
              borderRadius: BorderRadius.circular(4.0),
              child: LinearProgressIndicator(
                value: progressFraction,
                minHeight: 8.0,
                backgroundColor: secondaryText.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isComplete ? Colors.green : AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 8.0),
            Text(
              isComplete
                  ? 'Goal reached!'
                  : '$progressPercent% complete ($remaining remaining)',
              style: GoogleFonts.inter(
                fontSize: 12.0,
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
    final secondaryBackground = AppColors.secondaryBackground(brightness);
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);

    return Container(
      width: width,
      height: 80.0,
      decoration: BoxDecoration(
        color: secondaryBackground,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: alternate,
          width: 0.0,
        ),
      ),
      padding: const EdgeInsets.all(12.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0.0, 4.0, 0.0, 2.0),
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: GoogleFonts.interTight(
                fontSize: 20.0,
                fontWeight: FontWeight.w600,
                color: primaryText,
              ),
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
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
