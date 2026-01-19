import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../domain/utils/interval_calculator.dart';

/// Represents a selectable interval option.
class IntervalOption {
  /// Interval number (-1 for "All Time").
  final int intervalNumber;

  /// Display label (e.g., "Current (#3)", "#2", "All Time").
  final String label;

  /// Start time of the interval.
  final DateTime? startTime;

  /// Count of increments in this interval.
  final int count;

  /// Whether this is the current (ongoing) interval.
  final bool isCurrent;

  const IntervalOption({
    required this.intervalNumber,
    required this.label,
    this.startTime,
    required this.count,
    this.isCurrent = false,
  });

  /// Create "All Time" option.
  factory IntervalOption.allTime(int totalCount) {
    return IntervalOption(
      intervalNumber: -1,
      label: 'All Time',
      count: totalCount,
    );
  }

  /// Create from IntervalData.
  factory IntervalOption.fromIntervalData(IntervalData data, bool isCurrent) {
    final label = isCurrent
        ? 'Current (#${data.intervalNumber})'
        : '#${data.intervalNumber}';
    return IntervalOption(
      intervalNumber: data.intervalNumber,
      label: label,
      startTime: data.startTime,
      count: data.count,
      isCurrent: isCurrent,
    );
  }
}

/// Full-width dropdown for selecting intervals.
///
/// Shows interval options with start time and count.
/// Scrollable with ~5 visible items.
class IntervalDropdown extends StatelessWidget {
  /// List of interval options to display.
  final List<IntervalOption> options;

  /// Currently selected interval number (-1 for All Time).
  final int selectedInterval;

  /// Callback when interval is selected.
  final ValueChanged<int> onChanged;

  const IntervalDropdown({
    super.key,
    required this.options,
    required this.selectedInterval,
    required this.onChanged,
  });

  /// Build options from interval data list.
  static List<IntervalOption> buildOptions(List<IntervalData> intervals) {
    if (intervals.isEmpty) {
      return [IntervalOption.allTime(0)];
    }

    final options = <IntervalOption>[];

    // Find total row (intervalNumber == -1)
    final totalRow = intervals.where((i) => i.intervalNumber == -1).firstOrNull;
    options.add(IntervalOption.allTime(totalRow?.count ?? 0));

    // Add individual intervals (skip total row)
    final individualIntervals =
        intervals.where((i) => i.intervalNumber >= 0).toList();

    for (int i = 0; i < individualIntervals.length; i++) {
      final interval = individualIntervals[i];
      final isCurrent = i == 0; // First one is most recent (current)
      options.add(IntervalOption.fromIntervalData(interval, isCurrent));
    }

    return options;
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final alternate = AppColors.alternate(brightness);
    final primary = AppColors.primaryAdaptive(brightness);

    // Find selected option
    final selectedOption = options.firstWhere(
      (o) => o.intervalNumber == selectedInterval,
      orElse: () => options.first,
    );

    return Container(
      decoration: BoxDecoration(
        color: alternate,
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(
          color: primaryText.withValues(alpha: 0.08),
          width: 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10.0),
          onTap: () => _showDropdownMenu(context),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
            child: Row(
              children: [
                Icon(
                  Icons.filter_list_rounded,
                  size: 18.0,
                  color: secondaryText,
                ),
                const SizedBox(width: 10.0),
                Expanded(
                  child: _buildSelectedLabel(
                    selectedOption,
                    primaryText,
                    secondaryText,
                    primary,
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20.0,
                  color: secondaryText,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedLabel(
    IntervalOption option,
    Color primaryText,
    Color secondaryText,
    Color primary,
  ) {
    final dateFormat = DateFormat('MMM d h:mm a');

    return Row(
      children: [
        Text(
          option.label,
          style: GoogleFonts.inter(
            fontSize: 13.0,
            fontWeight: FontWeight.w600,
            color: primaryText,
          ),
        ),
        if (option.startTime != null) ...[
          Text(
            '  ·  From ${dateFormat.format(option.startTime!)}',
            style: GoogleFonts.inter(
              fontSize: 12.0,
              fontWeight: FontWeight.w400,
              color: secondaryText,
            ),
          ),
        ],
        Text(
          '  ·  ${option.count}',
          style: GoogleFonts.inter(
            fontSize: 12.0,
            fontWeight: FontWeight.w500,
            color: primary,
          ),
        ),
      ],
    );
  }

  void _showDropdownMenu(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final alternate = AppColors.alternate(brightness);
    final primary = AppColors.primaryAdaptive(brightness);
    final primaryBackground = AppColors.primaryBackground(brightness);

    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final buttonPosition = button.localToGlobal(Offset.zero, ancestor: overlay);

    final dateFormat = DateFormat('MMM d h:mm a');

    // Calculate menu height (max 5 items visible, ~52px each)
    final itemHeight = 52.0;
    final maxVisibleItems = 5;
    final menuHeight = (options.length > maxVisibleItems
            ? maxVisibleItems * itemHeight
            : options.length * itemHeight) +
        16.0; // padding

    showMenu<int>(
      context: context,
      position: RelativeRect.fromLTRB(
        buttonPosition.dx,
        buttonPosition.dy + button.size.height + 4.0,
        buttonPosition.dx + button.size.width,
        buttonPosition.dy + button.size.height + menuHeight + 4.0,
      ),
      constraints: BoxConstraints(
        minWidth: button.size.width,
        maxWidth: button.size.width,
        maxHeight: menuHeight,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      color: primaryBackground,
      elevation: 8.0,
      items: options.map((option) {
        final isSelected = option.intervalNumber == selectedInterval;
        return PopupMenuItem<int>(
          value: option.intervalNumber,
          height: itemHeight,
          padding: EdgeInsets.zero,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: isSelected ? primary.withValues(alpha: 0.08) : null,
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Row(
              children: [
                // Current indicator dot
                if (option.isCurrent)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 8.0),
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  )
                else
                  const SizedBox(width: 14.0),
                // Label
                Text(
                  option.label,
                  style: GoogleFonts.inter(
                    fontSize: 13.0,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? primary : primaryText,
                  ),
                ),
                const SizedBox(width: 8.0),
                // Start time
                if (option.startTime != null)
                  Expanded(
                    child: Text(
                      'From ${dateFormat.format(option.startTime!)}',
                      style: GoogleFonts.inter(
                        fontSize: 11.0,
                        fontWeight: FontWeight.w400,
                        color: secondaryText,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                else
                  const Expanded(child: SizedBox()),
                // Count
                Text(
                  '${option.count}',
                  style: GoogleFonts.inter(
                    fontSize: 12.0,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? primary : secondaryText,
                  ),
                ),
                // Check mark for selected
                if (isSelected) ...[
                  const SizedBox(width: 8.0),
                  Icon(
                    Icons.check_rounded,
                    size: 16.0,
                    color: primary,
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    ).then((value) {
      if (value != null) {
        onChanged(value);
      }
    });
  }
}
