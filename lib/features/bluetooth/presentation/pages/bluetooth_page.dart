import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../bloc/bluetooth_bloc.dart';
import '../bloc/bluetooth_event.dart';
import '../bloc/bluetooth_state.dart';
import 'bluetooth_search_page.dart';
import 'device_management_page.dart';

/// Main Bluetooth page - entry point for Bluetooth functionality.
///
/// Shows:
/// - Connection status overview
/// - Quick actions based on current state
/// - Navigate to search or device management
class BluetoothPage extends StatefulWidget {
  const BluetoothPage({super.key});

  static const String routeName = 'BluetoothPage';
  static const String routePath = '/bluetooth';

  @override
  State<BluetoothPage> createState() => _BluetoothPageState();
}

class _BluetoothPageState extends State<BluetoothPage> {
  @override
  void initState() {
    super.initState();
    // Check permissions on page load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BluetoothBloc>().add(const CheckBluetoothPermissions());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth'),
        automaticallyImplyLeading: false,
      ),
      body: BlocBuilder<BluetoothBloc, BluetoothState>(
        builder: (context, state) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StatusCard(state: state),
                const SizedBox(height: 24),
                _buildActionButtons(context, state),
                const SizedBox(height: 24),
                _buildInfoSection(context, state),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, BluetoothState state) {
    if (state.isConnected) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            onPressed: () => context.push(DeviceManagementPage.routePath),
            icon: const Icon(Icons.settings),
            label: const Text('Manage Device'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              context.read<BluetoothBloc>().add(const DisconnectFromDevice());
            },
            icon: const Icon(Icons.bluetooth_disabled),
            label: const Text('Disconnect'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              foregroundColor: Colors.red,
            ),
          ),
        ],
      );
    }

    if (state.isConnecting) {
      return ElevatedButton.icon(
        onPressed: null,
        icon: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        label: const Text('Connecting...'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      );
    }

    // Not connected
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: state.permissionsGranted && state.bluetoothEnabled
              ? () => context.push(BluetoothSearchPage.routePath)
              : null,
          icon: const Icon(Icons.bluetooth_searching),
          label: const Text('Find Device'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        if (!state.permissionsGranted) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              context.read<BluetoothBloc>().add(const RequestBluetoothPermissions());
            },
            icon: const Icon(Icons.security),
            label: const Text('Grant Permissions'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoSection(BuildContext context, BluetoothState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'About ESP32 Connection',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.bluetooth,
              label: 'Bluetooth',
              value: state.bluetoothEnabled ? 'Enabled' : 'Disabled',
              valueColor: state.bluetoothEnabled ? Colors.green : Colors.red,
            ),
            const Divider(height: 24),
            _InfoRow(
              icon: Icons.security,
              label: 'Permissions',
              value: state.permissionsGranted ? 'Granted' : 'Required',
              valueColor: state.permissionsGranted ? Colors.green : Colors.orange,
            ),
            const Divider(height: 24),
            _InfoRow(
              icon: Icons.devices,
              label: 'Device',
              value: state.connectedDevice?.name ?? 'Not connected',
              valueColor: state.isConnected ? Colors.green : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final BluetoothState state;

  const _StatusCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final (icon, color, title, subtitle) = _getStatusInfo();

    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: color),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  (IconData, Color, String, String) _getStatusInfo() {
    if (state.isConnected) {
      return (
        Icons.bluetooth_connected,
        Colors.green,
        'Connected',
        'Connected to ${state.connectedDevice?.name ?? "device"}',
      );
    }

    if (state.isConnecting) {
      return (
        Icons.bluetooth_searching,
        Colors.orange,
        'Connecting',
        'Establishing connection...',
      );
    }

    if (!state.permissionsGranted) {
      return (
        Icons.security,
        Colors.orange,
        'Permissions Required',
        'Grant Bluetooth permissions to connect',
      );
    }

    if (!state.bluetoothEnabled) {
      return (
        Icons.bluetooth_disabled,
        Colors.red,
        'Bluetooth Disabled',
        'Enable Bluetooth in settings',
      );
    }

    return (
      Icons.bluetooth,
      Colors.blue,
      'Ready to Connect',
      'Search for your ESP32 device',
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.outline),
        const SizedBox(width: 12),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const Spacer(),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: valueColor,
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }
}
