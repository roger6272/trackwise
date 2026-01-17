import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../items/presentation/bloc/items_bloc.dart';
import '../../../items/presentation/bloc/items_state.dart';
import '../bloc/bluetooth_bloc.dart';
import '../bloc/bluetooth_event.dart';
import '../bloc/bluetooth_state.dart';

/// Page for managing a connected BLE device.
///
/// Displays:
/// - Connected device info (name, signal)
/// - Sync items button
/// - Sync time button
/// - Disconnect button
class DeviceManagementPage extends StatelessWidget {
  const DeviceManagementPage({super.key});

  static const String routeName = 'DeviceManagementPage';
  static const String routePath = '/bluetooth/device';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Manager'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: BlocBuilder<BluetoothBloc, BluetoothState>(
        builder: (context, state) {
          if (!state.isConnected || state.connectedDevice == null) {
            return const Center(
              child: Text('No device connected'),
            );
          }

          final device = state.connectedDevice!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DeviceInfoCard(
                  deviceName: device.name,
                  deviceId: device.id,
                  rssi: device.rssi,
                ),
                const SizedBox(height: 24),
                _ActionSection(
                  title: 'Sync',
                  children: [
                    _ActionButton(
                      icon: Icons.sync,
                      label: 'Sync Items',
                      description: 'Send item list to device',
                      onPressed: () => _syncItems(context),
                    ),
                    const SizedBox(height: 12),
                    _ActionButton(
                      icon: Icons.access_time,
                      label: 'Sync Time',
                      description: 'Sync device clock',
                      onPressed: () {
                        context.read<BluetoothBloc>().add(const SendTimeSync());
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Time synced')),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _ActionSection(
                  title: 'Connection',
                  children: [
                    _ActionButton(
                      icon: Icons.bluetooth_disabled,
                      label: 'Disconnect',
                      description: 'Disconnect from device',
                      color: Colors.red,
                      onPressed: () {
                        context.read<BluetoothBloc>().add(const DisconnectFromDevice());
                        context.pop();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _ActionSection(
                  title: 'Debug',
                  children: [
                    _ActionButton(
                      icon: Icons.bug_report,
                      label: 'Test Page',
                      description: 'Open BLE debug/test page',
                      color: Colors.orange,
                      onPressed: () {
                        context.pushNamed('BluetoothTestPage');
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _LastMessageCard(state: state),
              ],
            ),
          );
        },
      ),
    );
  }

  void _syncItems(BuildContext context) {
    final itemsState = context.read<ItemsBloc>().state;
    if (itemsState is ItemsLoaded) {
      context.read<BluetoothBloc>().add(SendItemsToDevice(itemsState.items));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Synced ${itemsState.items.length} items')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No items to sync')),
      );
    }
  }
}

class _DeviceInfoCard extends StatelessWidget {
  final String deviceName;
  final String deviceId;
  final int rssi;

  const _DeviceInfoCard({
    required this.deviceName,
    required this.deviceId,
    required this.rssi,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.bluetooth_connected,
                size: 48,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              deviceName.isNotEmpty ? deviceName : 'ESP32 Device',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              deviceId,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.signal_cellular_alt, size: 16, color: Colors.green),
                const SizedBox(width: 4),
                Text(
                  'Connected • $rssi dBm',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.green,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _ActionSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        ...children,
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final Color? color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.description,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final buttonColor = color ?? Theme.of(context).colorScheme.primary;

    return Card(
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: buttonColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: buttonColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LastMessageCard extends StatelessWidget {
  final BluetoothState state;

  const _LastMessageCard({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.lastMessage == null) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Last Message',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              state.lastMessage!.type.toString(),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
