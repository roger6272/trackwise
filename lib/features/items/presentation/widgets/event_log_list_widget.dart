import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../events/domain/entities/event_log.dart';
import '../../../events/presentation/bloc/events_bloc.dart';
import '../../../events/presentation/bloc/events_state.dart';

/// Widget displaying a list of event logs.
///
/// Shows events in reverse chronological order (newest first).
/// Updates in real-time when new events are added via Bluetooth.
class EventLogListWidget extends StatelessWidget {
  /// Maximum number of events to display initially.
  final int initialDisplayCount;

  const EventLogListWidget({
    super.key,
    this.initialDisplayCount = 50,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EventsBloc, EventsState>(
      builder: (context, state) {
        if (state is EventsLoading) {
          return const _LoadingState();
        }

        if (state is EventsError) {
          return _ErrorState(message: state.message);
        }

        if (state is EventsLoaded) {
          if (state.events.isEmpty) {
            return const _EmptyState();
          }

          return _EventList(
            events: state.events,
            initialDisplayCount: initialDisplayCount,
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}

/// Loading state widget.
class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(32),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

/// Error state widget.
class _ErrorState extends StatelessWidget {
  final String message;

  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty state widget.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.event_note,
            size: 48,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No events found',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Events will appear here when recorded',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }
}

/// List of events with load more functionality.
class _EventList extends StatefulWidget {
  final List<EventLog> events;
  final int initialDisplayCount;

  const _EventList({
    required this.events,
    required this.initialDisplayCount,
  });

  @override
  State<_EventList> createState() => _EventListState();
}

class _EventListState extends State<_EventList> {
  late int _displayCount;

  @override
  void initState() {
    super.initState();
    _displayCount = widget.initialDisplayCount;
  }

  @override
  void didUpdateWidget(_EventList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset display count when events list changes significantly
    if (widget.events.length != oldWidget.events.length) {
      _displayCount = widget.initialDisplayCount;
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayEvents = widget.events.take(_displayCount).toList();
    final hasMore = widget.events.length > _displayCount;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Event Log',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  '${widget.events.length} events',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Event list
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayEvents.length + (hasMore ? 1 : 0),
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              if (index == displayEvents.length) {
                return _LoadMoreButton(
                  remaining: widget.events.length - _displayCount,
                  onPressed: () {
                    setState(() {
                      _displayCount += widget.initialDisplayCount;
                    });
                  },
                );
              }
              return _EventLogTile(event: displayEvents[index]);
            },
          ),
        ],
      ),
    );
  }
}

/// Single event log tile.
class _EventLogTile extends StatelessWidget {
  final EventLog event;

  const _EventLogTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('MMM d, y · h:mm a');
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: _EventIcon(eventName: event.eventName),
      title: Text(
        _formatEventName(event.eventName),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
      ),
      subtitle: Text(
        timeFormat.format(event.createdTime),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.outline,
            ),
      ),
      trailing: event.increment != 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: event.increment > 0
                    ? colorScheme.primaryContainer
                    : colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                event.increment > 0 ? '+${event.increment}' : '${event.increment}',
                style: TextStyle(
                  color: event.increment > 0
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onErrorContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
    );
  }

  String _formatEventName(String eventName) {
    // Convert snake_case or camelCase to Title Case
    return eventName
        .replaceAllMapped(
          RegExp(r'([a-z])([A-Z])'),
          (m) => '${m.group(1)} ${m.group(2)}',
        )
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isNotEmpty
            ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
            : '')
        .join(' ');
  }
}

/// Icon for different event types.
class _EventIcon extends StatelessWidget {
  final String eventName;

  const _EventIcon({required this.eventName});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    IconData icon;
    Color backgroundColor;
    Color iconColor;

    switch (eventName.toLowerCase()) {
      case 'increment':
        icon = Icons.add;
        backgroundColor = colorScheme.primaryContainer;
        iconColor = colorScheme.onPrimaryContainer;
        break;
      case 'decrement':
        icon = Icons.remove;
        backgroundColor = colorScheme.errorContainer;
        iconColor = colorScheme.onErrorContainer;
        break;
      case 'reset':
        icon = Icons.refresh;
        backgroundColor = colorScheme.tertiaryContainer;
        iconColor = colorScheme.onTertiaryContainer;
        break;
      case 'switch':
        icon = Icons.swap_horiz;
        backgroundColor = colorScheme.secondaryContainer;
        iconColor = colorScheme.onSecondaryContainer;
        break;
      default:
        icon = Icons.event;
        backgroundColor = colorScheme.surfaceContainerHighest;
        iconColor = colorScheme.onSurfaceVariant;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: iconColor, size: 20),
    );
  }
}

/// Button to load more events.
class _LoadMoreButton extends StatelessWidget {
  final int remaining;
  final VoidCallback onPressed;

  const _LoadMoreButton({
    required this.remaining,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.expand_more, size: 20),
            const SizedBox(width: 8),
            Text(
              'Load more ($remaining remaining)',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
