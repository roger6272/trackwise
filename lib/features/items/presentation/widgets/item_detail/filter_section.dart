import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_colors.dart';

/// A filter section widget for the item detail page.
///
/// Provides controls for:
/// - Aggregation period (1D, 7D, 30D)
/// - Reset toggle (Total vs Since Last Reset)
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
    final primaryBackground = AppColors.primaryBackground(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final primaryText = AppColors.primaryText(brightness);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Aggregation chips - centered
        _buildAggregationChips(primary, primaryBackground, secondaryText),
        const SizedBox(height: 10.0),
        // Reset toggle chips - centered
        _buildResetToggle(primary, primaryBackground, secondaryText),
        const SizedBox(height: 10.0),
        // Date picker row
        _buildDatePickerRow(context, primaryText, secondaryText),
      ],
    );
  }

  Widget _buildAggregationChips(Color primary, Color primaryBackground, Color secondaryText) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment<String>(
          value: '1D',
          label: Text('1D'),
        ),
        ButtonSegment<String>(
          value: '7D',
          label: Text('7D'),
        ),
        ButtonSegment<String>(
          value: '30D',
          label: Text('30D'),
        ),
      ],
      selected: {aggregation},
      onSelectionChanged: (Set<String> selection) {
        onAggregationChanged(selection.first);
      },
      showSelectedIcon: false,
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return primary;
          }
          return primaryBackground;
        }),
        foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return secondaryText;
        }),
        side: WidgetStateProperty.all(
          BorderSide(color: primary.withValues(alpha: 0.3)),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
        textStyle: WidgetStateProperty.all(
          GoogleFonts.inter(
            fontSize: 14.0,
            fontWeight: FontWeight.w500,
          ),
        ),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
        ),
      ),
    );
  }

  Widget _buildResetToggle(Color primary, Color primaryBackground, Color secondaryText) {
    return SegmentedButton<bool>(
      segments: const [
        ButtonSegment<bool>(
          value: false,
          label: Text('Total'),
        ),
        ButtonSegment<bool>(
          value: true,
          label: Text('Since Reset'),
        ),
      ],
      selected: {showSinceReset},
      onSelectionChanged: (Set<bool> selection) {
        onShowSinceResetChanged(selection.first);
      },
      showSelectedIcon: false,
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return primary;
          }
          return primaryBackground;
        }),
        foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return secondaryText;
        }),
        side: WidgetStateProperty.all(
          BorderSide(color: primary.withValues(alpha: 0.3)),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
        textStyle: WidgetStateProperty.all(
          GoogleFonts.inter(
            fontSize: 14.0,
            fontWeight: FontWeight.w500,
          ),
        ),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        ),
      ),
    );
  }

  Widget _buildDatePickerRow(BuildContext context, Color primaryText, Color secondaryText) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final brightness = Theme.of(context).brightness;
    final alternate = AppColors.alternate(brightness);

    // Label changes based on aggregation period
    final label = aggregation == '1D' ? 'Date:' : 'Ends:';

    return GestureDetector(
      onTap: () => _showDatePickerBottomSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: alternate,
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 15.0,
              color: secondaryText,
            ),
            const SizedBox(width: 8.0),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13.0,
                color: secondaryText,
              ),
            ),
            const SizedBox(width: 4.0),
            Text(
              dateFormat.format(selectedDate),
              style: GoogleFonts.inter(
                color: primaryText,
                fontWeight: FontWeight.w500,
                fontSize: 13.0,
              ),
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
    );
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
