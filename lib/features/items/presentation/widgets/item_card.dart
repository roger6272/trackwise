import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/item.dart';

class ItemCard extends StatelessWidget {
  const ItemCard({
    super.key,
    required this.item,
    required this.onUpdate,
    required this.onDelete,
    required this.onIncrement,
  });

  final Item item;
  final VoidCallback onUpdate;
  final VoidCallback onDelete;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.0),
      child: Slidable(
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          extentRatio: 0.75,
          children: [
            SlidableAction(
              label: 'Update',
              backgroundColor: AppColors.primary,
              icon: Icons.edit,
              onPressed: (_) => onUpdate(),
            ),
            SlidableAction(
              label: 'Increment',
              backgroundColor: AppColors.secondary,
              icon: Icons.add,
              onPressed: (_) => onIncrement(),
            ),
            SlidableAction(
              label: 'Delete',
              backgroundColor: AppColors.error,
              icon: Icons.delete,
              onPressed: (_) => onDelete(),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(
              color: Theme.of(context).dividerColor,
              width: 1.0,
            ),
          ),
          child: InkWell(
            onTap: onIncrement,
            borderRadius: BorderRadius.circular(12.0),
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Row(
                children: [
                  // Reminder type indicator
                  Container(
                    width: 4.0,
                    height: 48.0,
                    decoration: BoxDecoration(
                      color: _getReminderColor(context),
                      borderRadius: BorderRadius.circular(2.0),
                    ),
                  ),
                  SizedBox(width: 16.0),
                  // Item details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontFamily: 'Inter Tight',
                            letterSpacing: 0.0,
                          ),
                        ),
                        SizedBox(height: 4.0),
                        Text(
                          'Today: ${item.todayCount} • Total: ${item.count}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontFamily: 'Inter',
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            letterSpacing: 0.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Increment indicator
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor,
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Text(
                      '+${item.incrementBy}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getReminderColor(BuildContext context) {
    switch (item.reminder) {
      case ReminderType.target:
        return AppColors.primary;
      case ReminderType.interval:
        return AppColors.secondary;
      case ReminderType.none:
        return Theme.of(context).dividerColor;
    }
  }
}
