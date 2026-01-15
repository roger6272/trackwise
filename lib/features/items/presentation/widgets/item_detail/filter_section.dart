import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A filter section widget for the item detail page.
///
/// Provides controls for:
/// - Aggregation period (1D, 7D, 30D)
/// - Reset toggle (Total vs Since Last Reset)
/// - Date selection with collapsible calendar
class FilterSection extends StatelessWidget {
  const FilterSection({
    super.key,
    required this.aggregation,
    required this.showSinceReset,
    required this.selectedDate,
    required this.isCalendarCollapsed,
    required this.onAggregationChanged,
    required this.onShowSinceResetChanged,
    required this.onDateChanged,
    required this.onToggleCalendar,
  });

  final String aggregation;
  final bool showSinceReset;
  final DateTime selectedDate;
  final bool isCalendarCollapsed;
  final ValueChanged<String> onAggregationChanged;
  final ValueChanged<bool> onShowSinceResetChanged;
  final ValueChanged<DateTime> onDateChanged;
  final VoidCallback onToggleCalendar;

  // FlutterFlow colors
  static const Color _primary = Color(0xFF4B39EF);
  static const Color _alternate = Color(0xFFE0E3E7);
  static const Color _primaryBackground = Color(0xFFF1F4F8);
  static const Color _primaryText = Color(0xFF14181B);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _alternate,
        borderRadius: BorderRadius.circular(8.0),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildAggregationChips(),
          const SizedBox(height: 16.0),
          _buildResetToggle(),
          const SizedBox(height: 16.0),
          _buildDatePicker(),
          if (!isCalendarCollapsed) ...[
            const SizedBox(height: 16.0),
            _buildCalendar(),
          ],
        ],
      ),
    );
  }

  Widget _buildAggregationChips() {
    return Wrap(
      spacing: 8.0,
      children: ['1D', '7D', '30D'].map((period) {
        final isSelected = aggregation == period;
        return ChoiceChip(
          label: Text(period),
          selected: isSelected,
          onSelected: (_) => onAggregationChanged(period),
          selectedColor: _primary,
          backgroundColor: _primaryBackground,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : _primaryText,
            fontWeight: FontWeight.w500,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          side: BorderSide.none,
        );
      }).toList(),
    );
  }

  Widget _buildResetToggle() {
    return Row(
      children: [
        _buildToggleChip(
          label: 'Total',
          isSelected: !showSinceReset,
          onTap: () => onShowSinceResetChanged(false),
        ),
        const SizedBox(width: 8.0),
        _buildToggleChip(
          label: 'Since Last Reset',
          isSelected: showSinceReset,
          onTap: () => onShowSinceResetChanged(true),
        ),
      ],
    );
  }

  Widget _buildToggleChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: isSelected ? _primary : _primaryBackground,
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : _primaryText,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    final dateFormat = DateFormat.yMMMd();
    final showEndsOn = aggregation != '1D';

    return GestureDetector(
      onTap: onToggleCalendar,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: _primaryBackground,
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showEndsOn) ...[
              Text(
                'Ends on ',
                style: TextStyle(
                  color: _primaryText.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
            Text(
              dateFormat.format(selectedDate),
              style: const TextStyle(
                color: _primaryText,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4.0),
            Icon(
              isCalendarCollapsed ? Icons.expand_more : Icons.expand_less,
              color: _primaryText,
              size: 20.0,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CalendarDatePicker(
          initialDate: selectedDate,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          onDateChanged: (date) {
            onDateChanged(date);
            onToggleCalendar();
          },
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: onToggleCalendar,
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: _primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
