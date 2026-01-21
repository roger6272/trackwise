import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../domain/utils/interval_calculator.dart';
import 'interval_dropdown.dart';

/// A simple filter section widget for the item detail page.
///
/// Provides controls for:
/// - Interval selection dropdown (filters data by reset period)
class FilterSection extends StatelessWidget {
  const FilterSection({
    super.key,
    required this.intervals,
    required this.selectedInterval,
    required this.onIntervalChanged,
  });

  /// Interval data for the dropdown.
  final List<IntervalData> intervals;

  /// Currently selected interval number (-1 for All Time).
  final int selectedInterval;

  /// Callback when interval is selected.
  final ValueChanged<int> onIntervalChanged;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final secondaryText = AppColors.secondaryText(brightness);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // External label
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
          child: Text(
            'Filter by Reset Cycle',
            style: GoogleFonts.inter(
              fontSize: 12.0,
              fontWeight: FontWeight.w600,
              color: secondaryText,
              letterSpacing: 0.3,
            ),
          ),
        ),
        // Dropdown
        IntervalDropdown(
          options: IntervalDropdown.buildOptions(intervals),
          selectedInterval: selectedInterval,
          onChanged: onIntervalChanged,
        ),
        const SizedBox(height: 8.0),
      ],
    );
  }
}
