import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/shimmer.dart';

/// Shimmer skeleton for the hero stats section.
class HeroStatsSkeleton extends StatelessWidget {
  const HeroStatsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10.0, 16.0, 10.0, 12.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Large count placeholder
          const ShimmerBox(width: 100, height: 56, borderRadius: 8),
          const SizedBox(height: 8.0),
          // "Total" label placeholder
          const ShimmerText(width: 50, height: 16),
          const SizedBox(height: 12.0),
          // Trend badge placeholder
          const ShimmerBox(width: 160, height: 34, borderRadius: 17),
        ],
      ),
    );
  }
}

/// Shimmer skeleton for the chart area.
class ChartSkeleton extends StatelessWidget {
  const ChartSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width - 40;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: SizedBox(
        width: width,
        height: 220.0,
        child: Column(
          children: [
            // Chart toggle placeholder
            Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: const [
                  ShimmerText(width: 60, height: 14),
                  SizedBox(width: 8),
                  ShimmerBox(width: 40, height: 24, borderRadius: 12),
                  SizedBox(width: 8),
                  ShimmerText(width: 70, height: 14),
                ],
              ),
            ),
            // Chart area placeholder
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Y-axis labels
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(
                      5,
                      (index) => const ShimmerText(width: 24, height: 10),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Bars
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(
                        7,
                        (index) => ShimmerBox(
                          width: 24,
                          height: 40.0 + (index * 15.0) % 100,
                          borderRadius: 4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // X-axis labels
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                7,
                (index) => const ShimmerText(width: 28, height: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shimmer skeleton for the summary cards section.
class SummaryCardsSkeleton extends StatelessWidget {
  const SummaryCardsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final cardWidth = MediaQuery.sizeOf(context).width * 0.42;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header placeholder
        const Padding(
          padding: EdgeInsets.only(left: 4.0, bottom: 12.0),
          child: ShimmerText(width: 80, height: 16),
        ),
        // Card rows
        _buildCardRow(cardWidth),
        const SizedBox(height: 12),
        _buildCardRow(cardWidth),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildCardSkeleton(cardWidth),
            SizedBox(width: cardWidth), // Empty space for alignment
          ],
        ),
      ],
    );
  }

  Widget _buildCardRow(double cardWidth) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildCardSkeleton(cardWidth),
        _buildCardSkeleton(cardWidth),
      ],
    );
  }

  Widget _buildCardSkeleton(double width) {
    return ShimmerBox(
      width: width,
      height: 72,
      borderRadius: 10,
    );
  }
}

/// Shimmer skeleton for the entire stats section (hero + chart).
class StatsSectionSkeleton extends StatelessWidget {
  const StatsSectionSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final alternate = AppColors.alternate(brightness);

    return Container(
      decoration: BoxDecoration(
        color: alternate,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.1),
          width: 1.0,
        ),
      ),
      child: const Column(
        children: [
          HeroStatsSkeleton(),
          ChartSkeleton(),
        ],
      ),
    );
  }
}
