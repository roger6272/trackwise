import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../charts/presentation/bloc/charts_bloc.dart';
import '../../../charts/presentation/bloc/charts_event.dart';
import '../../../charts/presentation/bloc/charts_state.dart';
import '../../../events/presentation/bloc/events_bloc.dart';
import '../../../events/presentation/bloc/events_event.dart';

/// Widget for selecting a date range for charts and events.
///
/// Displays the current date range and allows users to pick new dates.
/// Updates both EventsBloc and ChartsBloc when the range changes.
class DateRangeSelector extends StatelessWidget {
  const DateRangeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChartsBloc, ChartsState>(
      builder: (context, state) {
        DateTime startDate;
        DateTime endDate;

        if (state is ChartsLoaded) {
          startDate = state.startDate;
          endDate = state.endDate;
        } else {
          endDate = DateTime.now();
          startDate = endDate.subtract(const Duration(days: 30));
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: _DateButton(
                  label: 'From',
                  date: startDate,
                  onPressed: () => _selectDate(
                    context,
                    startDate,
                    endDate,
                    isStartDate: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: _DateButton(
                  label: 'To',
                  date: endDate,
                  onPressed: () => _selectDate(
                    context,
                    startDate,
                    endDate,
                    isStartDate: false,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _QuickRangeButton(
                startDate: startDate,
                endDate: endDate,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _selectDate(
    BuildContext context,
    DateTime currentStart,
    DateTime currentEnd, {
    required bool isStartDate,
  }) async {
    final now = DateTime.now();
    final initialDate = isStartDate ? currentStart : currentEnd;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: now,
    );

    if (picked != null && context.mounted) {
      DateTime newStart;
      DateTime newEnd;

      if (isStartDate) {
        newStart = picked;
        newEnd = currentEnd;
        // Ensure start is before end
        if (newStart.isAfter(newEnd)) {
          newEnd = newStart;
        }
      } else {
        newStart = currentStart;
        newEnd = picked;
        // Ensure end is after start
        if (newEnd.isBefore(newStart)) {
          newStart = newEnd;
        }
      }

      _updateDateRange(context, newStart, newEnd);
    }
  }

  void _updateDateRange(
    BuildContext context,
    DateTime startDate,
    DateTime endDate,
  ) {
    // Update charts
    context.read<ChartsBloc>().add(ChangeDateRange(
          startDate: startDate,
          endDate: endDate,
        ));

    // Update events
    context.read<EventsBloc>().add(FilterByDateRange(
          startDate: startDate,
          endDate: endDate,
        ));
  }
}

/// Button displaying a date with label.
class _DateButton extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onPressed;

  const _DateButton({
    required this.label,
    required this.date,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, y');

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          Text(
            dateFormat.format(date),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

/// Popup menu for quick date range selection.
class _QuickRangeButton extends StatelessWidget {
  final DateTime startDate;
  final DateTime endDate;

  const _QuickRangeButton({
    required this.startDate,
    required this.endDate,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      icon: const Icon(Icons.calendar_today),
      tooltip: 'Quick select',
      onSelected: (days) => _selectQuickRange(context, days),
      itemBuilder: (context) => [
        const PopupMenuItem(value: 7, child: Text('Last 7 days')),
        const PopupMenuItem(value: 14, child: Text('Last 14 days')),
        const PopupMenuItem(value: 30, child: Text('Last 30 days')),
        const PopupMenuItem(value: 90, child: Text('Last 90 days')),
        const PopupMenuItem(value: 365, child: Text('Last year')),
      ],
    );
  }

  void _selectQuickRange(BuildContext context, int days) {
    final now = DateTime.now();
    final endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final startDate = endDate.subtract(Duration(days: days));

    // Update charts
    context.read<ChartsBloc>().add(ChangeDateRange(
          startDate: startDate,
          endDate: endDate,
        ));

    // Update events
    context.read<EventsBloc>().add(FilterByDateRange(
          startDate: startDate,
          endDate: endDate,
        ));
  }
}
