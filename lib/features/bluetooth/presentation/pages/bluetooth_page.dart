import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_util.dart';
import '../../../../core/utils/bluetooth_constants.dart';
import '../../domain/entities/paired_device.dart';
import '../bloc/bluetooth_bloc.dart';
import '../bloc/bluetooth_event.dart';
import '../bloc/bluetooth_state.dart';
import '../bloc/device_connection_state.dart';
import '../widgets/device_color_picker_dialog.dart';
import '../../../ota/presentation/bloc/ota_bloc.dart';
import '../../../ota/presentation/bloc/ota_event.dart' as ota_events;
import '../../../ota/presentation/bloc/ota_state.dart';
import '../../../ota/presentation/widgets/update_banner.dart';
import 'bluetooth_search_page.dart';

/// Main Bluetooth page — unified device management.
///
/// Shows:
/// - Summary bar (connected count, BT/permissions status)
/// - Paired device list with connect/disconnect/rename/color/unpair
/// - FAB to search for new devices
/// - Empty state when no devices are paired
class BluetoothPage extends StatefulWidget {
  const BluetoothPage({super.key});

  static const String routeName = 'BluetoothPage';
  static const String routePath = '/bluetooth';

  @override
  State<BluetoothPage> createState() => _BluetoothPageState();
}

class _BluetoothPageState extends State<BluetoothPage> {
  /// The deviceInstanceId we're connecting to from this page (null if not connecting).
  String? _connectingDeviceId;

  /// Tracks which device IDs have already triggered an OTA check this session.
  final Set<String> _otaCheckedDevices = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bloc = context.read<BluetoothBloc>();
      bloc.add(const CheckBluetoothPermissions());
      bloc.add(const LoadPairedDevices());
    });
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primaryBackground = AppColors.primaryBackground(brightness);
    final primaryText = AppColors.primaryText(brightness);

    return BlocListener<OtaBloc, OtaBlocState>(
      listener: (context, otaState) {
        // When OTA enters rebooting state, tell BluetoothBloc to expect the disconnect
        if (otaState is OtaBlocRebooting) {
          final btState = context.read<BluetoothBloc>().state;
          for (final deviceId in btState.connectedDevices.keys) {
            context.read<BluetoothBloc>().add(
              SetOtaRebootFlag(deviceInstanceId: deviceId, awaiting: true),
            );
          }
        }
      },
      child: BlocConsumer<BluetoothBloc, BluetoothState>(
      listener: (context, state) {
        // Connection success feedback
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

        // Trigger OTA update check when a device's firmware version becomes available
        for (final entry in state.connectedDevices.entries) {
          final deviceState = entry.value;
          if (deviceState.firmwareVersion != null &&
              deviceState.syncStatus == DeviceSyncStatus.synced &&
              !_otaCheckedDevices.contains(entry.key)) {
            _otaCheckedDevices.add(entry.key);
            // Check if this device just completed an OTA reboot
            final bluetoothBloc = context.read<BluetoothBloc>();
            if (bluetoothBloc.isAwaitingOtaReboot(entry.key)) {
              // Post-reboot reconnection: notify OtaBloc and clear the flag
              context.read<OtaBloc>().add(
                ota_events.OtaRebootCompleted(deviceState.firmwareVersion!),
              );
              bluetoothBloc.add(
                SetOtaRebootFlag(deviceInstanceId: entry.key, awaiting: false),
              );
            } else {
              context.read<OtaBloc>().add(
                    ota_events.CheckForUpdateRequested(deviceState.firmwareVersion!),
                  );
            }
            break; // Check for first connected device only
          }
        }
        // Clean up OTA check tracking for disconnected devices
        _otaCheckedDevices.removeWhere(
            (id) => !state.connectedDevices.containsKey(id));
      },
      builder: (context, state) {
        final devices = state.pairedDevices;
        final canSearch = state.permissionsGranted && state.bluetoothEnabled;

        return Scaffold(
          backgroundColor: primaryBackground,
          appBar: AppBar(
            backgroundColor: primaryBackground,
            foregroundColor: primaryText,
            title: Text(
              'Bluetooth',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: primaryText,
                    fontSize: 22.0,
                  ),
            ),
            automaticallyImplyLeading: false,
            elevation: 0.0,
            actions: devices.isNotEmpty
                ? [
                    Semantics(
                      label: 'Search for devices',
                      child: IconButton(
                        onPressed: canSearch
                            ? () =>
                                context.push(BluetoothSearchPage.routePath)
                            : null,
                        icon: const Icon(Icons.bluetooth_searching),
                        tooltip: 'Find Device',
                      ),
                    ),
                  ]
                : null,
          ),
          body: devices.isEmpty
              ? _buildEmptyState(context, state)
              : _buildDeviceList(context, state),
        );
      },
    ),
    );
  }

  Widget _buildDeviceList(BuildContext context, BluetoothState state) {
    final devices = state.pairedDevices;

    return Column(
      children: [
        // Status banners
        _buildBanners(context, state),
        // Summary bar
        _SummaryBar(state: state),
        // Device list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 4.0, bottom: 80.0),
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final device = devices[index];
              final isConnected =
                  state.connectedDevices.containsKey(device.deviceInstanceId);
              final isConnecting =
                  state.connectingDeviceId == device.deviceInstanceId;

              final deviceState = state.connectedDevices[device.deviceInstanceId];

              return _DeviceListTile(
                device: device,
                isConnected: isConnected,
                isConnecting: isConnecting,
                isAtConnectionLimit: state.isAtConnectionLimit,
                batteryLevel: deviceState?.batteryLevel,
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
                  context.read<BluetoothBloc>().add(
                        DisconnectFromDevice(
                            deviceInstanceId: device.deviceInstanceId),
                      );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBanners(BuildContext context, BluetoothState state) {
    final banners = <Widget>[];

    if (!state.bluetoothEnabled) {
      banners.add(_StatusBanner(
        message: 'Bluetooth is disabled',
        color: AppColors.error,
        icon: Icons.bluetooth_disabled,
      ));
    }

    if (!state.permissionsGranted) {
      banners.add(_StatusBanner(
        message: 'Bluetooth permissions required',
        color: AppColors.warning,
        icon: Icons.security,
        actionLabel: 'Grant',
        onAction: () {
          context
              .read<BluetoothBloc>()
              .add(const RequestBluetoothPermissions());
        },
      ));
    }

    // OTA update banner (shown when a connected device has a firmware update available)
    if (state.isConnected) {
      // Use the actual negotiated MTU from the first connected device
      final firstDeviceState = state.connectedDevices.values.firstOrNull;
      final mtu = firstDeviceState?.negotiatedMtu ?? BluetoothConstants.defaultMtuLimit;
      banners.add(UpdateBanner(
        negotiatedMtu: mtu,
      ));
    }

    if (banners.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(children: banners),
    );
  }

  Widget _buildEmptyState(BuildContext context, BluetoothState state) {
    final brightness = Theme.of(context).brightness;
    final secondaryText = AppColors.secondaryText(brightness);
    final canSearch = state.permissionsGranted && state.bluetoothEnabled;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Banners at top even in empty state
            if (!state.bluetoothEnabled || !state.permissionsGranted) ...[
              _buildBanners(context, state),
              const SizedBox(height: 32),
            ],
            Icon(
              Icons.watch_outlined,
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
              'Search for a Traxelos device to pair it with your account.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: secondaryText.withValues(alpha: 0.7),
                  ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: canSearch
                  ? () => context.push(BluetoothSearchPage.routePath)
                  : null,
              icon: const Icon(Icons.bluetooth_searching),
              label: const Text('Find Device'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
            ),
            if (!state.permissionsGranted) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  context
                      .read<BluetoothBloc>()
                      .add(const RequestBluetoothPermissions());
                },
                icon: const Icon(Icons.security),
                label: const Text('Grant Permissions'),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ========== Dialogs (from paired_devices_page) ==========

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
            child: const Text(
              'Save',
              style: TextStyle(color: Colors.white),
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
                      style:
                          Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
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
            child: const Text(
              'Remove from List',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// ========== Summary Bar ==========

class _SummaryBar extends StatelessWidget {
  final BluetoothState state;

  const _SummaryBar({required this.state});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final secondaryText = AppColors.secondaryText(brightness);
    final connected = state.connectedDevices.length;
    final total = state.pairedDevices.length;

    final atLimit = state.isAtConnectionLimit;
    final statusText = connected > 0
        ? '$connected of $total connected${atLimit ? ' (max)' : ''}'
        : 'No devices connected';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Icon(
            connected > 0
                ? Icons.bluetooth_connected
                : Icons.bluetooth,
            size: 20,
            color: connected > 0 ? AppColors.success : secondaryText,
          ),
          const SizedBox(width: 8),
          Text(
            statusText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: connected > 0 ? AppColors.success : secondaryText,
                  fontWeight: FontWeight.w500,
                ),
          ),
          const Spacer(),
          // Bluetooth status dot
          Semantics(
            label: state.bluetoothEnabled
                ? 'Bluetooth enabled'
                : 'Bluetooth disabled',
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: state.bluetoothEnabled ? AppColors.success : AppColors.error,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Permissions status dot
          Semantics(
            label: state.permissionsGranted
                ? 'Permissions granted'
                : 'Permissions required',
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: state.permissionsGranted
                    ? AppColors.success
                    : AppColors.warning,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ========== Status Banner ==========

class _StatusBanner extends StatelessWidget {
  final String message;
  final Color color;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _StatusBanner({
    required this.message,
    required this.color,
    required this.icon,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: color,
                minimumSize: Size.zero,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

// ========== Device List Tile ==========

class _DeviceListTile extends StatelessWidget {
  final PairedDevice device;
  final bool isConnected;
  final bool isConnecting;
  final bool isAtConnectionLimit;
  final int? batteryLevel;
  final VoidCallback onRename;
  final VoidCallback onChangeColor;
  final VoidCallback onUnpair;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  const _DeviceListTile({
    required this.device,
    required this.isConnected,
    this.isConnecting = false,
    this.isAtConnectionLimit = false,
    this.batteryLevel,
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
            ? Border.all(
                color: AppColors.success.withValues(alpha: 0.5), width: 1.5)
            : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 8.0,
        ),
        onTap: (!isConnected && !isConnecting && !isAtConnectionLimit) ? onConnect : null,
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.deviceColor(device.color, brightness).withValues(alpha: 0.2),
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
              : Center(
                  child: Icon(
                    Icons.watch,
                    color: AppColors.deviceColor(device.color, brightness),
                    size: 28,
                  ),
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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Battery level indicator
            _BatteryIndicator(
              level: batteryLevel,
              isConnected: isConnected,
            ),
            PopupMenuButton<String>(
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
                enabled: !isAtConnectionLimit,
                child: Row(
                  children: [
                    Icon(Icons.bluetooth_connected,
                        size: 20,
                        color: isAtConnectionLimit
                            ? AppColors.secondaryText(Theme.of(context).brightness)
                            : AppColors.primary),
                    const SizedBox(width: 12),
                    Text(
                      'Connect',
                      style: TextStyle(
                          color: isAtConnectionLimit
                              ? AppColors.secondaryText(Theme.of(context).brightness)
                              : AppColors.primary),
                    ),
                  ],
                ),
              ),
            if (isConnected)
              PopupMenuItem(
                value: 'disconnect',
                child: Row(
                  children: [
                    Icon(Icons.bluetooth_disabled,
                        size: 20, color: AppColors.error),
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
                  Icon(Icons.palette_outlined,
                      size: 20,
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

// ========== Battery Indicator ==========

class _BatteryIndicator extends StatelessWidget {
  final int? level;
  final bool isConnected;

  const _BatteryIndicator({
    this.level,
    required this.isConnected,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final secondaryText = AppColors.secondaryText(brightness);

    // Show unknown state when not connected or no battery data
    if (!isConnected || level == null) {
      return Semantics(
        label: 'Battery level unknown',
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.battery_unknown,
              size: 20,
              color: secondaryText.withValues(alpha: 0.4),
            ),
            Text(
              '--%',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: secondaryText.withValues(alpha: 0.4),
                    fontSize: 10.0,
                  ),
            ),
          ],
        ),
      );
    }

    final batteryLevel = level!;
    final icon = _batteryIcon(batteryLevel);
    final color = _batteryColor(batteryLevel);

    return Semantics(
      label: 'Battery level $batteryLevel percent',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 20,
            color: color,
          ),
          Text(
            '$batteryLevel%',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontSize: 10.0,
                ),
          ),
        ],
      ),
    );
  }

  IconData _batteryIcon(int level) {
    if (level > 75) return Icons.battery_full;
    if (level > 25) return Icons.battery_3_bar;
    if (level > 10) return Icons.battery_1_bar;
    return Icons.battery_alert;
  }

  Color _batteryColor(int level) {
    if (level > 25) return AppColors.success;
    if (level > 10) return AppColors.warning;
    return AppColors.error;
  }
}
