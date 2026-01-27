import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';

/// Dialog shown when a device is locked to a different user account.
///
/// This happens when the device has a stored pairedUid that differs from
/// the current user's UID. The device cannot be used until it's unpaired
/// from the other account.
///
/// Actions:
/// - OK: Dismisses dialog and disconnects from device
class WrongAccountDialog extends StatelessWidget {
  /// Called when user dismisses the dialog
  final VoidCallback onDismiss;

  const WrongAccountDialog({
    super.key,
    required this.onDismiss,
  });

  /// Shows the wrong account dialog.
  static Future<void> show({
    required BuildContext context,
    required VoidCallback onDismiss,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => WrongAccountDialog(
        onDismiss: onDismiss,
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
        'Wrong Account',
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
            'This device is paired to a different account.',
            style: GoogleFonts.inter(
              color: primaryText,
              fontSize: 15.0,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'To use this device, sign in with the account it was originally paired with, or factory reset the device.',
            style: GoogleFonts.inter(
              color: secondaryText,
              fontSize: 14.0,
            ),
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            onDismiss();
          },
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
          ),
          child: Text(
            'OK',
            style: GoogleFonts.inter(color: Colors.white),
          ),
        ),
      ],
    );
  }
}
