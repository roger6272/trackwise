import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../domain/entities/ble_device.dart';

/// Data model for BleDevice entity with flutter_blue_plus conversion.
///
/// Extends the domain BleDevice entity and adds factory methods for
/// converting from flutter_blue_plus types (ScanResult, BluetoothDevice).
class BleDeviceModel extends BleDevice {
  const BleDeviceModel({
    required super.id,
    required super.name,
    required super.rssi,
    super.isConnectable,
  });

  /// Creates a BleDeviceModel from a flutter_blue_plus ScanResult.
  ///
  /// Used when discovering devices during BLE scan.
  /// Extracts device info from the scan result including signal strength.
  factory BleDeviceModel.fromScanResult(ScanResult result) {
    return BleDeviceModel(
      id: result.device.remoteId.str,
      name: result.device.platformName.isNotEmpty
          ? result.device.platformName
          : 'Unknown Device',
      rssi: result.rssi,
      isConnectable: result.advertisementData.connectable,
    );
  }

  /// Creates a BleDeviceModel from a flutter_blue_plus BluetoothDevice.
  ///
  /// Used for already-connected devices where we don't have scan result.
  /// RSSI defaults to 0 since it's not available without scanning.
  factory BleDeviceModel.fromBluetoothDevice(BluetoothDevice device) {
    return BleDeviceModel(
      id: device.remoteId.str,
      name: device.platformName.isNotEmpty
          ? device.platformName
          : 'Unknown Device',
      rssi: 0, // Unknown for connected devices without recent scan
      isConnectable: true, // Assume connectable if we have the device object
    );
  }

  /// Creates a BleDeviceModel from a device ID string.
  ///
  /// Used when we only have the ID (e.g., from stored preferences).
  /// Name and RSSI will be unknown.
  factory BleDeviceModel.fromId(String deviceId) {
    return BleDeviceModel(
      id: deviceId,
      name: 'Unknown Device',
      rssi: 0,
      isConnectable: true,
    );
  }

  /// Converts this model to a domain entity.
  ///
  /// Since BleDeviceModel extends BleDevice, this is a simple cast.
  BleDevice toEntity() => this;
}
