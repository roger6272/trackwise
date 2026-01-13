import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../../../flutter_flow/flutter_flow_theme.dart';
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
          extentRatio: 0.6,
          children: [
            SlidableAction(
              label: 'Update',
              backgroundColor: FlutterFlowTheme.of(context).primary,
              icon: Icons.edit,
              onPressed: (_) => onUpdate(),
            ),
            SlidableAction(
              label: 'Increment',
              backgroundColor: FlutterFlowTheme.of(context).secondary,
              icon: Icons.add,
              onPressed: (_) => onIncrement(),
            ),
            SlidableAction(
              label: 'Delete',
              backgroundColor: FlutterFlowTheme.of(context).error,
              icon: Icons.delete,
              onPressed: (_) => onDelete(),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).secondaryBackground,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(
              color: FlutterFlowTheme.of(context).alternate,
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
                          style: FlutterFlowTheme.of(context).titleMedium.override(
                            fontFamily: 'Inter Tight',
                            letterSpacing: 0.0,
                          ),
                        ),
                        SizedBox(height: 4.0),
                        Text(
                          'Today: ${item.todayCount} • Total: ${item.count}',
                          style: FlutterFlowTheme.of(context).bodySmall.override(
                            fontFamily: 'Inter',
                            color: FlutterFlowTheme.of(context).secondaryText,
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
                      color: FlutterFlowTheme.of(context).alternate,
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Text(
                      '+${item.incrementBy}',
                      style: FlutterFlowTheme.of(context).bodyMedium.override(
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
        return FlutterFlowTheme.of(context).primary;
      case ReminderType.interval:
        return FlutterFlowTheme.of(context).secondary;
      case ReminderType.everyTime:
        return FlutterFlowTheme.of(context).tertiary;
      case ReminderType.none:
      default:
        return FlutterFlowTheme.of(context).alternate;
    }
  }
}
