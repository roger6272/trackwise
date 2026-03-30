import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/firmware_info.dart';
import '../bloc/ota_bloc.dart';
import '../bloc/ota_event.dart';
import '../bloc/ota_state.dart';

/// Bottom sheet that shows OTA update progress.
///
/// Displays:
/// - Firmware version and changelog
/// - Sequential progress: Download -> Transfer -> Verify -> Reboot
/// - Cancel button with confirmation
/// - Success/error messages
class OtaProgressSheet extends StatelessWidget {
  final FirmwareInfo firmwareInfo;
  final int negotiatedMtu;

  const OtaProgressSheet({
    super.key,
    required this.firmwareInfo,
    required this.negotiatedMtu,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final backgroundColor = AppColors.secondaryBackground(brightness);

    return BlocConsumer<OtaBloc, OtaBlocState>(
      listener: (context, state) {
        // Auto-dismiss on complete or error after delay
        if (state is OtaBlocComplete) {
          Future.delayed(const Duration(seconds: 3), () {
            if (context.mounted) Navigator.of(context).pop();
          });
        }
      },
      builder: (context, state) {
        return Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: secondaryText.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Title
                  Text(
                    'Firmware Update',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: primaryText,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'v${firmwareInfo.version}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: secondaryText,
                        ),
                  ),
                  if (firmwareInfo.changelog.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: secondaryText.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        firmwareInfo.changelog,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: secondaryText,
                            ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  // Progress content based on state
                  _buildContent(context, state),
                  const SizedBox(height: 16),
                  // Action buttons
                  _buildActions(context, state),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, OtaBlocState state) {
    final brightness = Theme.of(context).brightness;
    final primaryColor = AppColors.primaryAdaptive(brightness);
    final secondaryText = AppColors.secondaryText(brightness);

    return switch (state) {
      OtaUpdateAvailable() || OtaInitial() => _StepList(
          currentStep: -1,
          secondaryText: secondaryText,
          primaryColor: primaryColor,
        ),
      OtaBlocDownloading() => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StepList(
              currentStep: 0,
              progress: state.progress,
              secondaryText: secondaryText,
              primaryColor: primaryColor,
            ),
          ],
        ),
      OtaBlocTransferring() => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StepList(
              currentStep: 1,
              progress: state.progress,
              secondaryText: secondaryText,
              primaryColor: primaryColor,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.warningText(brightness)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Don\'t turn off your device',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.warningText(brightness),
                          fontStyle: FontStyle.italic,
                        ),
                  ),
                ),
              ],
            ),
          ],
        ),
      OtaBlocVerifying() => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StepList(
              currentStep: 2,
              secondaryText: secondaryText,
              primaryColor: primaryColor,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.warningText(brightness)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Don\'t turn off your device',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.warningText(brightness),
                          fontStyle: FontStyle.italic,
                        ),
                  ),
                ),
              ],
            ),
          ],
        ),
      OtaBlocRebooting() => _StepList(
          currentStep: 3,
          secondaryText: secondaryText,
          primaryColor: primaryColor,
        ),
      OtaBlocComplete() => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 48, color: AppColors.success),
            const SizedBox(height: 12),
            Text(
              'Update complete!',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Firmware updated to v${state.newVersion}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: secondaryText,
                  ),
            ),
          ],
        ),
      OtaBlocError() => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              'Update failed',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              state.message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: secondaryText,
                  ),
            ),
          ],
        ),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _buildActions(BuildContext context, OtaBlocState state) {
    return switch (state) {
      OtaUpdateAvailable() || OtaInitial() => Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Later',
                style: TextStyle(color: AppColors.secondaryText(Theme.of(context).brightness)),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () {
                context.read<OtaBloc>().add(StartUpdateRequested(
                      firmwareInfo: firmwareInfo,
                      negotiatedMtu: negotiatedMtu,
                    ));
              },
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Update Now', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      OtaBlocDownloading() || OtaBlocTransferring() => Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => _showCancelConfirmation(context),
              child: const Text('Cancel', style: TextStyle(color: AppColors.error)),
            ),
          ],
        ),
      OtaBlocVerifying() || OtaBlocRebooting() => const SizedBox.shrink(),
      OtaBlocComplete() => Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(backgroundColor: AppColors.success),
              child: const Text('Done', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      OtaBlocError() => Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Dismiss', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      _ => const SizedBox.shrink(),
    };
  }

  void _showCancelConfirmation(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final backgroundColor = AppColors.secondaryBackground(brightness);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        title: Text(
          'Cancel Update?',
          style: TextStyle(fontWeight: FontWeight.w600, color: primaryText),
        ),
        content: Text(
          'The firmware update will be cancelled. You can start it again later.',
          style: TextStyle(color: secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('Continue Update', style: TextStyle(color: secondaryText)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<OtaBloc>().add(const CancelUpdateRequested());
              Navigator.of(context).pop(); // Close bottom sheet
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Cancel Update', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ========== Step List ==========

class _StepList extends StatelessWidget {
  final int currentStep;
  final double? progress;
  final Color secondaryText;
  final Color primaryColor;

  const _StepList({
    required this.currentStep,
    this.progress,
    required this.secondaryText,
    required this.primaryColor,
  });

  static const _steps = [
    'Download firmware',
    'Transfer to device',
    'Verify installation',
    'Reboot device',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_steps.length, (index) {
        final isComplete = index < currentStep;
        final isCurrent = index == currentStep;
        final isPending = index > currentStep;

        final color = isComplete
            ? AppColors.success
            : isCurrent
                ? primaryColor
                : secondaryText.withValues(alpha: 0.5);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: isComplete
                    ? Icon(Icons.check_circle, size: 20, color: color)
                    : isCurrent
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.0,
                              color: color,
                              value: (index == 0 || index == 1) ? progress : null,
                            ),
                          )
                        : Icon(Icons.circle_outlined, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _steps[index],
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isPending
                            ? secondaryText.withValues(alpha: 0.5)
                            : isCurrent
                                ? primaryColor
                                : AppColors.success,
                        fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                      ),
                ),
              ),
              if (isCurrent && progress != null)
                Text(
                  '${(progress! * 100).toInt()}%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                ),
            ],
          ),
        );
      }),
    );
  }
}
