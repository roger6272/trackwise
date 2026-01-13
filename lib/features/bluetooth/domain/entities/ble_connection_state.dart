/// Connection state for BLE devices.
///
/// Maps to FlutterBluePlus BluetoothConnectionState but decoupled
/// for domain layer purity.
enum BleConnectionState {
  /// Not connected to any device
  disconnected,

  /// Connection attempt in progress
  connecting,

  /// Successfully connected and ready for communication
  connected,

  /// Disconnection in progress
  disconnecting,
}
