import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../domain/utils/interval_calculator.dart';

/// Returns a display name for a cycle.
///
/// Used by both the bottom sheet and [PeriodsTable] to keep labels consistent.
/// [intervalNumber] is the reset number (-1 for All Time).
/// [index] is the position in the sorted list (0 = current, 1 = previous, ...).
/// [totalPeriods] is the total number of individual periods (excluding All Time).
String getCycleDisplayName(
  int intervalNumber,
  int index,
  int totalPeriods,
  Map<String, String> cycleNames,
) {
  if (intervalNumber == -1) return 'All Time';
  final custom = cycleNames[intervalNumber.toString()];
  if (custom != null && custom.isNotEmpty) return custom;
  if (index == 0) return 'Current Cycle';
  if (index == 1) return 'Previous Cycle';
  return 'Cycle ${totalPeriods - index}';
}

/// Bottom sheet for selecting and renaming reset cycles.
class CycleSelectionBottomSheet extends StatefulWidget {
  /// All interval data including the "All Time" summary.
  final List<IntervalData> intervals;

  /// Currently selected interval number (-1 for All Time).
  final int selectedInterval;

  /// User-defined cycle names (resetNumber string → name).
  final Map<String, String> cycleNames;

  /// Callback when a cycle row is tapped.
  final ValueChanged<int> onIntervalSelected;

  /// Callback when a cycle is renamed. Returns after persistence completes.
  final Future<void> Function(int resetNumber, String newName) onCycleRenamed;

  const CycleSelectionBottomSheet({
    super.key,
    required this.intervals,
    required this.selectedInterval,
    required this.cycleNames,
    required this.onIntervalSelected,
    required this.onCycleRenamed,
  });

  @override
  State<CycleSelectionBottomSheet> createState() =>
      _CycleSelectionBottomSheetState();
}

class _CycleSelectionBottomSheetState extends State<CycleSelectionBottomSheet> {
  /// Index of the row currently being renamed, or -2 if none.
  int _editingIntervalNumber = -2;

  /// Local copy of cycle names so renames are reflected immediately.
  late Map<String, String> _localCycleNames;

  final TextEditingController _renameController = TextEditingController();
  final FocusNode _renameFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _localCycleNames = Map<String, String>.from(widget.cycleNames);
  }

  @override
  void dispose() {
    _renameController.dispose();
    _renameFocus.dispose();
    super.dispose();
  }

  void _startRename(int intervalNumber, String currentName) {
    setState(() {
      _editingIntervalNumber = intervalNumber;
      _renameController.text = currentName;
    });
    // Focus after the frame so the TextField is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _renameFocus.requestFocus();
      _renameController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _renameController.text.length,
      );
    });
  }

  Future<void> _submitRename(int intervalNumber) async {
    final newName = _renameController.text.trim();
    setState(() {
      _editingIntervalNumber = -2;
      // Update local copy immediately so the UI reflects the change
      if (newName.isEmpty) {
        _localCycleNames.remove(intervalNumber.toString());
      } else {
        _localCycleNames[intervalNumber.toString()] = newName;
      }
    });
    await widget.onCycleRenamed(intervalNumber, newName);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final primary = AppColors.primaryAdaptive(brightness);
    final surface = AppColors.surface(brightness);
    final textTheme = Theme.of(context).textTheme;

    // Build ordered list: All Time first, then individual periods
    final allTimeInterval = widget.intervals.firstWhere(
      (i) => i.intervalNumber == -1,
      orElse: () => widget.intervals.first,
    );
    final periods =
        widget.intervals.where((i) => i.intervalNumber >= 0).toList();
    final totalPeriods = periods.length;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20.0),
          topRight: Radius.circular(20.0),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          const SizedBox(height: 8.0),
          Container(
            width: 36.0,
            height: 4.0,
            decoration: BoxDecoration(
              color: secondaryText.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2.0),
            ),
          ),
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(20.0, 16.0, 8.0, 8.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Select Cycle',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: primaryText,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: Icon(Icons.close_rounded, color: secondaryText),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Divider(
            height: 1.0,
            color: secondaryText.withValues(alpha: 0.12),
          ),
          // Cycle rows (scrollable if many)
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              children: [
                // Individual periods first (current on top)
                for (var i = 0; i < periods.length; i++)
                  _buildCycleRow(
                    context,
                    interval: periods[i],
                    index: i,
                    totalPeriods: totalPeriods,
                    isCurrent: i == 0,
                    isSelected:
                        periods[i].intervalNumber == widget.selectedInterval,
                    primaryText: primaryText,
                    secondaryText: secondaryText,
                    primary: primary,
                    textTheme: textTheme,
                  ),
                // All Time row at end
                _buildAllTimeRow(
                  context,
                  interval: allTimeInterval,
                  isSelected: widget.selectedInterval == -1,
                  primaryText: primaryText,
                  secondaryText: secondaryText,
                  primary: primary,
                  textTheme: textTheme,
                ),
              ],
            ),
          ),
          // Bottom safe area
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8.0),
        ],
      ),
    );
  }

  Widget _buildCycleRow(
    BuildContext context, {
    required IntervalData interval,
    required int index,
    required int totalPeriods,
    required bool isCurrent,
    required bool isSelected,
    required Color primaryText,
    required Color secondaryText,
    required Color primary,
    required TextTheme textTheme,
  }) {
    final isEditing = _editingIntervalNumber == interval.intervalNumber;
    final displayName = getCycleDisplayName(
      interval.intervalNumber,
      index,
      totalPeriods,
      _localCycleNames,
    );

    // Subtitle: cycle number + date range + count
    final startStr = _formatDate(interval.startTime);
    final endStr = interval.endTime != null
        ? _formatDate(interval.endTime!)
        : 'now';
    final cycleNum = 'Cycle #${interval.intervalNumber + 1}';
    final subtitle =
        '$cycleNum · $startStr – $endStr · ${interval.count} presses';

    return Material(
      color: isSelected ? primary.withValues(alpha: 0.08) : Colors.transparent,
      child: InkWell(
        onTap: () {
          widget.onIntervalSelected(interval.intervalNumber);
          Navigator.of(context).pop();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Row(
            children: [
              // Radio indicator
              Container(
                width: 18.0,
                height: 18.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? primary : secondaryText.withValues(alpha: 0.4),
                    width: isSelected ? 2.0 : 1.5,
                  ),
                ),
                child: isSelected
                    ? Center(
                        child: Container(
                          width: 8.0,
                          height: 8.0,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: primary,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12.0),
              // Label + subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isEditing)
                      TextField(
                        controller: _renameController,
                        focusNode: _renameFocus,
                        maxLength: 20,
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: primaryText,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 6.0,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6.0),
                            borderSide: BorderSide(color: primary),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6.0),
                            borderSide: BorderSide(color: primary, width: 1.5),
                          ),
                          hintText: 'Cycle name',
                          suffixIcon: IconButton(
                            icon: Icon(Icons.check_rounded,
                                size: 18.0, color: primary),
                            onPressed: () =>
                                _submitRename(interval.intervalNumber),
                          ),
                        ),
                        onSubmitted: (_) =>
                            _submitRename(interval.intervalNumber),
                      )
                    else
                      Row(
                        children: [
                          if (isCurrent) ...[
                            Container(
                              width: 6.0,
                              height: 6.0,
                              margin: const EdgeInsets.only(right: 6.0),
                              decoration: const BoxDecoration(
                                color: AppColors.success,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                          Flexible(
                            child: Text(
                              displayName,
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isSelected ? primary : primaryText,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 2.0),
                    Text(
                      subtitle,
                      style: textTheme.bodySmall?.copyWith(
                        fontSize: 12.0,
                        color: secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              // Edit button (not for All Time)
              if (!isEditing)
                Semantics(
                  label: 'Rename cycle',
                  child: IconButton(
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 18.0,
                      color: secondaryText.withValues(alpha: 0.6),
                    ),
                    onPressed: () => _startRename(
                      interval.intervalNumber,
                      _localCycleNames[interval.intervalNumber.toString()] ??
                          '',
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAllTimeRow(
    BuildContext context, {
    required IntervalData interval,
    required bool isSelected,
    required Color primaryText,
    required Color secondaryText,
    required Color primary,
    required TextTheme textTheme,
  }) {
    return Material(
      color: isSelected ? primary.withValues(alpha: 0.08) : Colors.transparent,
      child: InkWell(
        onTap: () {
          widget.onIntervalSelected(-1);
          Navigator.of(context).pop();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Row(
            children: [
              // Radio indicator
              Container(
                width: 18.0,
                height: 18.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? primary : secondaryText.withValues(alpha: 0.4),
                    width: isSelected ? 2.0 : 1.5,
                  ),
                ),
                child: isSelected
                    ? Center(
                        child: Container(
                          width: 8.0,
                          height: 8.0,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: primary,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12.0),
              Icon(
                Icons.all_inclusive_rounded,
                size: 16.0,
                color: isSelected ? primary : secondaryText,
              ),
              const SizedBox(width: 6.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'All Time',
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isSelected ? primary : primaryText,
                      ),
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      '${interval.count} total presses',
                      style: textTheme.bodySmall?.copyWith(
                        fontSize: 12.0,
                        color: secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}
