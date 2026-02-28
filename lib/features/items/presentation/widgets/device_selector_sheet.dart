import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class DeviceSelectorSheet extends StatelessWidget {
  final List<({String instanceId, String name, int color})> devices;
  final ValueChanged<String> onDeviceSelected;

  const DeviceSelectorSheet({
    super.key,
    required this.devices,
    required this.onDeviceSelected,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground(brightness),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.secondaryText(brightness).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Select Device',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.primaryText(brightness),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Divider(height: 1),
            ...devices.map((d) => ListTile(
              leading: Icon(Icons.watch,
                  color: AppColors.deviceColor(d.color, brightness)),
              title: Text(
                d.name,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.primaryText(brightness),
                ),
              ),
              onTap: () => onDeviceSelected(d.instanceId),
            )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
