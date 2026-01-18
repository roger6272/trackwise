import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/theme/app_colors.dart';

/// Hero stats display with animated count and trend badge.
///
/// Shows:
/// - Large animated current count (matches listing page)
/// - Period increments as secondary info
/// - Trend badge with percent change from prior period
class HeroStats extends StatefulWidget {
  /// The current count to display (initial + all increments).
  final int currentCount;

  /// Total increments for the selected period.
  final int periodIncrements;

  /// The prior period count for comparison.
  final int priorPeriodCount;

  /// Percent change from prior period (null if prior is 0).
  final double? percentChange;

  /// Period comparison label: 'DoD', 'WoW', or 'MoM'.
  final String periodLabel;

  const HeroStats({
    super.key,
    required this.currentCount,
    required this.periodIncrements,
    required this.priorPeriodCount,
    required this.percentChange,
    required this.periodLabel,
  });

  @override
  State<HeroStats> createState() => _HeroStatsState();
}

class _HeroStatsState extends State<HeroStats>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _countAnimation;
  int _previousCount = 0;

  // Semantic colors for trend indicators
  static const Color _positiveColor = Color(0xFF017400);
  static const Color _negativeColor = Color(0xFF9F0202);
  static const Color _neutralColor = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _countAnimation = Tween<double>(
      begin: 0,
      end: widget.currentCount.toDouble(),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
    _controller.forward();
  }

  @override
  void didUpdateWidget(HeroStats oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentCount != widget.currentCount) {
      _previousCount = oldWidget.currentCount;
      _countAnimation = Tween<double>(
        begin: _previousCount.toDouble(),
        end: widget.currentCount.toDouble(),
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ));
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    const primary = AppColors.primary;
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);

    return Padding(
      padding: const EdgeInsets.fromLTRB(10.0, 16.0, 10.0, 12.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated current count display
          AnimatedBuilder(
            animation: _countAnimation,
            builder: (context, child) {
              return Text(
                _countAnimation.value.round().toString(),
                style: GoogleFonts.interTight(
                  fontSize: 52.0,
                  fontWeight: FontWeight.w700,
                  color: primary,
                  height: 1.1,
                ),
              );
            },
          ),
          const SizedBox(height: 4.0),
          // "Current Count" label
          Text(
            'Current Count',
            style: GoogleFonts.inter(
              fontSize: 14.0,
              fontWeight: FontWeight.w500,
              color: primaryText.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8.0),
          // Period increments (secondary info)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Text(
              '+${widget.periodIncrements} this period',
              style: GoogleFonts.inter(
                fontSize: 13.0,
                fontWeight: FontWeight.w600,
                color: primary,
              ),
            ),
          ),
          const SizedBox(height: 10.0),
          // Trend badge
          _buildTrendBadge(primaryText, secondaryText),
        ],
      ),
    );
  }

  Widget _buildTrendBadge(Color primaryText, Color secondaryText) {
    final percentChange = widget.percentChange;
    final isPositive = percentChange != null && percentChange > 0;
    final isNegative = percentChange != null && percentChange < 0;

    // Determine badge color and icon
    final Color badgeColor;
    final Color textColor;
    final IconData icon;

    if (isPositive) {
      badgeColor = _positiveColor.withValues(alpha: 0.12);
      textColor = _positiveColor;
      icon = Icons.trending_up_rounded;
    } else if (isNegative) {
      badgeColor = _negativeColor.withValues(alpha: 0.12);
      textColor = _negativeColor;
      icon = Icons.trending_down_rounded;
    } else {
      badgeColor = _neutralColor.withValues(alpha: 0.12);
      textColor = _neutralColor;
      icon = Icons.trending_flat_rounded;
    }

    // Format percent text
    final percentText = percentChange != null
        ? '${isPositive ? '+' : ''}${(percentChange * 100).toStringAsFixed(1)}%'
        : '0%';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18.0,
            color: textColor,
          ),
          const SizedBox(width: 6.0),
          Text(
            percentText,
            style: GoogleFonts.interTight(
              fontSize: 14.0,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(width: 8.0),
          Container(
            width: 1,
            height: 14,
            color: textColor.withValues(alpha: 0.3),
          ),
          const SizedBox(width: 8.0),
          Text(
            'vs ${widget.priorPeriodCount}',
            style: GoogleFonts.inter(
              fontSize: 13.0,
              fontWeight: FontWeight.w500,
              color: textColor.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(width: 6.0),
          Text(
            widget.periodLabel,
            style: GoogleFonts.inter(
              fontSize: 12.0,
              fontWeight: FontWeight.w500,
              color: textColor.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
