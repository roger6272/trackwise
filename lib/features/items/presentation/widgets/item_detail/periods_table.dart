import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../domain/utils/interval_calculator.dart';

/// Table displaying all periods for side-by-side comparison.
///
/// Features:
/// - Columns: Period, Count, Avg/day, Duration
/// - "All Time" row with distinct styling at top
/// - Max 6 visible rows, scrollable for more
/// - Tapping row selects that period
/// - Selected row is highlighted
/// - Auto-scrolls to selected row when selection changes
class PeriodsTable extends StatefulWidget {
  /// All interval data including the "All Time" summary.
  final List<IntervalData> intervals;

  /// Currently selected interval number (-1 for All Time).
  final int selectedInterval;

  /// Callback when a row is tapped.
  final ValueChanged<int> onIntervalSelected;

  const PeriodsTable({
    super.key,
    required this.intervals,
    required this.selectedInterval,
    required this.onIntervalSelected,
  });

  @override
  State<PeriodsTable> createState() => _PeriodsTableState();
}

class _PeriodsTableState extends State<PeriodsTable> {
  final ScrollController _scrollController = ScrollController();

  /// Height of each row for scroll calculations.
  static const double _rowHeight = 48.0;

  /// Maximum visible rows before scrolling.
  static const int _maxVisibleRows = 6;

  @override
  void didUpdateWidget(PeriodsTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Auto-scroll to selected row when selection changes
    if (oldWidget.selectedInterval != widget.selectedInterval) {
      _scrollToSelectedRow();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSelectedRow() {
    final index = _getSelectedRowIndex();
    if (index < 0) return;

    // Calculate scroll position to bring selected row into view
    final targetOffset = index * _rowHeight;
    final maxScroll = _scrollController.position.maxScrollExtent;
    const viewportHeight = _maxVisibleRows * _rowHeight;

    // Only scroll if the row is outside the visible area
    final currentOffset = _scrollController.offset;
    if (targetOffset < currentOffset) {
      // Row is above visible area
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else if (targetOffset + _rowHeight > currentOffset + viewportHeight) {
      // Row is below visible area
      final newOffset = (targetOffset + _rowHeight - viewportHeight).clamp(0.0, maxScroll);
      _scrollController.animateTo(
        newOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  int _getSelectedRowIndex() {
    // Build the same row order as the table
    final rows = _buildRowData();
    return rows.indexWhere((r) => r.intervalNumber == widget.selectedInterval);
  }

  List<_RowData> _buildRowData() {
    final rows = <_RowData>[];

    // Find the "All Time" entry (intervalNumber == -1)
    final allTimeInterval = widget.intervals.firstWhere(
      (i) => i.intervalNumber == -1,
      orElse: () => widget.intervals.first,
    );

    // Add "All Time" row first
    rows.add(_RowData(
      intervalNumber: -1,
      label: 'All Time',
      count: allTimeInterval.count,
      duration: allTimeInterval.duration,
      isAllTime: true,
    ));

    // Add individual periods (excluding "All Time")
    final periods = widget.intervals
        .where((i) => i.intervalNumber >= 0)
        .toList();

    for (var i = 0; i < periods.length; i++) {
      final interval = periods[i];
      String label;
      if (i == 0) {
        label = 'Current';
      } else if (i == 1) {
        label = 'Previous';
      } else {
        label = 'Period ${periods.length - i}';
      }

      rows.add(_RowData(
        intervalNumber: interval.intervalNumber,
        label: label,
        count: interval.count,
        duration: interval.duration,
        isAllTime: false,
      ));
    }

    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final primary = AppColors.primaryAdaptive(brightness);
    final alternate = AppColors.alternate(brightness);

    final rows = _buildRowData();
    final totalRows = rows.length;
    final showScroll = totalRows > _maxVisibleRows;
    final tableHeight = showScroll
        ? _maxVisibleRows * _rowHeight
        : totalRows * _rowHeight;

    return Container(
      decoration: BoxDecoration(
        color: alternate,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: primary.withValues(alpha: 0.08),
          width: 1.0,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table header
          _buildHeader(secondaryText),
          // Table body
          SizedBox(
            height: tableHeight,
            child: ListView.builder(
              controller: _scrollController,
              physics: showScroll
                  ? const ClampingScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              itemCount: rows.length,
              itemExtent: _rowHeight,
              itemBuilder: (context, index) {
                final row = rows[index];
                final isSelected = row.intervalNumber == widget.selectedInterval;
                return _buildRow(
                  row: row,
                  isSelected: isSelected,
                  primaryText: primaryText,
                  secondaryText: secondaryText,
                  primary: primary,
                  alternate: alternate,
                  onTap: () => widget.onIntervalSelected(row.intervalNumber),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(Color secondaryText) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: secondaryText.withValues(alpha: 0.1),
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              'Period',
              style: GoogleFonts.inter(
                fontSize: 11.0,
                fontWeight: FontWeight.w600,
                color: secondaryText,
                letterSpacing: 0.3,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Count',
              style: GoogleFonts.inter(
                fontSize: 11.0,
                fontWeight: FontWeight.w600,
                color: secondaryText,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Avg/day',
              style: GoogleFonts.inter(
                fontSize: 11.0,
                fontWeight: FontWeight.w600,
                color: secondaryText,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Duration',
              style: GoogleFonts.inter(
                fontSize: 11.0,
                fontWeight: FontWeight.w600,
                color: secondaryText,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow({
    required _RowData row,
    required bool isSelected,
    required Color primaryText,
    required Color secondaryText,
    required Color primary,
    required Color alternate,
    required VoidCallback onTap,
  }) {
    // Calculate derived values
    final days = row.duration.inDays.clamp(1, double.infinity).toInt();
    final avgPerDay = row.count / days;

    // Distinct styling for "All Time" row
    final backgroundColor = row.isAllTime
        ? primary.withValues(alpha: 0.06)
        : (isSelected ? primary.withValues(alpha: 0.12) : Colors.transparent);

    final textColor = isSelected ? primary : primaryText;

    return Material(
      color: backgroundColor,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          decoration: BoxDecoration(
            border: Border(
              left: isSelected
                  ? BorderSide(color: primary, width: 3.0)
                  : BorderSide.none,
              bottom: BorderSide(
                color: secondaryText.withValues(alpha: 0.06),
                width: 1.0,
              ),
            ),
          ),
          child: Row(
            children: [
              // Period label
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    if (row.isAllTime) ...[
                      Icon(
                        Icons.all_inclusive_rounded,
                        size: 14.0,
                        color: isSelected ? primary : secondaryText,
                      ),
                      const SizedBox(width: 6.0),
                    ],
                    Text(
                      row.label,
                      style: GoogleFonts.inter(
                        fontSize: 13.0,
                        fontWeight: isSelected || row.isAllTime
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
              // Count
              Expanded(
                flex: 2,
                child: Text(
                  '+${row.count}',
                  style: GoogleFonts.interTight(
                    fontSize: 13.0,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? primary : primaryText,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              // Avg/day
              Expanded(
                flex: 2,
                child: Text(
                  avgPerDay.toStringAsFixed(1),
                  style: GoogleFonts.inter(
                    fontSize: 13.0,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? primary : secondaryText,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              // Duration
              Expanded(
                flex: 2,
                child: Text(
                  IntervalCalculator.formatDuration(row.duration),
                  style: GoogleFonts.inter(
                    fontSize: 13.0,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? primary : secondaryText,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Internal data class for table rows.
class _RowData {
  final int intervalNumber;
  final String label;
  final int count;
  final Duration duration;
  final bool isAllTime;

  const _RowData({
    required this.intervalNumber,
    required this.label,
    required this.count,
    required this.duration,
    required this.isAllTime,
  });
}
