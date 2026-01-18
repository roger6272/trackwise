import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_colors.dart';

/// A compact filter section widget for the item detail page.
///
/// Provides controls for:
/// - Aggregation period (1D, 7D, 30D) as compact pills
/// - Reset toggle (Total vs Since Last Reset) as a subtle chip
/// - Date selection with bottom sheet calendar
class FilterSection extends StatelessWidget {
  const FilterSection({
    super.key,
    required this.aggregation,
    required this.showSinceReset,
    required this.selectedDate,
    required this.onAggregationChanged,
    required this.onShowSinceResetChanged,
    required this.onDateChanged,
  });

  final String aggregation;
  final bool showSinceReset;
  final DateTime selectedDate;
  final ValueChanged<String> onAggregationChanged;
  final ValueChanged<bool> onShowSinceResetChanged;
  final ValueChanged<DateTime> onDateChanged;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    const primary = AppColors.primary;
    final secondaryText = AppColors.secondaryText(brightness);
    final primaryText = AppColors.primaryText(brightness);
    final alternate = AppColors.alternate(brightness);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Row 1: Aggregation pills + Reset toggle
        Row(
          children: [
            // Aggregation pills (compact)
            _buildAggregationPills(primary, alternate, secondaryText),
            const Spacer(),
            // Reset toggle as subtle chip
            _buildResetChip(context, primary, alternate, secondaryText),
          ],
        ),
        const SizedBox(height: 12.0),
        // Row 2: Date picker (full width, more prominent)
        _buildDatePickerRow(context, primary, primaryText, secondaryText, alternate),
      ],
    );
  }

  Widget _buildAggregationPills(Color primary, Color alternate, Color secondaryText) {
    const periods = ['1D', '7D', '30D'];

    return Container(
      decoration: BoxDecoration(
        color: alternate,
        borderRadius: BorderRadius.circular(10.0),
      ),
      padding: const EdgeInsets.all(3.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: periods.map((period) {
          final isSelected = aggregation == period;
          return GestureDetector(
            onTap: () => onAggregationChanged(period),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
              decoration: BoxDecoration(
                color: isSelected ? primary : Colors.transparent,
                borderRadius: BorderRadius.circular(8.0),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: primary.withValues(alpha: 0.3),
                          blurRadius: 8.0,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                period,
                style: GoogleFonts.inter(
                  fontSize: 13.0,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.white : secondaryText,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildResetChip(BuildContext context, Color primary, Color alternate, Color secondaryText) {
    return GestureDetector(
      onTap: () => onShowSinceResetChanged(!showSinceReset),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: showSinceReset ? primary.withValues(alpha: 0.15) : alternate,
          borderRadius: BorderRadius.circular(10.0),
          border: Border.all(
            color: showSinceReset ? primary.withValues(alpha: 0.4) : Colors.transparent,
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              showSinceReset ? Icons.history_rounded : Icons.all_inclusive_rounded,
              size: 14.0,
              color: showSinceReset ? primary : secondaryText,
            ),
            const SizedBox(width: 6.0),
            Text(
              showSinceReset ? 'Since Reset' : 'All Time',
              style: GoogleFonts.inter(
                fontSize: 12.0,
                fontWeight: FontWeight.w500,
                color: showSinceReset ? primary : secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePickerRow(
    BuildContext context,
    Color primary,
    Color primaryText,
    Color secondaryText,
    Color alternate,
  ) {
    final dateFormat = DateFormat('EEE, MMM d');
    final isToday = _isToday(selectedDate);
    final canGoForward = !isToday;

    return Container(
      decoration: BoxDecoration(
        color: alternate,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: primary.withValues(alpha: 0.1),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          // Previous day button
          _buildNavArrow(
            icon: Icons.chevron_left_rounded,
            onTap: () => onDateChanged(
              selectedDate.subtract(const Duration(days: 1)),
            ),
            primary: primary,
            secondaryText: secondaryText,
            enabled: true,
          ),
          // Date picker (tappable center)
          Expanded(
            child: GestureDetector(
              onTap: () => _showDatePickerBottomSheet(context),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 14.0,
                      color: primary,
                    ),
                    const SizedBox(width: 8.0),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          aggregation == '1D' ? 'Viewing Date' : 'Period Ending',
                          style: GoogleFonts.inter(
                            fontSize: 10.0,
                            fontWeight: FontWeight.w500,
                            color: secondaryText,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 1.0),
                        Text(
                          isToday ? 'Today' : dateFormat.format(selectedDate),
                          style: GoogleFonts.interTight(
                            fontSize: 14.0,
                            fontWeight: FontWeight.w600,
                            color: primaryText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 4.0),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18.0,
                      color: secondaryText,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Next day button
          _buildNavArrow(
            icon: Icons.chevron_right_rounded,
            onTap: canGoForward
                ? () => onDateChanged(
                      selectedDate.add(const Duration(days: 1)),
                    )
                : null,
            primary: primary,
            secondaryText: secondaryText,
            enabled: canGoForward,
          ),
        ],
      ),
    );
  }

  Widget _buildNavArrow({
    required IconData icon,
    required VoidCallback? onTap,
    required Color primary,
    required Color secondaryText,
    required bool enabled,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
        child: Icon(
          icon,
          size: 22.0,
          color: enabled ? primary : secondaryText.withValues(alpha: 0.25),
        ),
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  void _showDatePickerBottomSheet(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    const primary = AppColors.primary;
    final primaryBackground = AppColors.primaryBackground(brightness);
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);

    // Title changes based on aggregation period
    final title = aggregation == '1D' ? 'Select Date' : 'Select End Date';

    DateTime tempSelectedDate = selectedDate;

    showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: primaryBackground,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20.0),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle bar
                    Container(
                      margin: const EdgeInsets.only(top: 12.0),
                      width: 40.0,
                      height: 4.0,
                      decoration: BoxDecoration(
                        color: secondaryText.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2.0),
                      ),
                    ),
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.interTight(
                              fontSize: 18.0,
                              fontWeight: FontWeight.w600,
                              color: primaryText,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(
                              Icons.close_rounded,
                              color: secondaryText,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                    // Calendar
                    CalendarDatePicker(
                      initialDate: tempSelectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      onDateChanged: (date) {
                        setModalState(() {
                          tempSelectedDate = date;
                        });
                      },
                    ),
                    // Action buttons
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24.0, 8.0, 24.0, 16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: secondaryText,
                                side: BorderSide(
                                  color: secondaryText.withValues(alpha: 0.3),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10.0),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 14.0),
                              ),
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.inter(
                                  fontSize: 15.0,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12.0),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                onDateChanged(tempSelectedDate);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10.0),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 14.0),
                              ),
                              child: Text(
                                'Confirm',
                                style: GoogleFonts.inter(
                                  fontSize: 15.0,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
