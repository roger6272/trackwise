import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/auth/auth_state_notifier.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_util.dart';
import '../../../../core/utils/logger.dart';
import '../../../items/domain/entities/item.dart';
import '../../../items/domain/repositories/item_repository.dart';
import '../../../items/domain/usecases/create_item_usecase.dart';

/// Step 4: Simplified item creation form for onboarding.
///
/// Pre-fills the item name based on the selected use case from Step 1.
/// Creates the item via [CreateItemUseCase] and reports back to the parent.
class OnboardingStepCreateItem extends StatefulWidget {
  final String? selectedUseCase;
  final void Function({required bool created, String? itemName}) onItemCreated;

  const OnboardingStepCreateItem({
    super.key,
    required this.selectedUseCase,
    required this.onItemCreated,
  });

  @override
  State<OnboardingStepCreateItem> createState() =>
      _OnboardingStepCreateItemState();
}

class _OnboardingStepCreateItemState extends State<OnboardingStepCreateItem> {
  final _nameController = TextEditingController();
  final _goalController = TextEditingController();
  final _incrementController = TextEditingController(text: '1');
  final _formKey = GlobalKey<FormState>();
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = _prefillName(widget.selectedUseCase);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _goalController.dispose();
    _incrementController.dispose();
    super.dispose();
  }

  String _prefillName(String? useCase) {
    switch (useCase) {
      case 'inventory':
        return 'Stock Count';
      case 'habits':
        return 'Water Intake';
      case 'fitness':
        return 'Push-ups';
      case 'manufacturing':
        return 'Units Produced';
      default:
        return '';
    }
  }

  Future<void> _createItem() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isCreating) return;

    setState(() => _isCreating = true);

    final name = _nameController.text.trim();
    final goalText = _goalController.text.trim();
    final incrementText = _incrementController.text.trim();

    final goal = goalText.isNotEmpty ? int.tryParse(goalText) : null;
    final incrementBy =
        incrementText.isNotEmpty ? (int.tryParse(incrementText) ?? 1) : 1;

    final userId = AuthStateNotifier.instance.uid;
    if (userId == null) {
      if (mounted) {
        setState(() => _isCreating = false);
        showErrorSnackBar(context, 'Not authenticated. Please try again.');
      }
      return;
    }

    final createItemUseCase = sl<CreateItemUseCase>();
    final result = await createItemUseCase(CreateItemParams(
      name: name,
      incrementBy: incrementBy,
      reminder: ReminderType.none,
      reminderValue: 0,
      userId: userId,
    ));

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() => _isCreating = false);
        showErrorSnackBar(context, failure.message);
        AppLogger.error('Onboarding item creation failed: ${failure.message}');
      },
      (createdItem) async {
        // If a goal was set, update the item with the goal
        if (goal != null && goal > 0) {
          final repo = sl<ItemRepository>();
          await repo.updateItem(createdItem.copyWith(goal: goal));
        }
        widget.onItemCreated(created: true, itemName: name);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            // Header icon
            Semantics(
              label: 'Create item icon',
              child: Icon(
                Icons.add_circle_outline,
                size: 64,
                color: AppColors.primaryAdaptive(brightness),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Create Your First Item',
              style: textTheme.headlineSmall?.copyWith(
                color: primaryText,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Give your counter a name and set an optional goal',
              style: textTheme.bodyMedium?.copyWith(color: secondaryText),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Item name field
            Semantics(
              label: 'Item name input',
              child: TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Item Name',
                  hintText: 'e.g. Push-ups, Coffee, Units',
                  prefixIcon: const Icon(Icons.label_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                textCapitalization: TextCapitalization.words,
                maxLength: 30,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter an item name';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 16),

            // Goal field
            Semantics(
              label: 'Daily goal input',
              child: TextFormField(
                controller: _goalController,
                decoration: InputDecoration(
                  labelText: 'Daily Goal (optional)',
                  hintText: 'Daily goal (optional)',
                  prefixIcon: const Icon(Icons.flag_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
            const SizedBox(height: 16),

            // Count per press field
            Semantics(
              label: 'Count per press input',
              child: TextFormField(
                controller: _incrementController,
                decoration: InputDecoration(
                  labelText: 'Count per Press',
                  hintText: 'Count per press',
                  prefixIcon: const Icon(Icons.plus_one),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a value';
                  }
                  final parsed = int.tryParse(value.trim());
                  if (parsed == null || parsed < 1 || parsed > 100) {
                    return 'Must be between 1 and 100';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 32),

            // Create button
            SizedBox(
              height: 50,
              child: Semantics(
                label: 'Create item button',
                child: FilledButton(
                  onPressed: _isCreating ? null : _createItem,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isCreating
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Create',
                          style: textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
