import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Dialog shown when an uninitialized device is detected (factory reset or new).
///
/// Asks the user to confirm pairing the device to their account.
///
/// Actions:
/// - Cancel: Disconnects from device without setting it up
/// - Set Up: Triggers override flow to pair and sync items to device
class DeviceSetupDialog extends StatelessWidget {
  /// Called when user confirms the transfer
  final VoidCallback onConfirm;

  /// Called when user cancels (should disconnect BLE)
  final VoidCallback onCancel;

  const DeviceSetupDialog({
    super.key,
    required this.onConfirm,
    required this.onCancel,
  });

  /// Shows the device setup dialog.
  ///
  /// Returns true if user confirmed, false if cancelled.
  static Future<bool?> show({
    required BuildContext context,
    required VoidCallback onConfirm,
    required VoidCallback onCancel,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => DeviceSetupDialog(
        onConfirm: onConfirm,
        onCancel: onCancel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final backgroundColor = AppColors.secondaryBackground(brightness);

    return AlertDialog(
      backgroundColor: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      title: Text(
        'New Device Detected',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: primaryText,
        ),
      ),
      content: Text(
        'This will pair the device to your account. Your items will sync automatically.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: secondaryText,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context, false);
            onCancel();
          },
          child: Text(
            'Cancel',
            style: TextStyle(color: secondaryText),
          ),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context, true);
            onConfirm();
          },
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
          ),
          child: Text(
            'Set Up',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}
