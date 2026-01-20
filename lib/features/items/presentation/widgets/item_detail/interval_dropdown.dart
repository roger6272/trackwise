import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../domain/utils/interval_calculator.dart';

/// Represents a selectable period option.
class IntervalOption {
  /// Period number (-1 for "All Time").
  final int intervalNumber;

  /// Display label (e.g., "Current", "Previous", "#3", "All Time").
  final String label;

  /// Duration of the period (null for All Time).
  final Duration? duration;

  /// Count of increments in this period.
  final int count;

  /// Whether this is the current (ongoing) period.
  final bool isCurrent;

  const IntervalOption({
    required this.intervalNumber,
    required this.label,
    this.duration,
    required this.count,
    this.isCurrent = false,
  });

  /// Create "All Time" option.
  factory IntervalOption.allTime(int totalCount, Duration? totalDuration) {
    return IntervalOption(
      intervalNumber: -1,
      label: 'All Time',
      duration: totalDuration,
      count: totalCount,
    );
  }

  /// Create from IntervalData.
  ///
  /// [displayNumber] is the user-facing period number (descending order).
  factory IntervalOption.fromIntervalData(
    IntervalData data, {
    required bool isCurrent,
    required bool isPrevious,
    required int displayNumber,
  }) {
    String label;
    if (isCurrent) {
      label = 'Current Period';
    } else if (isPrevious) {
      label = 'Previous Period';
    } else {
      label = 'Period $displayNumber';
    }
    return IntervalOption(
      intervalNumber: data.intervalNumber,
      label: label,
      duration: data.duration,
      count: data.count,
      isCurrent: isCurrent,
    );
  }
}

/// Full-width dropdown for selecting periods.
///
/// Shows period options with duration and count.
/// Scrollable with ~5 visible items.
class IntervalDropdown extends StatelessWidget {
  /// List of period options to display.
  final List<IntervalOption> options;

  /// Currently selected period number (-1 for All Time).
  final int selectedInterval;

  /// Callback when period is selected.
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
      return [IntervalOption.allTime(0, null)];
    }

    final options = <IntervalOption>[];

    // Find total row (intervalNumber == -1)
    final totalRow = intervals.where((i) => i.intervalNumber == -1).firstOrNull;
    options.add(IntervalOption.allTime(
      totalRow?.count ?? 0,
      totalRow?.duration,
    ));

    // Add individual intervals (skip total row)
    // Intervals are already sorted most recent first
    final individualIntervals =
        intervals.where((i) => i.intervalNumber >= 0).toList();
    final totalPeriods = individualIntervals.length;

    for (int i = 0; i < individualIntervals.length; i++) {
      final interval = individualIntervals[i];
      final isCurrent = i == 0; // First one is most recent (current)
      final isPrevious = i == 1; // Second one is previous
      // Display number: descending from total (e.g., 5, 4, 3, 2, 1)
      final displayNumber = totalPeriods - i;
      options.add(IntervalOption.fromIntervalData(
        interval,
        isCurrent: isCurrent,
        isPrevious: isPrevious,
        displayNumber: displayNumber,
      ));
    }

    return options;
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final alternate = AppColors.alternate(brightness);
    final primaryBackground = AppColors.primaryBackground(brightness);
    final primary = AppColors.primaryAdaptive(brightness);
    // Filter control background - blue tint to distinguish from content
    final baseBackground = Color.lerp(alternate, primaryBackground, 0.5)!;
    final controlBackground = Color.lerp(baseBackground, primary, 0.12)!;

    // Find selected option
    final selectedOption = options.firstWhere(
      (o) => o.intervalNumber == selectedInterval,
      orElse: () => options.first,
    );

    return Container(
      decoration: BoxDecoration(
        color: controlBackground,
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(
          color: secondaryText.withValues(alpha: 0.12),
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
    return Text(
      option.label,
      style: GoogleFonts.inter(
        fontSize: 13.0,
        fontWeight: FontWeight.w600,
        color: primaryText,
      ),
    );
  }

  void _showDropdownMenu(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primaryText = AppColors.primaryText(brightness);
    final primary = AppColors.primaryAdaptive(brightness);
    final primaryBackground = AppColors.primaryBackground(brightness);

    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final buttonPosition = button.localToGlobal(Offset.zero, ancestor: overlay);

    // Calculate menu height (max 5 items visible)
    const itemHeight = 48.0;
    const maxVisibleItems = 5;
    final menuHeight = (options.length > maxVisibleItems
            ? maxVisibleItems * itemHeight
            : options.length * itemHeight) +
        16.0; // padding

    // Build menu items
    final menuItems = <PopupMenuEntry<int>>[
      // Period options
      ...options.map((option) {
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
                // Label only
                Expanded(
                  child: Text(
                    option.label,
                    style: GoogleFonts.inter(
                      fontSize: 13.0,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? primary : primaryText,
                    ),
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
      }),
    ];

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
      items: menuItems,
    ).then((value) {
      if (value != null) {
        onChanged(value);
      }
    });
  }
}

/// Non-selectable header for the dropdown menu.
class _DropdownHeader extends PopupMenuEntry<int> {
  final Widget child;

  @override
  final double height;

  const _DropdownHeader({
    required this.child,
    required this.height,
  });

  @override
  bool represents(int? value) => false;

  @override
  State<_DropdownHeader> createState() => _DropdownHeaderState();
}

class _DropdownHeaderState extends State<_DropdownHeader> {
  @override
  Widget build(BuildContext context) => widget.child;
}
