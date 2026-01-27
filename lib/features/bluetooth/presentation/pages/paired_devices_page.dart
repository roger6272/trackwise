import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/paired_device.dart';
import '../bloc/bluetooth_bloc.dart';
import '../bloc/bluetooth_event.dart';
import '../bloc/bluetooth_state.dart';

/// Page for managing paired Trackwise devices.
///
/// Displays a list of all devices paired to the user's account.
/// Allows renaming and unpairing devices.
///
/// Connected device is shown with a green indicator.
class PairedDevicesPage extends StatefulWidget {
  const PairedDevicesPage({super.key});

  static const String routeName = 'PairedDevicesPage';
  static const String routePath = 'paired-devices';

  @override
  State<PairedDevicesPage> createState() => _PairedDevicesPageState();
}

class _PairedDevicesPageState extends State<PairedDevicesPage> {
  @override
  void initState() {
    super.initState();
    // Load paired devices when page opens
    context.read<BluetoothBloc>().add(const LoadPairedDevices());
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primaryBackground = AppColors.primaryBackground(brightness);
    final primaryText = AppColors.primaryText(brightness);

    return Scaffold(
      backgroundColor: primaryBackground,
      appBar: AppBar(
        backgroundColor: primaryBackground,
        title: Text(
          'Paired Devices',
          style: GoogleFonts.interTight(
            color: primaryText,
            fontWeight: FontWeight.w600,
            fontSize: 22.0,
          ),
        ),
        elevation: 0.0,
      ),
      body: BlocBuilder<BluetoothBloc, BluetoothState>(
        builder: (context, state) {
          final devices = state.pairedDevices;

          if (devices.isEmpty) {
            return _buildEmptyState(context);
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final device = devices[index];
              final isConnected =
                  state.connectedDeviceInstanceId == device.deviceInstanceId;

              return _DeviceListTile(
                device: device,
                isConnected: isConnected,
                onRename: () => _showRenameDialog(context, device),
                onUnpair: () => _showUnpairDialog(context, device),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final secondaryText = AppColors.secondaryText(brightness);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.devices_outlined,
              size: 64,
              color: secondaryText.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No devices paired',
              style: GoogleFonts.interTight(
                color: secondaryText,
                fontSize: 18.0,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Connect to a Trackwise device to pair it with your account.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: secondaryText.withValues(alpha: 0.7),
                fontSize: 14.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, PairedDevice device) {
    final brightness = Theme.of(context).brightness;
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final backgroundColor = AppColors.secondaryBackground(brightness);

    final controller = TextEditingController(text: device.deviceName);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        title: Text(
          'Rename Device',
          style: GoogleFonts.interTight(
            fontWeight: FontWeight.w600,
            color: primaryText,
          ),
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            style: GoogleFonts.inter(color: primaryText),
            decoration: InputDecoration(
              labelText: 'Device Name',
              labelStyle: GoogleFonts.inter(color: secondaryText),
              hintText: 'e.g., Office Counter, Home Device',
              hintStyle: GoogleFonts.inter(
                color: secondaryText.withValues(alpha: 0.5),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: secondaryText.withValues(alpha: 0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
            maxLength: 32,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Device name is required';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: secondaryText),
            ),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(dialogContext).pop();
                final newName = controller.text.trim();
                context.read<BluetoothBloc>().add(
                      UpdateDeviceName(
                        deviceInstanceId: device.deviceInstanceId,
                        newName: newName,
                      ),
                    );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: Text(
              'Save',
              style: GoogleFonts.inter(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showUnpairDialog(BuildContext context, PairedDevice device) {
    final brightness = Theme.of(context).brightness;
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final backgroundColor = AppColors.secondaryBackground(brightness);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        title: Text(
          'Unpair Device',
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
              'To complete unpairing, factory reset the device.',
              style: GoogleFonts.inter(
                color: primaryText,
                fontSize: 15.0,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: secondaryText.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: secondaryText,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'On device: Hold B button for 10 seconds.',
                      style: GoogleFonts.inter(
                        color: secondaryText,
                        fontSize: 13.0,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: secondaryText),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<BluetoothBloc>().add(
                    RemovePairedDevice(device.deviceInstanceId),
                  );
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text(
              'Remove from List',
              style: GoogleFonts.inter(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// List tile for displaying a paired device.
class _DeviceListTile extends StatelessWidget {
  final PairedDevice device;
  final bool isConnected;
  final VoidCallback onRename;
  final VoidCallback onUnpair;

  const _DeviceListTile({
    required this.device,
    required this.isConnected,
    required this.onRename,
    required this.onUnpair,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final secondaryBackground = AppColors.secondaryBackground(brightness);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: isConnected
            ? Colors.green.withValues(alpha: 0.15)
            : secondaryBackground,
        borderRadius: BorderRadius.circular(12.0),
        border: isConnected
            ? Border.all(color: Colors.green.withValues(alpha: 0.5), width: 1.5)
            : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 8.0,
        ),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isConnected
                ? Colors.green.withValues(alpha: 0.1)
                : secondaryText.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.watch,
            color: isConnected ? Colors.green : secondaryText,
            size: 28,
          ),
        ),
        title: Text(
          device.deviceName,
          style: GoogleFonts.inter(
            color: primaryText,
            fontWeight: FontWeight.w500,
            fontSize: 16.0,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isConnected ? 'Connected' : 'Paired ${_formatDate(device.pairedAt)}',
              style: GoogleFonts.inter(
                color: isConnected ? Colors.green : secondaryText,
                fontSize: 13.0,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'ID: ${device.deviceInstanceId}',
              style: TextStyle(
                color: secondaryText.withValues(alpha: 0.6),
                fontSize: 11.0,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: secondaryText),
          onSelected: (value) {
            if (value == 'rename') {
              onRename();
            } else if (value == 'unpair') {
              onUnpair();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'rename',
              child: Row(
                children: const [
                  Icon(Icons.edit_outlined, size: 20),
                  SizedBox(width: 12),
                  Text('Rename'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'unpair',
              child: Row(
                children: [
                  const Icon(Icons.link_off, size: 20, color: Colors.red),
                  const SizedBox(width: 12),
                  Text(
                    'Unpair',
                    style: GoogleFonts.inter(color: Colors.red),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'today';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }
}
