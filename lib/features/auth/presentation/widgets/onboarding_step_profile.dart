import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Step 1: User profile & preferences form.
///
/// Collects optional name, required use-case selection, and optional
/// referral source. All state lives in the parent [OnboardingPage];
/// this widget receives values + callbacks.
class OnboardingStepProfile extends StatelessWidget {
  const OnboardingStepProfile({
    super.key,
    required this.selectedUseCase,
    required this.selectedReferral,
    required this.nameText,
    required this.otherUseCaseText,
    required this.otherReferralText,
    required this.onUseCaseChanged,
    required this.onReferralChanged,
    required this.onNameChanged,
    required this.onOtherUseCaseChanged,
    required this.onOtherReferralChanged,
    this.actions,
  });

  final String? selectedUseCase;
  final String? selectedReferral;
  final String nameText;
  final String otherUseCaseText;
  final String otherReferralText;
  final ValueChanged<String> onUseCaseChanged;
  final ValueChanged<String?> onReferralChanged;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onOtherUseCaseChanged;
  final ValueChanged<String> onOtherReferralChanged;
  final Widget? actions;

  static const _useCases = <(String, String, String)>[
    ('inventory', 'Inventory Tracking', 'Track stock, supplies, or materials'),
    ('habits', 'Habit Tracking', 'Build and maintain daily habits'),
    ('fitness', 'Fitness & Exercise', 'Count reps, sets, or workouts'),
    (
      'manufacturing',
      'Manufacturing',
      'Track production or quality counts',
    ),
    ('other', 'Other', 'Something else'),
  ];

  static const _referrals = <(String, String)>[
    ('friend', 'Friend or Colleague'),
    ('social', 'Social Media'),
    ('search', 'Search Engine'),
    ('appstore', 'App Store'),
    ('other', 'Other'),
  ];

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final secondaryBg = AppColors.secondaryBackground(brightness);
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Header ---
          Text(
            'Tell us about yourself',
            style: textTheme.headlineSmall?.copyWith(
              color: primaryText,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Help us personalise your experience.',
            style: textTheme.bodyMedium?.copyWith(color: secondaryText),
          ),
          const SizedBox(height: 24),

          // --- Name field ---
          Semantics(
            label: 'Your name',
            child: TextField(
              onChanged: onNameChanged,
              controller: TextEditingController.fromValue(
                TextEditingValue(
                  text: nameText,
                  selection: TextSelection.collapsed(offset: nameText.length),
                ),
              ),
              decoration: InputDecoration(
                hintText: 'Your name (optional)',
                filled: true,
                fillColor: secondaryBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              style: textTheme.bodyLarge?.copyWith(color: primaryText),
              textCapitalization: TextCapitalization.words,
            ),
          ),
          const SizedBox(height: 28),

          // --- Use case (required) ---
          Text(
            'What will you use Traxelos for?',
            style: textTheme.titleMedium?.copyWith(
              color: primaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ..._useCases.map(
            (uc) => _UseCaseCard(
              value: uc.$1,
              title: uc.$2,
              subtitle: uc.$3,
              selected: selectedUseCase == uc.$1,
              onTap: () => onUseCaseChanged(uc.$1),
            ),
          ),

          // Other use-case text field
          if (selectedUseCase == 'other') ...[
            const SizedBox(height: 8),
            Semantics(
              label: 'Describe your use case',
              child: TextField(
                onChanged: onOtherUseCaseChanged,
                controller: TextEditingController.fromValue(
                  TextEditingValue(
                    text: otherUseCaseText,
                    selection: TextSelection.collapsed(
                      offset: otherUseCaseText.length,
                    ),
                  ),
                ),
                decoration: InputDecoration(
                  hintText: 'Tell us more…',
                  filled: true,
                  fillColor: secondaryBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                style: textTheme.bodyLarge?.copyWith(color: primaryText),
              ),
            ),
          ],
          const SizedBox(height: 28),

          // --- Referral source (optional) ---
          Text(
            'How did you hear about us?',
            style: textTheme.titleMedium?.copyWith(
              color: primaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Optional',
            style: textTheme.bodySmall?.copyWith(color: secondaryText),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _referrals.map((r) {
              final isSelected = selectedReferral == r.$1;
              return Semantics(
                label: r.$2,
                selected: isSelected,
                child: ChoiceChip(
                  label: Text(r.$2),
                  selected: isSelected,
                  onSelected: (_) {
                    // Toggle off if already selected
                    onReferralChanged(isSelected ? null : r.$1);
                  },
                  selectedColor: AppColors.primary.withValues(alpha: 0.15),
                  labelStyle: textTheme.bodyMedium?.copyWith(
                    color: isSelected ? AppColors.primary : primaryText,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.alternate(brightness),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              );
            }).toList(),
          ),

          // Other referral text field
          if (selectedReferral == 'other') ...[
            const SizedBox(height: 12),
            Semantics(
              label: 'Describe how you heard about us',
              child: TextField(
                onChanged: onOtherReferralChanged,
                controller: TextEditingController.fromValue(
                  TextEditingValue(
                    text: otherReferralText,
                    selection: TextSelection.collapsed(
                      offset: otherReferralText.length,
                    ),
                  ),
                ),
                decoration: InputDecoration(
                  hintText: 'Tell us more…',
                  filled: true,
                  fillColor: secondaryBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                style: textTheme.bodyLarge?.copyWith(color: primaryText),
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (actions != null) actions!,
        ],
      ),
    );
  }
}

/// A tappable card representing a use-case option.
class _UseCaseCard extends StatelessWidget {
  const _UseCaseCard({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String value;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final secondaryBg = AppColors.secondaryBackground(brightness);
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        label: '$title — $subtitle',
        selected: selected,
        child: Material(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.1)
              : secondaryBg,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? AppColors.primary
                      : AppColors.alternate(brightness),
                  width: selected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: textTheme.bodyLarge?.copyWith(
                            color: primaryText,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: textTheme.bodySmall?.copyWith(
                            color: secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: selected ? AppColors.primary : secondaryText,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
