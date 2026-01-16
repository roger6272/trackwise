import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_colors.dart';

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

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    const primary = AppColors.primary;
    final alternate = AppColors.alternate(brightness);
    final primaryBackground = AppColors.primaryBackground(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final primaryText = AppColors.primaryText(brightness);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Aggregation chips - centered
        _buildAggregationChips(primary, primaryBackground, secondaryText),
        const SizedBox(height: 20.0),
        // Reset toggle chips - centered
        _buildResetToggle(primary, primaryBackground, secondaryText),
        const SizedBox(height: 30.0),
        // "Ends on" label row (only shown when not 1D)
        if (aggregation != '1D')
          Padding(
            padding: const EdgeInsets.only(left: 22.0, right: 22.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Ends on',
                style: GoogleFonts.inter(
                  fontSize: 12.0,
                  fontWeight: FontWeight.normal,
                  color: primaryText,
                ),
              ),
            ),
          ),
        // Date picker row
        Padding(
          padding: const EdgeInsets.fromLTRB(32.0, 0.0, 25.0, 15.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: _buildDatePicker(primaryText),
          ),
        ),
        // Calendar (when expanded)
        if (!isCalendarCollapsed) _buildCalendar(context, primary, secondaryText, alternate),
      ],
    );
  }

  Widget _buildAggregationChips(Color primary, Color primaryBackground, Color secondaryText) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 5.0,
      children: ['1D', '7D', '30D'].map((period) {
        final isSelected = aggregation == period;
        return GestureDetector(
          onTap: () => onAggregationChanged(period),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: isSelected ? primary : primaryBackground,
              borderRadius: BorderRadius.circular(5.0),
            ),
            child: Text(
              period,
              style: GoogleFonts.inter(
                fontSize: 14.0,
                color: isSelected ? Colors.white : secondaryText,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildResetToggle(Color primary, Color primaryBackground, Color secondaryText) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 5.0,
      children: [
        _buildToggleChip(
          label: 'Total',
          isSelected: !showSinceReset,
          onTap: () => onShowSinceResetChanged(false),
          primary: primary,
          primaryBackground: primaryBackground,
          secondaryText: secondaryText,
        ),
        _buildToggleChip(
          label: 'Since Last Reset',
          isSelected: showSinceReset,
          onTap: () => onShowSinceResetChanged(true),
          primary: primary,
          primaryBackground: primaryBackground,
          secondaryText: secondaryText,
        ),
      ],
    );
  }

  Widget _buildToggleChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required Color primary,
    required Color primaryBackground,
    required Color secondaryText,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: isSelected ? primary : primaryBackground,
          borderRadius: BorderRadius.circular(5.0),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14.0,
            color: isSelected ? Colors.white : secondaryText,
          ),
        ),
      ),
    );
  }

  Widget _buildDatePicker(Color primaryText) {
    final dateFormat = DateFormat.yMMMd();

    return GestureDetector(
      onTap: onToggleCalendar,
      child: Text(
        dateFormat.format(selectedDate),
        style: GoogleFonts.interTight(
          color: primaryText,
          fontWeight: FontWeight.w500,
          fontSize: 16.0,
        ),
      ),
    );
  }

  Widget _buildCalendar(BuildContext context, Color primary, Color secondaryText, Color alternate) {
    final brightness = Theme.of(context).brightness;
    final secondaryBackground = AppColors.secondaryBackground(brightness);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 10.0),
          child: CalendarDatePicker(
            initialDate: selectedDate,
            firstDate: DateTime(2020),
            lastDate: DateTime.now(),
            onDateChanged: onDateChanged,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(15.0, 10.0, 15.0, 10.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildCalendarButton(
                label: 'OK',
                isPrimary: true,
                onPressed: onToggleCalendar,
                primary: primary,
                secondaryText: secondaryText,
                secondaryBackground: secondaryBackground,
                alternate: alternate,
              ),
              const SizedBox(width: 10.0),
              _buildCalendarButton(
                label: 'Cancel',
                isPrimary: false,
                onPressed: onToggleCalendar,
                primary: primary,
                secondaryText: secondaryText,
                secondaryBackground: secondaryBackground,
                alternate: alternate,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarButton({
    required String label,
    required bool isPrimary,
    required VoidCallback onPressed,
    required Color primary,
    required Color secondaryText,
    required Color secondaryBackground,
    required Color alternate,
  }) {
    return SizedBox(
      width: 70.0,
      height: 40.0,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? primary : secondaryBackground,
          foregroundColor: isPrimary ? Colors.white : secondaryText,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18.0),
            side: BorderSide(color: alternate),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Text(
          label,
          style: GoogleFonts.interTight(
            fontSize: 14.0,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
