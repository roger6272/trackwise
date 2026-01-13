import 'package:equatable/equatable.dart';

/// Represents a discovered BLE device from scanning.
///
/// Domain layer entity - pure Dart with no Flutter/FlutterBluePlus dependencies.
class BleDevice extends Equatable {
  /// Unique device identifier (MAC address or platform-specific ID)
  final String id;

  /// Device display name (platformName from FlutterBluePlus)
  final String name;

  /// Signal strength in dBm (typically -30 to -90)
  /// Lower (more negative) = weaker signal
  final int rssi;

  /// Whether the device is connectable
  final bool isConnectable;

  const BleDevice({
    required this.id,
    required this.name,
    required this.rssi,
    this.isConnectable = true,
  });

  /// Creates a copy with the given fields replaced.
  BleDevice copyWith({
    String? id,
    String? name,
    int? rssi,
    bool? isConnectable,
  }) {
    return BleDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      rssi: rssi ?? this.rssi,
      isConnectable: isConnectable ?? this.isConnectable,
    );
  }

  @override
  List<Object?> get props => [id, name, rssi, isConnectable];

  @override
  String toString() {
    return 'BleDevice(id: $id, name: $name, rssi: $rssi, isConnectable: $isConnectable)';
  }
}
