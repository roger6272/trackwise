import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';

/// Dialog shown when an uninitialized device is detected (factory reset or new).
///
/// Asks the user to confirm transferring items to the new device.
///
/// Actions:
/// - Cancel: Disconnects from device without setting it up
/// - Transfer: Triggers override flow to transfer items to device
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
        style: GoogleFonts.interTight(
          fontWeight: FontWeight.w600,
          color: primaryText,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Transfer your items?',
            style: GoogleFonts.inter(
              color: primaryText,
              fontSize: 15.0,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Your items will be synced to the device.',
            style: GoogleFonts.inter(
              color: secondaryText,
              fontSize: 14.0,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context, false);
            onCancel();
          },
          child: Text(
            'Cancel',
            style: GoogleFonts.inter(color: secondaryText),
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
            'Transfer',
            style: GoogleFonts.inter(color: Colors.white),
          ),
        ),
      ],
    );
  }
}
