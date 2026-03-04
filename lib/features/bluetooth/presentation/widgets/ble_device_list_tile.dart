import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/ble_device.dart';

class BleDeviceListTile extends StatelessWidget {
  final BleDevice device;
  final bool isConnecting;
  final VoidCallback? onTap;

  const BleDeviceListTile({
    super.key,
    required this.device,
    required this.isConnecting,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: _buildSignalIcon(),
        title: Text(
          device.name.isNotEmpty ? device.name : 'Unknown Device',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '${device.id}\nSignal: ${device.rssi} dBm',
        ),
        isThreeLine: true,
        trailing: isConnecting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.chevron_right),
        onTap: isConnecting ? null : onTap,
      ),
    );
  }

  Widget _buildSignalIcon() {
    // RSSI ranges: -30 to -50 = excellent, -50 to -70 = good, -70 to -90 = weak
    IconData icon;
    Color color;

    if (device.rssi > -50) {
      icon = Icons.signal_cellular_4_bar;
      color = AppColors.success;
    } else if (device.rssi > -70) {
      icon = Icons.signal_cellular_alt;
      color = AppColors.warning;
    } else {
      icon = Icons.signal_cellular_alt_1_bar;
      color = AppColors.error;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color),
    );
  }
}
