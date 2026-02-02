import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Step 2: Static product introduction screen.
///
/// Presents a brief overview of Traxelos One — what it is, what the user
/// needs, and what comes next in the onboarding flow.
class OnboardingStepIntro extends StatelessWidget {
  const OnboardingStepIntro({super.key, this.actions});

  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          // Hero icon
          Semantics(
            label: 'Traxelos One device icon',
            child: Icon(
              Icons.devices,
              size: 80,
              color: AppColors.primaryAdaptive(brightness),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Welcome to Traxelos One',
            style: textTheme.headlineSmall?.copyWith(
              color: primaryText,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Info sections
          _InfoSection(
            icon: Icons.touch_app,
            title: 'What is it?',
            body:
                'A physical counting device that pairs with this app via '
                'Bluetooth to track anything you need.',
            primaryText: primaryText,
            secondaryText: secondaryText,
            textTheme: textTheme,
            brightness: brightness,
          ),
          const SizedBox(height: 20),
          _InfoSection(
            icon: Icons.bluetooth,
            title: 'What you need',
            body:
                'Your Traxelos One device nearby with Bluetooth enabled '
                'on your phone.',
            primaryText: primaryText,
            secondaryText: secondaryText,
            textTheme: textTheme,
            brightness: brightness,
          ),
          const SizedBox(height: 20),
          _InfoSection(
            icon: Icons.rocket_launch,
            title: "What's next",
            body:
                "We'll help you pair your device so you can start "
                'counting right away.',
            primaryText: primaryText,
            secondaryText: secondaryText,
            textTheme: textTheme,
            brightness: brightness,
          ),
          const SizedBox(height: 24),
          if (actions != null) actions!,
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({
    required this.icon,
    required this.title,
    required this.body,
    required this.primaryText,
    required this.secondaryText,
    required this.textTheme,
    required this.brightness,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color primaryText;
  final Color secondaryText;
  final TextTheme textTheme;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$title: $body',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: AppColors.primaryAdaptive(brightness),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleSmall?.copyWith(
                    color: primaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: textTheme.bodyMedium?.copyWith(color: secondaryText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
