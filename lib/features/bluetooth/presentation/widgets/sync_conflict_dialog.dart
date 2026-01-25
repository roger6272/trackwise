import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';

/// Dialog shown when a sync conflict is detected (sync_seq mismatch).
///
/// Explains that the device needs to be updated to match the app's data,
/// and that any counts on the device since last sync will be replaced.
///
/// Actions:
/// - Cancel: Disconnects from device without syncing
/// - Sync Now: Triggers override flow (app data -> device)
class SyncConflictDialog extends StatelessWidget {
  /// Called when user confirms the override
  final VoidCallback onConfirm;

  /// Called when user cancels (should disconnect BLE)
  final VoidCallback onCancel;

  const SyncConflictDialog({
    super.key,
    required this.onConfirm,
    required this.onCancel,
  });

  /// Shows the sync conflict dialog.
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
      builder: (context) => SyncConflictDialog(
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
        'Sync Required',
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
            'This device needs to be updated to match your app.',
            style: GoogleFonts.inter(
              color: primaryText,
              fontSize: 15.0,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Any counts on this device since your last sync will be replaced.',
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
            'Sync Now',
            style: GoogleFonts.inter(color: Colors.white),
          ),
        ),
      ],
    );
  }
}
