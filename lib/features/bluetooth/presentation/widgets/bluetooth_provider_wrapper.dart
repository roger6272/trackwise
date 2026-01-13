import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../bloc/bluetooth_bloc.dart';
import '../bloc/bluetooth_event.dart';
import '../bloc/bluetooth_state.dart';

/// Widget that provides BluetoothBloc to its descendants.
///
/// Wrap FlutterFlow pages or widgets that need Bluetooth functionality:
/// ```dart
/// BluetoothProviderWrapper(
///   child: MyFlutterFlowPage(),
/// )
/// ```
///
/// Access the bloc in child widgets using:
/// ```dart
/// final bloc = context.read<BluetoothBloc>();
/// // or
/// final state = context.watch<BluetoothBloc>().state;
/// ```
class BluetoothProviderWrapper extends StatelessWidget {
  final Widget child;

  /// If true, automatically requests permissions on mount.
  final bool requestPermissionsOnMount;

  /// If true, checks Bluetooth enabled state on mount.
  final bool checkBluetoothOnMount;

  const BluetoothProviderWrapper({
    super.key,
    required this.child,
    this.requestPermissionsOnMount = false,
    this.checkBluetoothOnMount = false,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider<BluetoothBloc>(
      create: (context) {
        final bloc = sl<BluetoothBloc>();

        if (requestPermissionsOnMount) {
          bloc.add(const RequestBluetoothPermissions());
        } else if (checkBluetoothOnMount) {
          bloc.add(const CheckBluetoothEnabled());
        }

        return bloc;
      },
      child: child,
    );
  }
}

/// Listener widget that reacts to Bluetooth state changes.
///
/// Use this to show snackbars, navigate, or perform other side effects:
/// ```dart
/// BluetoothStateListener(
///   onConnected: (device) => showSnackBar('Connected to ${device.name}'),
///   onDisconnected: () => showSnackBar('Disconnected'),
///   onError: (message) => showSnackBar('Error: $message'),
///   child: MyWidget(),
/// )
/// ```
class BluetoothStateListener extends StatelessWidget {
  final Widget child;
  final void Function(BluetoothState state)? onStateChanged;
  final void Function()? onConnected;
  final void Function()? onDisconnected;
  final void Function(String message)? onError;
  final void Function()? onPermissionsDenied;
  final void Function()? onBluetoothDisabled;

  const BluetoothStateListener({
    super.key,
    required this.child,
    this.onStateChanged,
    this.onConnected,
    this.onDisconnected,
    this.onError,
    this.onPermissionsDenied,
    this.onBluetoothDisabled,
  });

  @override
  Widget build(BuildContext context) {
    return BlocListener<BluetoothBloc, BluetoothState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        onStateChanged?.call(state);

        switch (state.status) {
          case BluetoothStatus.connected:
            onConnected?.call();
            break;
          case BluetoothStatus.ready:
            if (context.read<BluetoothBloc>().state.connectedDevice != null) {
              onDisconnected?.call();
            }
            break;
          case BluetoothStatus.error:
            onError?.call(state.errorMessage ?? 'Unknown error');
            break;
          case BluetoothStatus.permissionsDenied:
            onPermissionsDenied?.call();
            break;
          case BluetoothStatus.bluetoothDisabled:
            onBluetoothDisabled?.call();
            break;
          default:
            break;
        }
      },
      child: child,
    );
  }
}

/// Builder widget that rebuilds when Bluetooth status changes.
///
/// Use for status-specific UI:
/// ```dart
/// BluetoothStatusBuilder(
///   builder: (context, status, child) {
///     if (status == BluetoothStatus.connected) {
///       return ConnectedView();
///     }
///     return DisconnectedView();
///   },
/// )
/// ```
class BluetoothStatusBuilder extends StatelessWidget {
  final Widget Function(
    BuildContext context,
    BluetoothStatus status,
    Widget? child,
  ) builder;
  final Widget? child;

  const BluetoothStatusBuilder({
    super.key,
    required this.builder,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return BlocSelector<BluetoothBloc, BluetoothState, BluetoothStatus>(
      selector: (state) => state.status,
      builder: (context, status) => builder(context, status, child),
    );
  }
}

/// Builder widget for device list during scanning.
///
/// ```dart
/// BluetoothDeviceListBuilder(
///   builder: (context, devices, isScanning) {
///     if (isScanning && devices.isEmpty) {
///       return CircularProgressIndicator();
///     }
///     return ListView.builder(
///       itemCount: devices.length,
///       itemBuilder: (context, index) => DeviceTile(devices[index]),
///     );
///   },
/// )
/// ```
class BluetoothDeviceListBuilder extends StatelessWidget {
  final Widget Function(
    BuildContext context,
    List<dynamic> devices, // BleDevice list
    bool isScanning,
  ) builder;

  const BluetoothDeviceListBuilder({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BluetoothBloc, BluetoothState>(
      buildWhen: (previous, current) =>
          previous.discoveredDevices != current.discoveredDevices ||
          previous.isScanning != current.isScanning,
      builder: (context, state) {
        return builder(
          context,
          state.discoveredDevices,
          state.isScanning,
        );
      },
    );
  }
}

/// Builder widget for connection state.
///
/// ```dart
/// BluetoothConnectionBuilder(
///   builder: (context, isConnected, device) {
///     if (isConnected) {
///       return Text('Connected to ${device?.name}');
///     }
///     return Text('Not connected');
///   },
/// )
/// ```
class BluetoothConnectionBuilder extends StatelessWidget {
  final Widget Function(
    BuildContext context,
    bool isConnected,
    dynamic connectedDevice, // BleDevice?
  ) builder;

  const BluetoothConnectionBuilder({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BluetoothBloc, BluetoothState>(
      buildWhen: (previous, current) =>
          previous.isConnected != current.isConnected ||
          previous.connectedDevice != current.connectedDevice,
      builder: (context, state) {
        return builder(
          context,
          state.isConnected,
          state.connectedDevice,
        );
      },
    );
  }
}

/// Extension methods for easy Bluetooth operations in widgets.
extension BluetoothBlocContextExtension on BuildContext {
  /// Gets the BluetoothBloc from context.
  BluetoothBloc get bluetoothBloc => read<BluetoothBloc>();

  /// Starts scanning for devices.
  void startBluetoothScan({Duration? timeout}) {
    bluetoothBloc.add(StartScan(timeout: timeout ?? const Duration(seconds: 10)));
  }

  /// Stops scanning.
  void stopBluetoothScan() {
    bluetoothBloc.add(const StopScan());
  }

  /// Connects to a device by ID.
  void connectToBluetoothDevice(String deviceId) {
    bluetoothBloc.add(ConnectToDevice(deviceId));
  }

  /// Disconnects from the currently connected device.
  /// Note: deviceId is kept for API compatibility but not used.
  void disconnectFromBluetoothDevice(String deviceId) {
    bluetoothBloc.add(const DisconnectFromDevice());
  }

  /// Gets current Bluetooth connection status.
  bool get isBluetoothConnected => bluetoothBloc.state.isConnected;

  /// Gets current Bluetooth scanning status.
  bool get isBluetoothScanning => bluetoothBloc.state.isScanning;
}
