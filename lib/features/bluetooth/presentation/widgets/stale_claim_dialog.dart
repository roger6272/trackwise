import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Dialog shown when a device reconnects and has stale claims
/// (items that were unlocked while the device was offline).
///
/// Actions:
/// - Keep Offline: Disconnects without syncing (device keeps its counts)
/// - Sync Now: Triggers override flow (app data -> device, stale counts discarded)
class StaleClaimDialog extends StatelessWidget {
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final String? deviceName;
  final List<String> itemNames;

  const StaleClaimDialog({
    super.key,
    required this.onConfirm,
    required this.onCancel,
    this.deviceName,
    required this.itemNames,
  });

  static Future<bool?> show({
    required BuildContext context,
    required VoidCallback onConfirm,
    required VoidCallback onCancel,
    String? deviceName,
    required List<String> itemNames,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StaleClaimDialog(
        onConfirm: onConfirm,
        onCancel: onCancel,
        deviceName: deviceName,
        itemNames: itemNames,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final backgroundColor = AppColors.secondaryBackground(brightness);

    final deviceLabel = deviceName != null ? '"$deviceName"' : 'your device';

    return AlertDialog(
      backgroundColor: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      title: Text(
        'Items Unlocked',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: primaryText,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'While $deviceLabel was offline, the following '
            '${itemNames.length == 1 ? 'item was' : 'items were'} unlocked:',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: primaryText,
              fontSize: 15.0,
            ),
          ),
          const SizedBox(height: 8),
          ...itemNames.map((name) => Padding(
            padding: const EdgeInsets.only(left: 8, top: 2, bottom: 2),
            child: Row(
              children: [
                Icon(Icons.lock_open, size: 16, color: AppColors.warningText(brightness)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: primaryText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          )),
          const SizedBox(height: 12),
          Text(
            'Syncing will discard any unsaved counts on the device for these items.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: secondaryText,
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
            'Keep Offline',
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
          child: const Text(
            'Sync Now',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}
