import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Step 4: Onboarding completion screen.
///
/// Shows a success summary with the paired device name.
/// Only shown when device pairing (Step 3) was completed.
class OnboardingStepDone extends StatelessWidget {
  final String? deviceName;
  final Widget? actions;

  const OnboardingStepDone({
    super.key,
    this.deviceName,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final secondaryBackground = AppColors.secondaryBackground(brightness);
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 48),
          // Success icon
          Semantics(
            label: 'Setup complete',
            child: const Icon(
              Icons.check_circle_outline,
              size: 80,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "You're All Set!",
            style: textTheme.headlineSmall?.copyWith(
              color: primaryText,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Info card
          if (deviceName != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: secondaryBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Semantics(
                label: 'Paired device: $deviceName',
                child: Row(
                  children: [
                    Icon(
                      Icons.bluetooth_connected,
                      color: AppColors.primaryAdaptive(brightness),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Device',
                            style: textTheme.bodySmall?.copyWith(
                              color: secondaryText,
                            ),
                          ),
                          Text(
                            deviceName!,
                            style: textTheme.bodyLarge?.copyWith(
                              color: primaryText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 32),

          // Subtitle
          Semantics(
            label: 'Press the button on your Traxelos One to start counting',
            child: Text(
              'Your device is ready to count. Press the button on your '
              'Traxelos One to start!',
              style: textTheme.bodyMedium?.copyWith(color: secondaryText),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          if (actions != null) actions!,
        ],
      ),
    );
  }
}
