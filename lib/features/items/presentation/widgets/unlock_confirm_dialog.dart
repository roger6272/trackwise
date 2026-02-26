import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

Future<bool> showUnlockConfirmDialog({
  required BuildContext context,
  required String itemName,
  required String deviceName,
  required bool isBreakGlass,
}) async {
  return await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final brightness = Theme.of(ctx).brightness;
      return AlertDialog(
        backgroundColor: AppColors.secondaryBackground(brightness),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Release Item',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.primaryText(brightness),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(TextSpan(children: [
              const TextSpan(text: 'Release '),
              TextSpan(text: itemName, style: const TextStyle(fontWeight: FontWeight.w600)),
              const TextSpan(text: ' from '),
              TextSpan(text: deviceName, style: const TextStyle(fontWeight: FontWeight.w600)),
              const TextSpan(text: '?'),
            ])),
            if (isBreakGlass) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Unsynced counts will be discarded when $deviceName reconnects.',
                        style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.secondaryText(brightness)),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: isBreakGlass ? AppColors.error : AppColors.primary,
            ),
            child: const Text('Release', style: TextStyle(color: Colors.white)),
          ),
        ],
      );
    },
  ) ?? false;
}
