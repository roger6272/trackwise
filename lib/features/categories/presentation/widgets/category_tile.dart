import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/category.dart';

/// A tile widget for displaying a category in the list.
class CategoryTile extends StatelessWidget {
  final Category category;
  final int index;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const CategoryTile({
    super.key,
    required this.category,
    required this.index,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final cardColor = AppColors.secondaryBackground(brightness);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: ReorderableDragStartListener(
          index: index,
          child: Icon(
            Icons.drag_handle_rounded,
            color: secondaryText,
          ),
        ),
        title: Text(
          category.name,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: primaryText,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Edit category',
              icon: Icon(
                Icons.edit_outlined,
                color: secondaryText,
                size: 20,
              ),
              onPressed: onTap,
            ),
            IconButton(
              tooltip: 'Delete category',
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error,
                size: 20,
              ),
              onPressed: onDelete,
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
