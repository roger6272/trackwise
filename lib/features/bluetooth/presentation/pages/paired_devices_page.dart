import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_util.dart';
import '../../domain/entities/paired_device.dart';
import '../bloc/bluetooth_bloc.dart';
import '../bloc/bluetooth_event.dart';
import '../bloc/bluetooth_state.dart';
import '../widgets/device_color_picker_dialog.dart';

/// Page for managing paired Traxelos devices.
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
  /// The deviceInstanceId we're connecting to from this page (null if not connecting).
  String? _connectingDeviceId;

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
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: Icon(Icons.arrow_back_ios_rounded, color: primaryText),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Paired Devices',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: primaryText,
          ),
        ),
        centerTitle: true,
      ),
      body: BlocConsumer<BluetoothBloc, BluetoothState>(
        listener: (context, state) {
          if (_connectingDeviceId != null) {
            if (state.connectedDevices.containsKey(_connectingDeviceId)) {
              _connectingDeviceId = null;
              showSuccessSnackBar(context, 'Connected to device');
            } else if (state.status == BluetoothStatus.error &&
                state.errorMessage != null) {
              _connectingDeviceId = null;
              showErrorSnackBar(context, state.errorMessage!);
            }
          }
        },
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
                  state.connectedDevices.containsKey(device.deviceInstanceId);

              final isConnecting =
                  state.connectingDeviceId == device.deviceInstanceId;

              return _DeviceListTile(
                device: device,
                isConnected: isConnected,
                isConnecting: isConnecting,
                onRename: () => _showRenameDialog(context, device),
                onChangeColor: () => _showColorPickerDialog(context, device),
                onUnpair: () => _showUnpairDialog(context, device),
                onConnect: () {
                  _connectingDeviceId = device.deviceInstanceId;
                  context.read<BluetoothBloc>().add(
                        ConnectToDevice(device.deviceInstanceId),
                      );
                },
                onDisconnect: () {
                  final btBloc = context.read<BluetoothBloc>();
                  btBloc.add(DisconnectFromDevice(
                    deviceInstanceId: btBloc.state.connectedDeviceInstanceId ?? '',
                  ));
                },
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
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: secondaryText,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Connect to a Traxelos device to pair it with your account.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: secondaryText.withValues(alpha: 0.7),
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
          style: TextStyle(
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
            style: TextStyle(color: primaryText),
            decoration: InputDecoration(
              labelText: 'Device Name',
              labelStyle: TextStyle(color: secondaryText),
              hintText: 'e.g., Office Counter, Home Device',
              hintStyle: TextStyle(
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
              style: TextStyle(color: secondaryText),
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
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showColorPickerDialog(BuildContext context, PairedDevice device) {
    showDialog(
      context: context,
      builder: (dialogContext) => DeviceColorPickerDialog(
        currentColor: device.color,
        onColorSelected: (newColor) {
          Navigator.of(dialogContext).pop();
          context.read<BluetoothBloc>().add(
            UpdateDeviceColor(
              deviceInstanceId: device.deviceInstanceId,
              newColor: newColor,
            ),
          );
        },
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
              'To complete unpairing, factory reset the device.',
              style: Theme.of(dialogContext).textTheme.bodyLarge?.copyWith(
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
                      style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
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
              style: TextStyle(color: secondaryText),
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
              backgroundColor: AppColors.error,
            ),
            child: Text(
              'Remove from List',
              style: const TextStyle(color: Colors.white),
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
  final bool isConnecting;
  final VoidCallback onRename;
  final VoidCallback onChangeColor;
  final VoidCallback onUnpair;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  const _DeviceListTile({
    required this.device,
    required this.isConnected,
    this.isConnecting = false,
    required this.onRename,
    required this.onChangeColor,
    required this.onUnpair,
    required this.onConnect,
    required this.onDisconnect,
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
            ? AppColors.success.withValues(alpha: 0.15)
            : secondaryBackground,
        borderRadius: BorderRadius.circular(12.0),
        border: isConnected
            ? Border.all(color: AppColors.success.withValues(alpha: 0.5), width: 1.5)
            : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 8.0,
        ),
        onTap: (!isConnected && !isConnecting) ? onConnect : null,
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isConnected
                ? AppColors.success.withValues(alpha: 0.1)
                : secondaryText.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: isConnecting
              ? Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.primary,
                    ),
                  ),
                )
              : Stack(
                  children: [
                    Center(child: Icon(
                      Icons.watch,
                      color: isConnected ? AppColors.success : secondaryText,
                      size: 28,
                    )),
                    Positioned(right: 2, bottom: 2, child: Container(
                      width: 12, height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.deviceColor(device.color, brightness),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: secondaryBackground.withValues(alpha: 0.8),
                          width: 1.5,
                        ),
                      ),
                    )),
                  ],
                ),
        ),
        title: Text(
          device.deviceName,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: primaryText,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isConnecting
                  ? 'Connecting...'
                  : isConnected
                      ? 'Connected'
                      : 'Paired ${_formatDate(device.pairedAt)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isConnecting
                    ? AppColors.primary
                    : isConnected
                        ? AppColors.success
                        : secondaryText,
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
            if (value == 'connect') {
              onConnect();
            } else if (value == 'disconnect') {
              onDisconnect();
            } else if (value == 'rename') {
              onRename();
            } else if (value == 'color') {
              onChangeColor();
            } else if (value == 'unpair') {
              onUnpair();
            }
          },
          itemBuilder: (context) => [
            if (!isConnected && !isConnecting)
              PopupMenuItem(
                value: 'connect',
                child: Row(
                  children: [
                    Icon(Icons.bluetooth_connected, size: 20, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Text(
                      'Connect',
                      style: TextStyle(color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            if (isConnected)
              PopupMenuItem(
                value: 'disconnect',
                child: Row(
                  children: [
                    Icon(Icons.bluetooth_disabled, size: 20, color: AppColors.error),
                    const SizedBox(width: 12),
                    Text(
                      'Disconnect',
                      style: TextStyle(color: AppColors.error),
                    ),
                  ],
                ),
              ),
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
              value: 'color',
              child: Row(
                children: [
                  Icon(Icons.palette_outlined, size: 20,
                    color: AppColors.deviceColor(device.color, brightness)),
                  const SizedBox(width: 12),
                  const Text('Change Color'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'unpair',
              child: Row(
                children: [
                  const Icon(Icons.link_off, size: 20, color: AppColors.error),
                  const SizedBox(width: 12),
                  Text(
                    'Unpair',
                    style: TextStyle(color: AppColors.error),
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
