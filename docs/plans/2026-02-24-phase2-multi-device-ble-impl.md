# Phase 2: Multi-Device BLE & Claim Logic — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Refactor the single-device BLE architecture to support multiple simultaneous device connections with exclusive item claiming.

**Architecture:** Extract per-device state from singleton datasource into `DeviceConnection` objects (2a), refactor BLoC state from singular fields to a `connectedDevices` map (2b), enable concurrent connections with fire-and-forget handshakes (2c), and add Firestore claim transactions with claim-filtered pushes (2d). Sub-phases 2a and 2b are pure refactors with no behavior change.

**Tech Stack:** Flutter BLoC, flutter_blue_plus, Cloud Firestore transactions, mocktail

**Design Doc:** `docs/plans/2026-02-24-phase2-multi-device-ble-design.md`

---

## Sub-Phase 2a: Datasource Refactor (no behavior change)

The `_connections` map starts with 0-or-1 entries — single-device behavior preserved.

### Task 1: Create DeviceConnection class

**Files:**
- Create: `lib/features/bluetooth/data/datasources/device_connection.dart`
- Test: `test/features/bluetooth/data/datasources/device_connection_test.dart`

**Context:** Currently, `BluetoothDataSourceImpl` holds 11 per-device fields as instance vars (lines 29-65). We extract these into a class so each connected device gets its own lifecycle.

**Step 1: Write the failing test**

```dart
// test/features/bluetooth/data/datasources/device_connection_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:traxelos/features/bluetooth/data/datasources/device_connection.dart';

void main() {
  group('DeviceConnection', () {
    test('should be created with deviceInstanceId', () {
      final conn = DeviceConnection(deviceInstanceId: 'dev_abc');
      expect(conn.deviceInstanceId, 'dev_abc');
      expect(conn.negotiatedMtu, 180); // BluetoothConstants.defaultMtuLimit
      expect(conn.isProcessingWrite, false);
    });

    test('dispose should cancel subscriptions and close controller', () async {
      final conn = DeviceConnection(deviceInstanceId: 'dev_abc');
      // Should not throw
      await conn.dispose();
      expect(conn.messageController.isClosed, true);
    });

    test('clearConnectionState should reset all fields', () {
      final conn = DeviceConnection(deviceInstanceId: 'dev_abc');
      conn.negotiatedMtu = 512;
      conn.clearConnectionState();
      expect(conn.negotiatedMtu, 180);
      expect(conn.readChar, isNull);
      expect(conn.notifyChar, isNull);
      expect(conn.setItemsChar, isNull);
      expect(conn.writeChar, isNull);
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/features/bluetooth/data/datasources/device_connection_test.dart`
Expected: FAIL (file doesn't exist yet)

**Step 3: Write DeviceConnection class**

```dart
// lib/features/bluetooth/data/datasources/device_connection.dart
import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../../../core/utils/bluetooth_constants.dart';
import '../../domain/entities/ble_message.dart';

/// Encapsulates all per-device BLE state for a single connection.
///
/// Created by BluetoothDataSourceImpl.connect(), disposed on disconnect.
/// Each connected device gets its own DeviceConnection instance.
class DeviceConnection {
  final String deviceInstanceId;

  // The underlying BLE device handle
  BluetoothDevice? device;

  // Cached characteristics (discovered on connect)
  BluetoothCharacteristic? readChar;
  BluetoothCharacteristic? notifyChar;
  BluetoothCharacteristic? setItemsChar;
  BluetoothCharacteristic? writeChar;

  // Connection
  int negotiatedMtu = BluetoothConstants.defaultMtuLimit;
  StreamSubscription<BluetoothConnectionState>? connectionSubscription;

  // Message assembly
  StreamSubscription<List<int>>? notifySubscription;
  final messageController = StreamController<BleMessage>.broadcast();
  final messageBuffer = StringBuffer();
  Timer? messageTimeoutTimer;

  // Write serialization (per-device queue)
  final writeQueue = <WriteOperation>[];
  bool isProcessingWrite = false;

  DeviceConnection({required this.deviceInstanceId});

  /// Clears cached characteristics and resets MTU.
  void clearConnectionState() {
    readChar = null;
    notifyChar = null;
    setItemsChar = null;
    writeChar = null;
    negotiatedMtu = BluetoothConstants.defaultMtuLimit;
    notifySubscription?.cancel();
    notifySubscription = null;
    messageBuffer.clear();
    messageTimeoutTimer?.cancel();
    messageTimeoutTimer = null;
  }

  /// Releases all resources for this connection.
  Future<void> dispose() async {
    connectionSubscription?.cancel();
    connectionSubscription = null;
    notifySubscription?.cancel();
    notifySubscription = null;
    messageTimeoutTimer?.cancel();
    messageTimeoutTimer = null;
    messageBuffer.clear();
    writeQueue.clear();
    if (!messageController.isClosed) {
      await messageController.close();
    }
  }
}

/// A queued write operation for BLE serialization.
class WriteOperation {
  final BluetoothCharacteristic characteristic;
  final String data;
  final Completer<void> completer;

  WriteOperation({
    required this.characteristic,
    required this.data,
    required this.completer,
  });
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/features/bluetooth/data/datasources/device_connection_test.dart`
Expected: PASS (3 tests)

**Step 5: Commit**

```bash
git add lib/features/bluetooth/data/datasources/device_connection.dart test/features/bluetooth/data/datasources/device_connection_test.dart
git commit -m "feat(ble): add DeviceConnection class for per-device state"
```

---

### Task 2: Refactor BluetoothDataSourceImpl to use DeviceConnection

**Files:**
- Modify: `lib/features/bluetooth/data/datasources/bluetooth_datasource_impl.dart`
- Modify: `lib/features/bluetooth/data/datasources/device_connection.dart` (if needed)

**Context:** Replace the 11 per-device instance fields (lines 29-65) with a `_connections` map. The `_WriteOperation` private class (used by write queue) must move to `device_connection.dart` as the public `WriteOperation`. All methods that touch per-device state must look up the connection by deviceId.

**Step 1: Replace instance fields with connections map**

In `bluetooth_datasource_impl.dart`:

1. Remove these instance fields (lines 29-65):
   - `_connectedDevice`, `_connectedDeviceModel`
   - `_readChar`, `_notifyChar`, `_setItemsChar`, `_writeChar`
   - `_negotiatedMtu`
   - `_notifySubscription`, `_messageController`, `_messageBuffer`, `_messageTimeoutTimer`
   - `_connectionSubscription`
   - `_writeQueue`, `_isProcessingWrite`

2. Keep the `_connectionStateController` (global — emits tuples later, for now still emits singular state).

3. Add:
   ```dart
   final Map<String, DeviceConnection> _connections = {};

   /// Global message controller — broadcasts messages from ALL connections.
   /// BLoC subscribes once and routes by deviceInstanceId.
   final _messageController = StreamController<BleMessage>.broadcast();
   ```

4. Add a helper:
   ```dart
   /// Gets the single active connection (Phase 2a: 0 or 1 entry).
   /// Throws if no connection exists.
   DeviceConnection get _activeConnection {
     if (_connections.isEmpty) {
       throw StateError('No active BLE connection');
     }
     return _connections.values.first;
   }
   ```

**Step 2: Refactor connect() (line ~157)**

Current connect() stores fields directly. Refactor to:
1. Create `DeviceConnection(deviceInstanceId: deviceId)` — note: in 2a we use BLE deviceId as placeholder since we don't have deviceInstanceId yet from handshake. The connection will be re-keyed after handshake in 2c.
2. Store device, characteristics, MTU, subscriptions on the `DeviceConnection`.
3. Add to `_connections` map.
4. Keep the `_connectedDeviceModel` getter working via the connection.

**Step 3: Refactor disconnect() (line ~279)**

1. Look up connection by deviceId in `_connections`.
2. Call `connection.dispose()`.
3. Remove from map.
4. Update `connectedDevice` getter to return null.

**Step 4: Refactor data methods**

Each method that uses per-device fields must go through the connection:
- `discoverServices()` — store chars on connection
- `_ensureCharacteristicsCached()` — check connection's chars
- `_subscribeToNotifications()` — use connection's notifyChar, store subscription on connection
- `_handleNotificationData()` — use connection's messageBuffer, forward to global `_messageController`
- `writeItems()` / `writeCommand()` — use connection's characteristic + write queue
- `_enqueueWrite()` / `_processWriteQueue()` — use connection's writeQueue
- `watchNotifications()` — return global `_messageController.stream`
- `readData()` / `rediscoverAndReadData()` / `prepareReadCycle()` — use connection's chars
- `_clearConnectionState()` — call `connection.clearConnectionState()`

**Step 5: Remove the private `_WriteOperation` class**

Replace all references to `_WriteOperation` with the public `WriteOperation` from `device_connection.dart`.

**Step 6: Update `connectedDevice` getter**

```dart
@override
BleDeviceModel? get connectedDevice {
  if (_connections.isEmpty) return null;
  final conn = _connections.values.first;
  return conn.device != null ? BleDeviceModel.fromBluetoothDevice(conn.device!) : null;
}
```

**Step 7: Run full test suite to verify no behavior change**

Run: `flutter test`
Expected: All ~782 tests pass (1 pre-existing skip)

Run: `flutter build apk --debug`
Expected: BUILD SUCCESSFUL

**Step 8: Commit**

```bash
git add lib/features/bluetooth/data/datasources/bluetooth_datasource_impl.dart lib/features/bluetooth/data/datasources/device_connection.dart
git commit -m "refactor(ble): use DeviceConnection map in datasource (no behavior change)"
```

---

### Task 3: Update abstract interface and repository

**Files:**
- Modify: `lib/features/bluetooth/data/datasources/bluetooth_datasource.dart`
- Modify: `lib/features/bluetooth/data/repositories/bluetooth_repository_impl.dart`
- Modify: `lib/features/bluetooth/domain/repositories/bluetooth_repository.dart` (abstract)

**Context:** The abstract `BluetoothDataSource` interface (line 13) needs method signatures to accept deviceInstanceId where needed (Phase 2c will use them; 2a just adds the parameter with default routing to single connection). The repository passes through.

**Step 1: Add `getConnection()` to abstract datasource**

```dart
/// Gets a DeviceConnection by instance ID (null if not found).
DeviceConnection? getConnection(String deviceInstanceId);
```

**Step 2: Update `watchConnectionState` return type**

For now, keep the existing return type. In Phase 2c, this will change to emit `(String, BleConnectionState)` tuples. Adding the parameter signature now avoids a second interface change.

**Step 3: Run full test suite**

Run: `flutter test && flutter build apk --debug`
Expected: All tests pass, build succeeds

**Step 4: Commit**

```bash
git add lib/features/bluetooth/data/datasources/bluetooth_datasource.dart lib/features/bluetooth/data/datasources/bluetooth_datasource_impl.dart lib/features/bluetooth/data/repositories/bluetooth_repository_impl.dart lib/features/bluetooth/domain/repositories/bluetooth_repository.dart
git commit -m "refactor(ble): add getConnection to datasource interface"
```

---

## Sub-Phase 2b: BLoC State Refactor (no behavior change)

State splits into global fields (adapter-level) and per-device fields (new `DeviceConnectionState`). The `connectedDevices` map has 0-or-1 entries in 2b — single-device behavior preserved.

### Task 4: Create DeviceConnectionState and DeviceSyncStatus

**Files:**
- Create: `lib/features/bluetooth/presentation/bloc/device_connection_state.dart`
- Test: `test/features/bluetooth/presentation/bloc/device_connection_state_test.dart`

**Step 1: Write the failing test**

```dart
// test/features/bluetooth/presentation/bloc/device_connection_state_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:traxelos/features/bluetooth/domain/entities/ble_device.dart';
import 'package:traxelos/features/bluetooth/presentation/bloc/device_connection_state.dart';

void main() {
  group('DeviceConnectionState', () {
    final testDevice = BleDevice(id: 'AA:BB:CC', name: 'Test Device', rssi: -50);

    test('isOnline should be true when syncStatus is synced', () {
      final state = DeviceConnectionState(
        device: testDevice,
        syncStatus: DeviceSyncStatus.synced,
      );
      expect(state.isOnline, true);
    });

    test('isOnline should be false for non-synced statuses', () {
      for (final status in DeviceSyncStatus.values) {
        final state = DeviceConnectionState(
          device: testDevice,
          syncStatus: status,
        );
        if (status == DeviceSyncStatus.synced) {
          expect(state.isOnline, true);
        } else {
          expect(state.isOnline, false, reason: '$status should not be online');
        }
      }
    });

    test('copyWith should preserve fields when not specified', () {
      final state = DeviceConnectionState(
        device: testDevice,
        syncStatus: DeviceSyncStatus.syncing,
        selectedItemId: 'item_1',
        isOverriding: true,
      );
      final copied = state.copyWith(syncStatus: DeviceSyncStatus.synced);
      expect(copied.device, testDevice);
      expect(copied.syncStatus, DeviceSyncStatus.synced);
      expect(copied.selectedItemId, 'item_1');
      expect(copied.isOverriding, true);
    });

    test('copyWith clearSelectedItemId should set to null', () {
      final state = DeviceConnectionState(
        device: testDevice,
        syncStatus: DeviceSyncStatus.synced,
        selectedItemId: 'item_1',
      );
      final cleared = state.copyWith(clearSelectedItemId: true);
      expect(cleared.selectedItemId, isNull);
    });
  });

  group('DeviceSyncStatus', () {
    test('should have all expected values', () {
      expect(DeviceSyncStatus.values, containsAll([
        DeviceSyncStatus.handshaking,
        DeviceSyncStatus.syncing,
        DeviceSyncStatus.synced,
        DeviceSyncStatus.conflict,
        DeviceSyncStatus.setup,
        DeviceSyncStatus.wrongAccount,
      ]));
    });
  });

  group('isItemEditable', () {
    final testDevice = BleDevice(id: 'AA:BB:CC', name: 'Test', rssi: -50);

    test('unclaimed items are always editable', () {
      // No claimedBy means unclaimed
      expect(isItemEditable(null, {}), true);
    });

    test('claimed item is editable when claiming device is online', () {
      final devices = {
        'dev_1': DeviceConnectionState(
          device: testDevice,
          syncStatus: DeviceSyncStatus.synced,
        ),
      };
      expect(isItemEditable('dev_1', devices), true);
    });

    test('claimed item is NOT editable when claiming device is offline', () {
      expect(isItemEditable('dev_1', {}), false);
    });

    test('claimed item is NOT editable when claiming device is not synced', () {
      final devices = {
        'dev_1': DeviceConnectionState(
          device: testDevice,
          syncStatus: DeviceSyncStatus.handshaking,
        ),
      };
      expect(isItemEditable('dev_1', devices), false);
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/features/bluetooth/presentation/bloc/device_connection_state_test.dart`
Expected: FAIL

**Step 3: Implement DeviceConnectionState**

```dart
// lib/features/bluetooth/presentation/bloc/device_connection_state.dart
import 'package:equatable/equatable.dart';

import '../../domain/entities/ble_device.dart';

/// Sync status for a single device connection.
///
/// Named DeviceSyncStatus to avoid collision with existing SyncStatus enum
/// (which has: inSync, conflict, wrongAccount, uninitialized).
enum DeviceSyncStatus {
  /// Handshake in progress
  handshaking,

  /// Device data syncing (after handshake, before sync_complete)
  syncing,

  /// Fully synced and ready for use
  synced,

  /// Sync conflict detected (seq mismatch)
  conflict,

  /// Device needs initial setup (uninitialized/factory reset)
  setup,

  /// Device paired to different user account
  wrongAccount,
}

/// Per-device connection state within BluetoothState.
class DeviceConnectionState extends Equatable {
  final BleDevice device;
  final DeviceSyncStatus syncStatus;
  final String? selectedItemId;
  final bool isOverriding;
  final bool hasMoreLogs;
  final int? conflictAppSyncSeq;
  final int? conflictDeviceSyncSeq;

  /// Whether this device connection is fully synced and ready for use.
  bool get isOnline => syncStatus == DeviceSyncStatus.synced;

  const DeviceConnectionState({
    required this.device,
    required this.syncStatus,
    this.selectedItemId,
    this.isOverriding = false,
    this.hasMoreLogs = false,
    this.conflictAppSyncSeq,
    this.conflictDeviceSyncSeq,
  });

  DeviceConnectionState copyWith({
    BleDevice? device,
    DeviceSyncStatus? syncStatus,
    String? selectedItemId,
    bool clearSelectedItemId = false,
    bool? isOverriding,
    bool? hasMoreLogs,
    int? conflictAppSyncSeq,
    int? conflictDeviceSyncSeq,
    bool clearConflict = false,
  }) {
    return DeviceConnectionState(
      device: device ?? this.device,
      syncStatus: syncStatus ?? this.syncStatus,
      selectedItemId: clearSelectedItemId
          ? null
          : (selectedItemId ?? this.selectedItemId),
      isOverriding: isOverriding ?? this.isOverriding,
      hasMoreLogs: hasMoreLogs ?? this.hasMoreLogs,
      conflictAppSyncSeq: clearConflict
          ? null
          : (conflictAppSyncSeq ?? this.conflictAppSyncSeq),
      conflictDeviceSyncSeq: clearConflict
          ? null
          : (conflictDeviceSyncSeq ?? this.conflictDeviceSyncSeq),
    );
  }

  @override
  List<Object?> get props => [
        device,
        syncStatus,
        selectedItemId,
        isOverriding,
        hasMoreLogs,
        conflictAppSyncSeq,
        conflictDeviceSyncSeq,
      ];
}

/// Can this item be edited or deleted?
///
/// Unclaimed items are always editable.
/// Claimed items are editable only if the claiming device is online (synced).
bool isItemEditable(
  String? claimedBy,
  Map<String, DeviceConnectionState> connectedDevices,
) {
  if (claimedBy == null) return true;
  final device = connectedDevices[claimedBy];
  if (device == null) return false;
  return device.isOnline;
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/features/bluetooth/presentation/bloc/device_connection_state_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/features/bluetooth/presentation/bloc/device_connection_state.dart test/features/bluetooth/presentation/bloc/device_connection_state_test.dart
git commit -m "feat(ble): add DeviceConnectionState and DeviceSyncStatus"
```

---

### Task 5: Refactor BluetoothState to use connectedDevices map

**Files:**
- Modify: `lib/features/bluetooth/presentation/bloc/bluetooth_state.dart`

**Context:** Replace singular per-device fields with `Map<String, DeviceConnectionState> connectedDevices`. Remove `BluetoothStatus.connected` and `BluetoothStatus.disconnecting` from the enum. Update `isConnected` getter.

**Step 1: Update BluetoothStatus enum**

Remove `connected` and `disconnecting` values. These are now per-device via `DeviceSyncStatus`. Remaining values: `initial`, `checkingPermissions`, `permissionsDenied`, `bluetoothDisabled`, `ready`, `scanning`, `connecting`, `error`.

**Step 2: Replace singular fields**

Remove from BluetoothState:
- `connectedDevice` (BleDevice?) — now in `DeviceConnectionState.device`
- `connectedDeviceInstanceId` (String?) — now is the map key
- `selectedItemId` (String?) — now per-device in `DeviceConnectionState.selectedItemId`
- `hasConflict` (bool) — now per-device via `syncStatus == conflict`
- `conflictAppSyncSeq` / `conflictDeviceSyncSeq` (int?) — now per-device
- `conflictDeviceInstanceId` (String?) — now is the map key
- `needsSetup` (bool) — now per-device via `syncStatus == setup`
- `setupDeviceInstanceId` (String?) — now is the map key
- `isOverriding` (bool) — now per-device
- `hasWrongAccount` (bool) — now per-device via `syncStatus == wrongAccount`
- `isSyncing` (bool) — now per-device via `syncStatus == syncing/handshaking`
- `lastMessage` (BleMessage?) — remove (unused in UI, BLoC processes messages directly)
- `hasMoreLogs` (bool) — now per-device

Keep:
- `status` — adapter-level
- `discoveredDevices` — global
- `connectingDeviceId` — global (which device we're trying to connect)
- `errorMessage` — global
- `permissionsGranted` — global
- `bluetoothEnabled` — global
- `pairedDevices` — global

Add:
- `connectedDevices` (Map<String, DeviceConnectionState>)

**Step 3: Update copyWith**

Remove clear sentinels for removed fields. Add parameter:
```dart
Map<String, DeviceConnectionState>? connectedDevices,
```

**Step 4: Update convenience getters**

```dart
bool get isConnected => connectedDevices.isNotEmpty;
bool get hasMultipleDevices => connectedDevices.length >= 2;
DeviceConnectionState? getDevice(String id) => connectedDevices[id];

// Backward-compatible helpers for single-device code during migration
BleDevice? get connectedDevice =>
    connectedDevices.isNotEmpty ? connectedDevices.values.first.device : null;
String? get connectedDeviceInstanceId =>
    connectedDevices.isNotEmpty ? connectedDevices.keys.first : null;
String? get selectedItemId =>
    connectedDevices.isNotEmpty ? connectedDevices.values.first.selectedItemId : null;
bool get hasConflict =>
    connectedDevices.values.any((d) => d.syncStatus == DeviceSyncStatus.conflict);
bool get needsSetup =>
    connectedDevices.values.any((d) => d.syncStatus == DeviceSyncStatus.setup);
bool get hasWrongAccount =>
    connectedDevices.values.any((d) => d.syncStatus == DeviceSyncStatus.wrongAccount);
bool get isSyncing =>
    connectedDevices.values.any((d) =>
        d.syncStatus == DeviceSyncStatus.handshaking ||
        d.syncStatus == DeviceSyncStatus.syncing);
bool get isOverriding =>
    connectedDevices.values.any((d) => d.isOverriding);
```

**Step 5: Update props and toString**

Replace removed fields with `connectedDevices` in the `props` list.

**Step 6: Run build to verify compilation**

Run: `flutter build apk --debug`
Expected: Compilation errors in BLoC and UI files that reference removed copyWith params. This is expected — Task 6 updates the BLoC, Task 7 updates UI consumers.

**Step 7: Commit (state file only)**

```bash
git add lib/features/bluetooth/presentation/bloc/bluetooth_state.dart lib/features/bluetooth/presentation/bloc/device_connection_state.dart
git commit -m "refactor(ble): replace singular state fields with connectedDevices map"
```

---

### Task 6: Update BluetoothBloc handlers for per-device state

**Files:**
- Modify: `lib/features/bluetooth/presentation/bloc/bluetooth_bloc.dart`
- Modify: `lib/features/bluetooth/presentation/bloc/bluetooth_event.dart`

**Context:** This is the largest single task. Every handler that reads/writes the removed singular fields must use the `connectedDevices` map instead. The BLoC file is ~1229 lines. Key handler changes:

**Step 1: Add import for DeviceConnectionState**

```dart
import 'device_connection_state.dart';
```

**Step 2: Helper method for updating a device in the map**

Add to BluetoothBloc:
```dart
/// Returns a new connectedDevices map with one device updated.
Map<String, DeviceConnectionState> _updateDevice(
  String deviceInstanceId,
  DeviceConnectionState Function(DeviceConnectionState) update,
) {
  final current = state.connectedDevices[deviceInstanceId];
  if (current == null) return state.connectedDevices;
  return {
    ...state.connectedDevices,
    deviceInstanceId: update(current),
  };
}

/// Returns a new connectedDevices map with one device removed.
Map<String, DeviceConnectionState> _removeDevice(String deviceInstanceId) {
  return Map.of(state.connectedDevices)..remove(deviceInstanceId);
}
```

**Step 3: Update _onConnect handler**

Currently sets `status: BluetoothStatus.connected` and `connectedDevice`. Change to:
1. Keep `status: BluetoothStatus.ready` (connected is now per-device).
2. After handshake resolves deviceInstanceId, create `DeviceConnectionState` and add to map.
3. For 2b (single device), use BLE deviceId as temporary key, re-key after handshake.

**Step 4: Update _onConnectionStateChanged handler**

On connected: create `DeviceConnectionState(device: bleDevice, syncStatus: DeviceSyncStatus.handshaking)`, add to `connectedDevices`.

On disconnected: remove from `connectedDevices`. If map is now empty and status was `scanning`/`connecting`, leave as-is; otherwise set `status: BluetoothStatus.ready`.

**Step 5: Update _onDisconnect handler**

Currently sets `status: BluetoothStatus.disconnecting`. Change to: remove device from map, set status to `ready`.

**Step 6: Update _performInitialSync and related handlers**

- `_performInitialSync`: Update device's `syncStatus` in the map as sync progresses (handshaking → syncing → synced).
- `_onSyncConflictDetected`: Update the specific device's state to `conflict` with conflict seq numbers.
- `_onConfirmSyncOverride`: Read from specific device's state, update `isOverriding`.
- `_onSyncCompleted`: Update specific device to `synced`.
- `_onDeviceSetupRequired`: Update specific device to `setup`.
- `_onConfirmDeviceSetup`: Read from specific device's state.
- `_onWrongAccountDetected`: Update specific device to `wrongAccount`.

**Step 7: Update _onSendItems and _onSendSelectedItem**

Currently these don't reference per-device state (they just call use cases). No changes needed.

**Step 8: Update _onMessageReceived**

Currently updates `lastMessage` — remove that. The handler already processes the message inline.

**Step 9: Update _onUpdateSelectedItemFromDevice**

Currently sets `selectedItemId` on state. Change to update the specific device's `selectedItemId` in the map.

**Step 10: Update auto-reconnect fields**

Keep as-is for 2b (single device). Phase 2c converts to per-device maps.

**Step 11: Update _onRemovePairedDevice**

If the removed device is in `connectedDevices`, disconnect and remove from map.

**Step 12: Run full test suite**

Run: `flutter test && flutter build apk --debug`
Expected: Compilation errors in UI files only (Task 7). BLoC file should compile. Tests that don't touch BLoC directly should pass.

**Step 13: Commit**

```bash
git add lib/features/bluetooth/presentation/bloc/bluetooth_bloc.dart lib/features/bluetooth/presentation/bloc/bluetooth_event.dart
git commit -m "refactor(ble): update BLoC handlers for per-device state map"
```

---

### Task 7: Migrate UI consumers to new state shape

**Files (10 files):**
- Modify: `lib/features/bluetooth/presentation/pages/paired_devices_page.dart`
- Modify: `lib/features/bluetooth/presentation/pages/onboarding_step_device.dart`
- Modify: `lib/features/items/presentation/pages/items_list_page.dart`
- Modify: `lib/features/items/presentation/pages/manage_categories_page.dart`
- Modify: `lib/features/items/presentation/pages/deleted_items_page.dart`
- Modify: `lib/features/auth/presentation/pages/profile_page.dart`
- Modify: `lib/features/bluetooth/presentation/pages/bluetooth_page.dart`
- Modify: `lib/main.dart`
- Modify: `lib/app_shell.dart`
- Modify: `lib/features/bluetooth/presentation/utils/device_sync_helper.dart`

**Context:** These files reference removed singular fields. The backward-compatible getters on BluetoothState (from Task 5) handle most cases. The main changes are:

1. **`state.status == BluetoothStatus.connected`** → **`state.isConnected`** — All files checking for connected status. The `BluetoothStatus.connected` enum value no longer exists.

2. **`state.status == BluetoothStatus.disconnecting`** → remove check (no longer needed, disconnecting is instant from BLoC perspective).

3. **Backward-compatible getters** handle: `state.connectedDevice`, `state.connectedDeviceInstanceId`, `state.selectedItemId`, `state.hasConflict`, `state.needsSetup`, `state.hasWrongAccount`, `state.isSyncing`, `state.isOverriding` — these all work via the getters defined in Task 5.

**Step 1: Search for BluetoothStatus.connected references**

Find and replace:
- `state.status == BluetoothStatus.connected` → `state.isConnected`
- `BluetoothStatus.connected` in switch/case → add `isConnected` check
- `BluetoothStatus.disconnecting` → remove case or merge with default

**Step 2: Update app_shell.dart**

The `app_shell.dart` checks `BluetoothStatus.connected` for navigation. Change to use `state.isConnected`.

**Step 3: Update main.dart**

The `main.dart` listens for `hasConflict`, `needsSetup`, `hasWrongAccount` to show dialogs. The backward-compatible getters handle this. Check that `conflictDeviceInstanceId` / `setupDeviceInstanceId` are read correctly (now use the map key of the device with that status).

**Step 4: Update device_sync_helper.dart**

No changes needed yet (Phase 2d adds `deviceInstanceId` parameter).

**Step 5: Run full test suite**

Run: `flutter test && flutter build apk --debug`
Expected: All ~782 tests pass, BUILD SUCCESSFUL

**Step 6: Commit**

```bash
git add -A
git commit -m "refactor(ble): migrate UI consumers to connectedDevices map (no behavior change)"
```

---

## Sub-Phase 2c: Multi-Connection Support

### Task 8: Add deviceInstanceId to events

**Files:**
- Modify: `lib/features/bluetooth/presentation/bloc/bluetooth_event.dart`

**Context:** Per the design doc Section 3, these events gain a required `deviceInstanceId` parameter:
- `SendItemsToDevice`
- `SendSelectedItem`
- `MessageReceived`
- `SyncConflictDetected` (already has optional — make required)
- `ConfirmSyncOverride`
- `CancelSyncConflict`
- `ConnectionStateChanged`
- `DisconnectFromDevice`
- `DeviceSetupRequired` (already has it)
- `ConfirmDeviceSetup`
- `CancelDeviceSetup`
- `UpdateSelectedItemFromDevice`
- `SyncCompleted` (already has optional — make required)

New events to add:
- `HandshakeCompleted(String deviceInstanceId, HandshakeResult result)`

**Step 1: Add deviceInstanceId to each event class**

For each event listed above, add `final String deviceInstanceId;` as a required constructor parameter and include in `props`.

**Step 2: Add HandshakeCompleted event**

```dart
class HandshakeCompleted extends BluetoothEvent {
  final String deviceInstanceId;
  final SyncResult result;

  const HandshakeCompleted({
    required this.deviceInstanceId,
    required this.result,
  });

  @override
  List<Object?> get props => [deviceInstanceId, result];
}
```

**Step 3: Update all event dispatch sites in the BLoC**

Every `add(SomeEvent(...))` call within `bluetooth_bloc.dart` must pass the `deviceInstanceId`. For internal events dispatched from within the BLoC, the deviceInstanceId comes from the handler's context (e.g., from the connection state event, or from the performing sync method).

**Step 4: Update all event dispatch sites in UI**

UI files that dispatch events (e.g., `ConfirmSyncOverride`, `DisconnectFromDevice`) must pass the deviceInstanceId. Use `state.connectedDeviceInstanceId` (backward-compat getter) for single-device.

**Step 5: Run full test suite**

Run: `flutter test && flutter build apk --debug`

**Step 6: Commit**

```bash
git add -A
git commit -m "feat(ble): add deviceInstanceId to BLoC events"
```

---

### Task 9: Remove disconnect-before-connect gate

**Files:**
- Modify: `lib/features/bluetooth/data/datasources/bluetooth_datasource_impl.dart` (line ~167-170)

**Context:** Currently `connect()` disconnects existing device first (line 167-170). Remove this gate so multiple connections coexist.

**Step 1: Remove the early disconnect**

Delete:
```dart
// Disconnect from any existing connection
if (_connectedDevice != null) {
  await disconnect(_connectedDevice!.remoteId.str);
}
```

The connection is now stored in `_connections[deviceId]`. Multiple entries can coexist.

**Step 2: Run full test suite**

Run: `flutter test && flutter build apk --debug`

**Step 3: Commit**

```bash
git add lib/features/bluetooth/data/datasources/bluetooth_datasource_impl.dart
git commit -m "feat(ble): remove disconnect-before-connect gate for multi-connection"
```

---

### Task 10: Fire-and-forget handshake with HandshakeCompleted

**Files:**
- Modify: `lib/features/bluetooth/presentation/bloc/bluetooth_bloc.dart`

**Context:** Currently `_onConnect` awaits the full `_performInitialSync()` flow (~10s). This blocks the BLoC event queue. Change to fire-and-forget: launch sync as a non-awaited Future that dispatches `HandshakeCompleted` when done.

**Step 1: Register HandshakeCompleted handler**

```dart
on<HandshakeCompleted>(_onHandshakeCompleted);
```

**Step 2: Convert _performInitialSync to fire-and-forget**

In the connection handler, instead of:
```dart
await _performInitialSync(deviceId, emit);
```

Do:
```dart
// Fire-and-forget: don't await, dispatch HandshakeCompleted when done
_performInitialSync(deviceInstanceId).then((result) {
  if (!isClosed) {
    add(HandshakeCompleted(
      deviceInstanceId: deviceInstanceId,
      result: result,
    ));
  }
}).catchError((error) {
  AppLogger.error('Handshake failed for $deviceInstanceId: $error');
  if (!isClosed) {
    // Remove device from connected map on handshake failure
    add(ConnectionStateChanged(
      isConnected: false,
      deviceId: deviceInstanceId,
    ));
  }
});
```

**Step 3: Refactor _performInitialSync to return SyncResult**

Change signature from:
```dart
Future<void> _performInitialSync(String deviceId, Emitter<BluetoothState> emit)
```
To:
```dart
Future<SyncResult> _performInitialSync(String deviceInstanceId)
```

Remove all `emit()` calls from within — the `HandshakeCompleted` handler does all state updates.

**Step 4: Implement _onHandshakeCompleted handler**

```dart
void _onHandshakeCompleted(
  HandshakeCompleted event,
  Emitter<BluetoothState> emit,
) {
  final deviceId = event.deviceInstanceId;
  final result = event.result;

  // Route based on handshake result
  switch (result.type) {
    case SyncResultType.success:
      // Update device to synced, store selectedItemId
      emit(state.copyWith(
        connectedDevices: _updateDevice(deviceId, (d) => d.copyWith(
          syncStatus: DeviceSyncStatus.synced,
          selectedItemId: result.selectedFirestoreId,
        )),
      ));
      // Trigger paired devices reload
      add(const LoadPairedDevices());
      break;
    // ... handle conflict, setup, wrongAccount via existing event dispatches
  }
}
```

**Step 5: Run full test suite**

Run: `flutter test && flutter build apk --debug`

**Step 6: Commit**

```bash
git add lib/features/bluetooth/presentation/bloc/bluetooth_bloc.dart
git commit -m "feat(ble): fire-and-forget handshake with HandshakeCompleted event"
```

---

### Task 11: Per-device message subscriptions and auto-reconnect

**Files:**
- Modify: `lib/features/bluetooth/presentation/bloc/bluetooth_bloc.dart`

**Context:** Currently the BLoC has a single `_messageSubscription`. With multiple devices, each needs its own message subscription. Similarly, auto-reconnect must be per-device.

**Step 1: Replace singular subscription with per-device map**

```dart
// Replace:
StreamSubscription<dynamic>? _messageSubscription;

// With:
final Map<String, StreamSubscription<dynamic>> _messageSubscriptions = {};
```

**Step 2: Per-device message subscription on connect**

When a device connects, subscribe to its message stream and tag each message with the deviceInstanceId:
```dart
_messageSubscriptions[deviceInstanceId] = _watchMessages(deviceId).listen(
  (message) {
    if (!isClosed) {
      add(MessageReceived(message, deviceInstanceId: deviceInstanceId));
    }
  },
);
```

**Step 3: Cancel per-device subscription on disconnect**

```dart
_messageSubscriptions[deviceInstanceId]?.cancel();
_messageSubscriptions.remove(deviceInstanceId);
```

**Step 4: Per-device auto-reconnect**

Replace:
```dart
bool _isManualDisconnect = false;
String? _lastConnectedDeviceId;
Timer? _reconnectTimer;
int _reconnectAttempts = 0;
```

With:
```dart
final Set<String> _manualDisconnects = {};
final Map<String, String> _lastConnectedDeviceIds = {}; // instanceId → bleDeviceId
final Map<String, Timer> _reconnectTimers = {};
final Map<String, int> _reconnectAttempts = {};
```

Each device has independent reconnect with exponential backoff. Manual disconnect for one device doesn't affect others.

**Step 5: Run full test suite**

Run: `flutter test && flutter build apk --debug`

**Step 6: Commit**

```bash
git add lib/features/bluetooth/presentation/bloc/bluetooth_bloc.dart
git commit -m "feat(ble): per-device message subscriptions and auto-reconnect"
```

---

## Sub-Phase 2d: Claim Logic

### Task 12: Add ClaimItem and ReleaseItem events + handler stubs

**Files:**
- Modify: `lib/features/bluetooth/presentation/bloc/bluetooth_event.dart`
- Modify: `lib/features/bluetooth/presentation/bloc/bluetooth_bloc.dart`
- Modify: `lib/features/items/domain/repositories/item_repository.dart` (add claimItem/releaseItem)
- Modify: `lib/features/items/data/repositories/item_repository_impl.dart`
- Modify: `lib/features/items/data/datasources/item_remote_datasource.dart`
- Modify: `lib/features/items/data/datasources/item_remote_datasource_impl.dart`

**Step 1: Add events**

```dart
/// Claim an item for exclusive use by a device.
class ClaimItem extends BluetoothEvent {
  final String itemId;
  final String deviceInstanceId;

  const ClaimItem({required this.itemId, required this.deviceInstanceId});

  @override
  List<Object?> get props => [itemId, deviceInstanceId];
}

/// Release a claim on an item.
class ReleaseItem extends BluetoothEvent {
  final String itemId;

  const ReleaseItem({required this.itemId});

  @override
  List<Object?> get props => [itemId];
}
```

**Step 2: Add Firestore claim transaction to datasource**

In `item_remote_datasource.dart` (abstract):
```dart
Future<void> claimItem(String itemId, String deviceInstanceId);
Future<void> releaseItem(String itemId);
Future<void> releaseAllClaims(String deviceInstanceId);
```

In `item_remote_datasource_impl.dart`:
```dart
@override
Future<void> claimItem(String itemId, String deviceInstanceId) async {
  try {
    await _firestore.runTransaction((transaction) async {
      final docRef = _firestore.collection('items').doc(itemId);
      final snapshot = await transaction.get(docRef);
      final data = snapshot.data();
      if (data == null) throw ServerException('Item not found');

      final currentClaim = data['claimed_by'] as String?;
      if (currentClaim != null && currentClaim != deviceInstanceId) {
        throw ClaimConflictException('Item already claimed by $currentClaim');
      }

      transaction.update(docRef, {
        'claimed_by': deviceInstanceId,
        'claimed_at': FieldValue.serverTimestamp(),
      });
    });
  } on ClaimConflictException {
    rethrow;
  } on FirebaseException catch (e) {
    throw ServerException('Failed to claim item: ${e.message}');
  }
}
```

**Step 3: Add to repository**

```dart
Future<Either<Failure, void>> claimItem(String itemId, String deviceInstanceId);
Future<Either<Failure, void>> releaseItem(String itemId);
Future<Either<Failure, void>> releaseAllClaims(String deviceInstanceId);
```

**Step 4: Register handlers in BLoC**

```dart
on<ClaimItem>(_onClaimItem);
on<ReleaseItem>(_onReleaseItem);
```

**Step 5: Implement stub handlers**

```dart
Future<void> _onClaimItem(ClaimItem event, Emitter<BluetoothState> emit) async {
  // TODO: Implement in Task 13
}
```

**Step 6: Add ClaimConflictException**

```dart
// lib/core/error/exceptions.dart (or bluetooth-specific)
class ClaimConflictException implements Exception {
  final String message;
  ClaimConflictException(this.message);
}
```

**Step 7: Run full test suite**

Run: `flutter test && flutter build apk --debug`

**Step 8: Commit**

```bash
git add -A
git commit -m "feat(ble): add ClaimItem/ReleaseItem events and Firestore transaction"
```

---

### Task 13: Implement claim handler with push to affected devices

**Files:**
- Modify: `lib/features/bluetooth/presentation/bloc/bluetooth_bloc.dart`
- Modify: `lib/features/bluetooth/presentation/utils/device_sync_helper.dart`

**Context:** The `ClaimItem` handler must:
1. Release previous claim (if device had a different item selected)
2. Claim the new item via Firestore transaction
3. Push claim-filtered `set_items` to affected devices

**Step 1: Add deviceInstanceId parameter to syncItemsToDevice**

In `device_sync_helper.dart`, add:
```dart
void syncItemsToDevice({
  required BluetoothBloc bluetoothBloc,
  required List<Item> allItems,
  required String deviceInstanceId,  // NEW
  required String? deviceSelectedId,
  required Map<String, String> categoryNames,
  String? excludeItemId,
  Item? includeItem,
  String? fallbackCategoryId,
}) {
  // ... existing category filtering logic ...

  // NEW: Filter by claim state — device sees only unclaimed items + its own claims
  categoryItems = categoryItems.where((item) =>
    item.claimedBy == null || item.claimedBy == deviceInstanceId
  ).toList();

  // ... existing sort ...

  bluetoothBloc.add(SendItemsToDevice(
    categoryItems,
    categoryNames: categoryNames,
    deviceInstanceId: deviceInstanceId,  // NEW
  ));

  // ... existing set_selected logic ...
}
```

**Step 2: Update all 4 call sites to pass deviceInstanceId**

- `items_list_page.dart` — pass `state.connectedDeviceInstanceId!`
- `deleted_items_page.dart` — pass `state.connectedDeviceInstanceId!`
- `profile_page.dart` — pass `state.connectedDeviceInstanceId!`
- `manage_categories_page.dart` — pass `state.connectedDeviceInstanceId!`

**Step 3: Implement _onClaimItem**

```dart
Future<void> _onClaimItem(ClaimItem event, Emitter<BluetoothState> emit) async {
  final deviceState = state.connectedDevices[event.deviceInstanceId];
  if (deviceState == null) return;

  // Release previous claim if device had a different item
  final previousItemId = deviceState.selectedItemId;
  if (previousItemId != null && previousItemId != event.itemId) {
    await _itemRepository.releaseItem(previousItemId);
  }

  // Claim the new item
  final result = await _itemRepository.claimItem(event.itemId, event.deviceInstanceId);

  result.fold(
    (failure) {
      // Claim conflict — push corrective set_items to this device
      AppLogger.debug('Claim failed for ${event.itemId}: ${failure.message}');
      _pushCorrectiveSetItems(event.deviceInstanceId, emit);
    },
    (_) {
      // Claim succeeded — update selectedItemId
      emit(state.copyWith(
        connectedDevices: _updateDevice(event.deviceInstanceId, (d) =>
          d.copyWith(selectedItemId: event.itemId)),
      ));

      // Push updated set_items to other affected devices
      _pushToAffectedDevices(event.itemId, event.deviceInstanceId);
    },
  );
}
```

**Step 4: Implement _pushToAffectedDevices helper**

```dart
void _pushToAffectedDevices(String claimedItemId, String claimingDeviceId) {
  // For each OTHER connected device, check if the claimed item
  // was in their visible category. If so, push corrective set_items.
  for (final entry in state.connectedDevices.entries) {
    if (entry.key == claimingDeviceId) continue;
    // Trigger sync for each affected device
    // (implementation delegates to syncItemsToDevice)
  }
}
```

**Step 5: Run full test suite**

Run: `flutter test && flutter build apk --debug`

**Step 6: Commit**

```bash
git add -A
git commit -m "feat(ble): implement claim handler with claim-filtered push"
```

---

### Task 14: Wire switch event to ClaimItem dispatch

**Files:**
- Modify: `lib/features/bluetooth/presentation/bloc/bluetooth_bloc.dart`
- Modify: `lib/features/bluetooth/domain/usecases/sync_device_data_usecase.dart`

**Context:** When a device reports a "switch" event (user pressed switch button on ESP32), the BLoC should dispatch `ClaimItem` instead of just updating `selectedItemId`.

**Step 1: Add deviceInstanceId to SyncDeviceDataParams**

```dart
class SyncDeviceDataParams extends Equatable {
  final BleMessage message;
  final String userId;
  final String? deviceInstanceId;  // NEW

  const SyncDeviceDataParams({
    required this.message,
    required this.userId,
    this.deviceInstanceId,
  });
  // ...
}
```

**Step 2: Pass deviceInstanceId through EventLog creation**

In `SyncDeviceDataUseCase`, where EventLog records are created, set `deviceInstanceId: params.deviceInstanceId`.

**Step 3: Update BLoC _onMessageReceived to pass deviceInstanceId**

The `MessageReceived` event now has `deviceInstanceId`. Pass it through to `SyncDeviceDataParams`.

**Step 4: Dispatch ClaimItem on switch result**

In `_onMessageReceived`, after `_syncDeviceData` returns a `selectedFirestoreId`:
```dart
if (result.selectedFirestoreId != null) {
  add(ClaimItem(
    itemId: result.selectedFirestoreId!,
    deviceInstanceId: event.deviceInstanceId,
  ));
}
```

**Step 5: Run full test suite**

Run: `flutter test && flutter build apk --debug`

**Step 6: Commit**

```bash
git add -A
git commit -m "feat(ble): wire switch event to ClaimItem dispatch"
```

---

### Task 15: Post-handshake claim-filtered push

**Files:**
- Modify: `lib/features/bluetooth/presentation/bloc/bluetooth_bloc.dart`

**Context:** After a device completes handshake (synced), it still has old item lists. Push claim-filtered `set_items` to ensure it only sees unclaimed items + its own claims.

**Step 1: Add post-handshake push in HandshakeCompleted handler**

After setting device state to `synced`:
```dart
// Push claim-filtered items to newly synced device
_pushClaimFilteredItems(event.deviceInstanceId);
```

**Step 2: Implement _pushClaimFilteredItems**

```dart
void _pushClaimFilteredItems(String deviceInstanceId) {
  // Load all items and category names, then call syncItemsToDevice
  // with the deviceInstanceId for claim filtering
}
```

**Step 3: Apply claim filtering during override**

In `_onConfirmSyncOverride` and `_onConfirmDeviceSetup`, filter items by claim state before sending override chunks.

**Step 4: Run full test suite**

Run: `flutter test && flutter build apk --debug`

**Step 5: Commit**

```bash
git add lib/features/bluetooth/presentation/bloc/bluetooth_bloc.dart
git commit -m "feat(ble): push claim-filtered items after handshake"
```

---

### Task 16: Auto-release claims on unpair

**Files:**
- Modify: `lib/features/bluetooth/presentation/bloc/bluetooth_bloc.dart`
- Test: `test/features/bluetooth/presentation/bloc/claim_logic_test.dart`

**Context:** When a device is unpaired (removed from paired devices list), all its claims must be released.

**Step 1: Write the test**

```dart
// test/features/bluetooth/presentation/bloc/claim_logic_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:traxelos/features/bluetooth/presentation/bloc/device_connection_state.dart';

void main() {
  group('Claim logic helpers', () {
    // Test isItemEditable (already in Task 4 tests)
    // Test claim-filtering logic
    test('claim filter should keep unclaimed items and own claims', () {
      // Items: unclaimed, claimed by dev_1, claimed by dev_2
      // Filter for dev_1: should keep unclaimed + dev_1 claims
      // (This tests the filter logic from syncItemsToDevice)
    });
  });
}
```

**Step 2: Update _onRemovePairedDevice**

In the `_onRemovePairedDevice` handler, before removing the device:
```dart
// Release all claims for this device
await _itemRepository.releaseAllClaims(event.deviceInstanceId);
```

**Step 3: Implement releaseAllClaims in datasource**

```dart
@override
Future<void> releaseAllClaims(String deviceInstanceId) async {
  try {
    final snapshot = await _firestore
        .collection('items')
        .where('claimed_by', isEqualTo: deviceInstanceId)
        .get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        'claimed_by': FieldValue.delete(),
        'claimed_at': FieldValue.delete(),
      });
    }
    await batch.commit();
  } on FirebaseException catch (e) {
    throw ServerException('Failed to release claims: ${e.message}');
  }
}
```

**Step 4: Run full test suite**

Run: `flutter test && flutter build apk --debug`

**Step 5: Commit**

```bash
git add -A
git commit -m "feat(ble): auto-release claims on device unpair"
```

---

### Task 17: Final verification and cleanup

**Files:**
- All modified files

**Step 1: Run complete test suite**

Run: `flutter test`
Expected: All tests pass

**Step 2: Verify build**

Run: `flutter build apk --debug`
Expected: BUILD SUCCESSFUL

**Step 3: Remove backward-compatible getters (if all callers migrated)**

Check if any code still uses the backward-compatible getters from Task 5. If all UI code has been migrated to use the map directly, remove the deprecated getters. If some callers remain, leave getters with `@Deprecated` annotation for Phase 3 cleanup.

**Step 4: Push and request code review**

```bash
git push origin feature/multi-device-ble
```

Run code review using `superpowers:requesting-code-review`.

---

## Dependency Graph

```
Task 1 (DeviceConnection class)
  └→ Task 2 (Datasource refactor)
       └→ Task 3 (Interface + repository update)
            └→ Task 4 (DeviceConnectionState)
                 └→ Task 5 (BluetoothState refactor)
                      └→ Task 6 (BLoC handlers)
                           └→ Task 7 (UI migration)
                                ├→ Task 8 (Events + deviceInstanceId)
                                │    └→ Task 9 (Remove disconnect gate)
                                │         └→ Task 10 (Fire-and-forget handshake)
                                │              └→ Task 11 (Per-device subscriptions)
                                │                   └→ Task 12 (Claim events + Firestore)
                                │                        └→ Task 13 (Claim handler + push)
                                │                             └→ Task 14 (Switch → ClaimItem)
                                │                                  └→ Task 15 (Post-handshake push)
                                │                                       └→ Task 16 (Unpair release)
                                │                                            └→ Task 17 (Final verification)
```

## Test Strategy

- **Phase 2a/2b**: Pure refactors. Existing tests are the safety net. New unit tests for `DeviceConnection` and `DeviceConnectionState`. Build verification after each task.
- **Phase 2c/2d**: New behavior. Write tests for `DeviceConnectionState`, `isItemEditable`, claim filtering logic, and claim transaction. BLoC-level tests are gated behind `@TestOn('android || ios')` — verify on emulator.
- **All tasks**: Run `flutter test` + `flutter build apk --debug` before each commit.

## Risk Areas

1. **BLoC handler migration (Task 6)** — Largest single task. The `_performInitialSync` flow is complex (~100 lines). Take extra care with emit calls.
2. **Fire-and-forget timing (Task 10)** — Ensure handshake completion dispatches arrive correctly even if BLoC processes other events concurrently.
3. **Write queue (Task 2)** — Decide if write queue stays global (simpler, prevents cross-device chunk interleaving) or becomes per-device. Design doc says per-device but global may be safer for BLE stack.
4. **UI migration (Task 7)** — 10 files, mostly mechanical but easy to miss a reference.
