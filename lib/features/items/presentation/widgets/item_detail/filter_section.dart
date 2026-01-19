import 'package:flutter/material.dart';

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
    return IntervalDropdown(
      options: IntervalDropdown.buildOptions(intervals),
      selectedInterval: selectedInterval,
      onChanged: onIntervalChanged,
    );
  }
}
