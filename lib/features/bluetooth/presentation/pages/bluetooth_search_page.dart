import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_util.dart';
import '../../domain/entities/ble_device.dart';
import '../bloc/bluetooth_bloc.dart';
import '../bloc/bluetooth_event.dart';
import '../bloc/bluetooth_state.dart';
import '../widgets/ble_device_list_tile.dart';
import '../widgets/ble_status_banner.dart';
import '../widgets/blinking_widget.dart';

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
  bool _hasAutoStartedScan = false;
  /// Number of connected devices when page opened.
  /// Navigation only triggers when a NEW device connects beyond this count.
  late int _initialConnectedCount;

  @override
  void initState() {
    super.initState();
    _initialConnectedCount = context.read<BluetoothBloc>().state.connectedDevices.length;
    // Check permissions on page load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BluetoothBloc>().add(const CheckBluetoothPermissions());
    });
  }

  /// Auto-start scan if no prior search was done and permissions are ready.
  void _tryAutoStartScan(BluetoothState state) {
    if (_hasAutoStartedScan) return;
    if (state.discoveredDevices.isEmpty &&
        !state.isScanning &&
        state.permissionsGranted &&
        state.bluetoothEnabled) {
      _hasAutoStartedScan = true;
      context.read<BluetoothBloc>().add(const StartScan());
    }
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
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: primaryText,
            fontSize: 22.0,
          ),
        ),
        elevation: 0.0,
        leading: IconButton(
          tooltip: 'Back',
          icon: Icon(Icons.arrow_back, color: primaryText),
          onPressed: () => context.pop(),
        ),
      ),
      body: BlocConsumer<BluetoothBloc, BluetoothState>(
        listener: (context, state) {
          // Auto-start scan if ready and no prior search was done
          _tryAutoStartScan(state);

          // Navigate home only when a NEW device connects from this page
          if (state.connectedDevices.length > _initialConnectedCount) {
            context.go('/');
          }
          // Show error snackbar
          if (state.status == BluetoothStatus.error && state.errorMessage != null) {
            showErrorSnackBar(context, state.errorMessage!);
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
      return BleStatusBanner(
        message: 'Bluetooth permissions required',
        color: AppColors.warning,
        action: TextButton(
          onPressed: () {
            context.read<BluetoothBloc>().add(const RequestBluetoothPermissions());
          },
          child: const Text('Grant', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    if (!state.bluetoothEnabled) {
      return const BleStatusBanner(
        message: 'Bluetooth is disabled. Please enable it in settings.',
        color: AppColors.error,
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
              ? const BlinkingWidget(child: Icon(Icons.bluetooth_searching))
              : const Icon(Icons.bluetooth_searching),
          label: state.isScanning
              ? const BlinkingWidget(child: Text('Scanning...'))
              : const Text('Scan for Devices'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceList(BuildContext context, BluetoothState state) {
    // Hide already-paired devices from search results
    final pairedIds = state.pairedDevices.map((d) => d.deviceInstanceId).toSet();
    final unpaired = state.discoveredDevices.where((d) => !pairedIds.contains(d.id)).toList();

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
              '${unpaired.length} new device${unpaired.length == 1 ? '' : 's'} found',
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
    if (unpaired.isEmpty) {
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
              'No new devices found.\nTap "Scan" to search.',
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
    final sortedDevices = List<BleDevice>.from(unpaired)
      ..sort((a, b) => b.rssi.compareTo(a.rssi));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: sortedDevices.length,
      itemBuilder: (context, index) {
        final device = sortedDevices[index];
        return BleDeviceListTile(
          device: device,
          isConnecting: state.connectingDeviceId == device.id,
          onTap: state.isAtConnectionLimit
              ? null
              : () {
                  context.read<BluetoothBloc>().add(ConnectToDevice(device.id));
                },
        );
      },
    );
  }
}
