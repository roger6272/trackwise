import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/constants.dart';
import '../../domain/entities/category.dart';

/// Dialog for creating or editing a category.
class CategoryFormDialog extends StatefulWidget {
  final Category? category;
  final void Function(String name) onSave;

  /// Existing category names for duplicate checking.
  final List<String> existingNames;

  const CategoryFormDialog({
    super.key,
    this.category,
    required this.onSave,
    this.existingNames = const [],
  });

  @override
  State<CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<CategoryFormDialog> {
  late final TextEditingController _nameController;
  final _formKey = GlobalKey<FormState>();

  bool get isEditing => widget.category != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final backgroundColor = AppColors.secondaryBackground(brightness);

    return AlertDialog(
      backgroundColor: backgroundColor,
      title: Text(
        isEditing ? 'Edit Category' : 'New Category',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: primaryText,
        ),
      ),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _nameController,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: TextStyle(color: primaryText),
          decoration: InputDecoration(
            labelText: 'Category Name',
            labelStyle: TextStyle(color: secondaryText),
            hintText: 'e.g., Electronics, Office Supplies',
            hintStyle: TextStyle(color: secondaryText.withValues(alpha: 0.5)),
            counterText: '${_nameController.text.length}/${AppConstants.maxCategoryNameLength}',
            counterStyle: Theme.of(context).textTheme.bodySmall?.copyWith(color: secondaryText),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: secondaryText.withValues(alpha: 0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
          maxLength: AppConstants.maxCategoryNameLength,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Category name is required';
            }
            final trimmed = value.trim().toLowerCase();
            final isDuplicate = widget.existingNames.any(
              (name) => name.toLowerCase() == trimmed,
            );
            if (isDuplicate) {
              return 'A category with this name already exists';
            }
            return null;
          },
          onChanged: (_) => setState(() {}), // Update counter
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(color: secondaryText),
          ),
        ),
        FilledButton(
          onPressed: _save,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
          ),
          child: Text(
            isEditing ? 'Save' : 'Create',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }

  void _save() {
    if (_formKey.currentState?.validate() ?? false) {
      final name = _nameController.text.trim();
      widget.onSave(name);
      Navigator.of(context).pop();
    }
  }
}
