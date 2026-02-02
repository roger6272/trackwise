import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_util.dart';
import '../../../bluetooth/domain/entities/ble_device.dart';
import '../../../bluetooth/presentation/bloc/bluetooth_bloc.dart';
import '../../../bluetooth/presentation/bloc/bluetooth_event.dart';
import '../../../bluetooth/presentation/bloc/bluetooth_state.dart';
import '../../../bluetooth/presentation/widgets/ble_device_list_tile.dart';
import '../../../bluetooth/presentation/widgets/ble_status_banner.dart';
import '../../../bluetooth/presentation/widgets/blinking_widget.dart';

/// Step 3 of onboarding: scan for and connect to a BLE device.
///
/// Uses [BluetoothBloc] (provided higher in the widget tree) to manage
/// scanning, connection, and handshake. Calls [onPairingComplete] when
/// the device connects and initial sync finishes.
class OnboardingStepDevice extends StatefulWidget {
  final void Function({required bool paired, String? deviceName})
      onPairingComplete;
  final Widget? actions;

  const OnboardingStepDevice({
    super.key,
    required this.onPairingComplete,
    this.actions,
  });

  @override
  State<OnboardingStepDevice> createState() => _OnboardingStepDeviceState();
}

class _OnboardingStepDeviceState extends State<OnboardingStepDevice> {
  bool _hasAutoStartedScan = false;
  bool _pairingCompleted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BluetoothBloc>().add(const CheckBluetoothPermissions());
    });
  }

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

  void _completePairing(BluetoothState state) {
    if (_pairingCompleted) return;
    _pairingCompleted = true;
    widget.onPairingComplete(
      paired: true,
      deviceName: state.connectedDevice?.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BluetoothBloc, BluetoothState>(
      listener: (context, state) {
        _tryAutoStartScan(state);

        // Handle error
        if (state.status == BluetoothStatus.error &&
            state.errorMessage != null) {
          showErrorSnackBar(context, state.errorMessage!);
        }

        // Wrong account and sync conflict dialogs are handled globally
        // by BlocListeners in main.dart — no duplicate handling here.

        // Handle successful sync — pairing complete
        if (state.isConnected &&
            state.connectedDeviceInstanceId != null &&
            !state.needsSetup &&
            !_pairingCompleted) {
          _completePairing(state);
        }
      },
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Expanded(child: _buildContent(context, state)),
              if (widget.actions != null) widget.actions!,
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, BluetoothState state) {
    // Permissions not granted
    if (!state.permissionsGranted) {
      return _buildPermissionsView(context);
    }

    // Bluetooth off
    if (!state.bluetoothEnabled) {
      return _buildBluetoothDisabledView(context);
    }

    // Connecting
    if (state.isConnecting) {
      return _buildConnectingView(context, state);
    }

    // Connected and syncing (override in progress)
    if (state.isConnected && state.isOverriding) {
      return _buildSyncingView(context);
    }

    // Ready / scanning — show scan UI with device list
    return _buildScanView(context, state);
  }

  Widget _buildPermissionsView(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primaryText = AppColors.primaryText(brightness);

    return Column(
      children: [
        BleStatusBanner(
          message: 'Bluetooth permissions required',
          color: AppColors.warning,
          action: Semantics(
            label: 'Grant Bluetooth permissions',
            child: TextButton(
              onPressed: () {
                context
                    .read<BluetoothBloc>()
                    .add(const RequestBluetoothPermissions());
              },
              child:
                  const Text('Grant', style: TextStyle(color: Colors.white)),
            ),
          ),
        ),
        const Spacer(),
        Icon(Icons.bluetooth_disabled, size: 64, color: primaryText.withValues(alpha: 0.3)),
        const SizedBox(height: 16),
        Text(
          'Bluetooth permissions are needed to find your device.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: primaryText.withValues(alpha: 0.7),
              ),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildBluetoothDisabledView(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primaryText = AppColors.primaryText(brightness);

    return Column(
      children: [
        const BleStatusBanner(
          message: 'Bluetooth is disabled. Please enable it in settings.',
          color: AppColors.error,
        ),
        const Spacer(),
        Icon(Icons.bluetooth_disabled, size: 64, color: primaryText.withValues(alpha: 0.3)),
        const SizedBox(height: 16),
        Text(
          'Turn on Bluetooth to find nearby devices.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: primaryText.withValues(alpha: 0.7),
              ),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildConnectingView(BuildContext context, BluetoothState state) {
    final brightness = Theme.of(context).brightness;
    final primaryText = AppColors.primaryText(brightness);

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
            'Connecting...',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: primaryText,
                ),
          ),
          if (state.connectingDeviceId != null) ...[
            const SizedBox(height: 8),
            Text(
              'Device: ${state.connectingDeviceId}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: primaryText.withValues(alpha: 0.6),
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSyncingView(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primaryText = AppColors.primaryText(brightness);

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
            'Setting up device...',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: primaryText,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Transferring your data',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: primaryText.withValues(alpha: 0.6),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanView(BuildContext context, BluetoothState state) {
    final brightness = Theme.of(context).brightness;
    final primaryText = AppColors.primaryText(brightness);
    final canScan = state.permissionsGranted && state.bluetoothEnabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Text(
          'Find Your Device',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: primaryText,
                fontWeight: FontWeight.w600,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Make sure your Traxelos One is powered on and nearby',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: primaryText.withValues(alpha: 0.7),
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),

        // Scan button
        Semantics(
          label: state.isScanning ? 'Stop scanning' : 'Scan for devices',
          child: SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: canScan
                  ? () {
                      if (state.isScanning) {
                        context
                            .read<BluetoothBloc>()
                            .add(const StopScan());
                      } else {
                        context
                            .read<BluetoothBloc>()
                            .add(const StartScan());
                      }
                    }
                  : null,
              icon: state.isScanning
                  ? const BlinkingWidget(
                      child: Icon(Icons.bluetooth_searching))
                  : const Icon(Icons.bluetooth_searching),
              label: state.isScanning
                  ? const BlinkingWidget(child: Text('Scanning...'))
                  : const Text('Scan for Devices'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Device list or status
        Expanded(child: _buildDeviceList(context, state)),
      ],
    );
  }

  Widget _buildDeviceList(BuildContext context, BluetoothState state) {
    // Scanning with no devices yet
    if (state.isScanning && state.discoveredDevices.isEmpty) {
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
          ],
        ),
      );
    }

    // Not scanning and no devices
    if (!state.isScanning && state.discoveredDevices.isEmpty) {
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
              'No devices found',
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
      itemCount: sortedDevices.length,
      itemBuilder: (context, index) {
        final device = sortedDevices[index];
        return BleDeviceListTile(
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
