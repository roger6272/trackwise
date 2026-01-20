import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/ble_device.dart';
import '../bloc/bluetooth_bloc.dart';
import '../bloc/bluetooth_event.dart';
import '../bloc/bluetooth_state.dart';

/// Page for scanning and discovering BLE devices.
///
/// Displays:
/// - Scan button to start/stop scanning
/// - List of discovered devices with signal strength
/// - Tap device to connect
class BluetoothSearchPage extends StatefulWidget {
  const BluetoothSearchPage({super.key});

  static const String routeName = 'BluetoothSearchPage';
  static const String routePath = '/bluetooth/search';

  @override
  State<BluetoothSearchPage> createState() => _BluetoothSearchPageState();
}

class _BluetoothSearchPageState extends State<BluetoothSearchPage> {
  @override
  void initState() {
    super.initState();
    // Check permissions and start scan on page load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BluetoothBloc>().add(const CheckBluetoothPermissions());
    });
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primaryBackground = AppColors.primaryBackground(brightness);
    final primaryText = AppColors.primaryText(brightness);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryBackground,
        title: Text(
          'Find Device',
          style: GoogleFonts.interTight(
            color: primaryText,
            fontWeight: FontWeight.w600,
            fontSize: 22.0,
          ),
        ),
        elevation: 0.0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primaryText),
          onPressed: () => context.pop(),
        ),
      ),
      body: BlocConsumer<BluetoothBloc, BluetoothState>(
        listener: (context, state) {
          // Navigate back when connected
          if (state.isConnected) {
            context.pop();
          }
          // Show error snackbar
          if (state.status == BluetoothStatus.error && state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          return Column(
            children: [
              _buildStatusBanner(context, state),
              _buildScanButton(context, state),
              Expanded(
                child: _buildDeviceList(context, state),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusBanner(BuildContext context, BluetoothState state) {
    if (!state.permissionsGranted) {
      return _StatusBanner(
        message: 'Bluetooth permissions required',
        color: Colors.orange,
        action: TextButton(
          onPressed: () {
            context.read<BluetoothBloc>().add(const RequestBluetoothPermissions());
          },
          child: const Text('Grant', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    if (!state.bluetoothEnabled) {
      return const _StatusBanner(
        message: 'Bluetooth is disabled. Please enable it in settings.',
        color: Colors.red,
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildScanButton(BuildContext context, BluetoothState state) {
    final canScan = state.permissionsGranted && state.bluetoothEnabled;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: canScan
              ? () {
                  if (state.isScanning) {
                    context.read<BluetoothBloc>().add(const StopScan());
                  } else {
                    context.read<BluetoothBloc>().add(const StartScan());
                  }
                }
              : null,
          icon: state.isScanning
              ? const _BlinkingWidget(child: Icon(Icons.bluetooth_searching))
              : const Icon(Icons.bluetooth_searching),
          label: state.isScanning
              ? const _BlinkingWidget(child: Text('Scanning...'))
              : const Text('Scan for Devices'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceList(BuildContext context, BluetoothState state) {
    // Show loading indicator while scanning
    if (state.isScanning) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(),
            ),
            const SizedBox(height: 24),
            Text(
              'Searching for devices...',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '${state.discoveredDevices.length} device${state.discoveredDevices.length == 1 ? '' : 's'} found',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
      );
    }

    // Show empty state when not scanning and no devices found
    if (state.discoveredDevices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bluetooth_disabled,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No devices found.\nTap "Scan" to search.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
      );
    }

    // Sort by signal strength (strongest first)
    final sortedDevices = List<BleDevice>.from(state.discoveredDevices)
      ..sort((a, b) => b.rssi.compareTo(a.rssi));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: sortedDevices.length,
      itemBuilder: (context, index) {
        final device = sortedDevices[index];
        return _DeviceListTile(
          device: device,
          isConnecting: state.connectingDeviceId == device.id,
          onTap: () {
            context.read<BluetoothBloc>().add(ConnectToDevice(device.id));
          },
        );
      },
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final String message;
  final Color color;
  final Widget? action;

  const _StatusBanner({
    required this.message,
    required this.color,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: color,
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white),
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class _DeviceListTile extends StatelessWidget {
  final BleDevice device;
  final bool isConnecting;
  final VoidCallback onTap;

  const _DeviceListTile({
    required this.device,
    required this.isConnecting,
    required this.onTap,
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
      color = Colors.green;
    } else if (device.rssi > -70) {
      icon = Icons.signal_cellular_alt;
      color = Colors.orange;
    } else {
      icon = Icons.signal_cellular_alt_1_bar;
      color = Colors.red;
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

class _BlinkingWidget extends StatefulWidget {
  final Widget child;

  const _BlinkingWidget({required this.child});

  @override
  State<_BlinkingWidget> createState() => _BlinkingWidgetState();
}

class _BlinkingWidgetState extends State<_BlinkingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 1.0, end: 0.3).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: widget.child,
        );
      },
    );
  }
}
