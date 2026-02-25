# Phase 2: Multi-Device BLE & Claim Logic — Detailed Design

> **Status:** Approved
> **Date:** 2026-02-24
> **Parent Spec:** [EXCLUSIVE_LEASING_SPEC.md](../EXCLUSIVE_LEASING_SPEC.md) — Section 12, Phase 2

---

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Datasource refactor | DeviceConnection objects in a coordinator map | Clean per-device lifecycle; connect creates, disconnect disposes |
| BLoC architecture | Single BluetoothBloc with per-device state | Avoids dynamic BLoC creation; claims are cross-device by nature |
| Claim ownership | BluetoothBloc owns claim logic | Already orchestrates sync/push; avoids circular cross-BLoC deps |
| "Online" definition | Connected + handshake complete (`DeviceSyncStatus.synced`) | Safest — device is fully synced before allowing edits |
| Claim transaction | Firestore read-then-write transaction | Deterministic winner/loser on race; ~10ms overhead |

---

## 1. DeviceConnection Class

Each connected device gets a `DeviceConnection` instance encapsulating all per-device state:

```dart
class DeviceConnection {
  final String deviceInstanceId;
  final BluetoothDevice device;

  // Characteristics (discovered on connect)
  BluetoothCharacteristic? readChar;
  BluetoothCharacteristic? notifyChar;
  BluetoothCharacteristic? setItemsChar;
  BluetoothCharacteristic? writeChar;

  // Connection
  int negotiatedMtu = 180;
  StreamSubscription<BluetoothConnectionState>? connectionSubscription;

  // Message assembly
  StreamSubscription<List<int>>? notifySubscription;
  final messageController = StreamController<BleMessage>.broadcast();
  final messageBuffer = StringBuffer();
  Timer? messageTimeoutTimer;

  // Write serialization
  final writeQueue = <WriteOperation>[];
  bool isProcessingWrite = false;

  void dispose() { /* cancel all subscriptions, close controllers */ }
}
```

The datasource becomes a coordinator:

```dart
class BluetoothDataSourceImpl {
  final Map<String, DeviceConnection> _connections = {};
  final _connectionStateController =
      StreamController<(String, BleConnectionState)>.broadcast();

  DeviceConnection? getConnection(String deviceInstanceId) =>
      _connections[deviceInstanceId];
}
```

Key changes from current architecture:

- `connect()` creates a new `DeviceConnection` and adds it to the map. **No longer disconnects existing device first** — multiple connections coexist.
- `disconnect()` calls `connection.dispose()` and removes from map.
- All data methods (`writeCommand`, `writeItems`, etc.) look up the connection by `deviceInstanceId`.
- `_connectionStateController` emits `(deviceInstanceId, state)` tuples so the BLoC knows which device changed.
- `_connectedDeviceModel` cache is removed — BLoC state tracks connected devices.

---

## 2. BluetoothState Refactor

State splits into **global fields** (adapter-level) and **per-device fields** (new `DeviceConnectionState`).

### DeviceConnectionState

```dart
class DeviceConnectionState {
  final BleDevice device;
  final DeviceSyncStatus syncStatus;
  final String? selectedItemId;
  final bool isOverriding;
  final bool hasMoreLogs;
  final int? conflictAppSyncSeq;
  final int? conflictDeviceSyncSeq;

  bool get isOnline => syncStatus == DeviceSyncStatus.synced;
}

/// Named DeviceSyncStatus to avoid collision with existing SyncStatus enum
/// (which has: inSync, conflict, wrongAccount, uninitialized — used for handshake results).
enum DeviceSyncStatus { handshaking, syncing, synced, conflict, setup, wrongAccount }
```

### BluetoothState

```dart
class BluetoothState {
  // === GLOBAL (adapter-level) ===
  final BluetoothStatus status;            // initial, checking, scanning, ready, error
  final List<BleDevice> discoveredDevices;
  final String? connectingDeviceId;
  final String? errorMessage;
  final bool permissionsGranted;
  final bool bluetoothEnabled;
  final List<PairedDevice> pairedDevices;

  // === PER-DEVICE ===
  final Map<String, DeviceConnectionState> connectedDevices;

  // === CONVENIENCE GETTERS ===
  bool get isConnected => connectedDevices.isNotEmpty;
  bool get hasMultipleDevices => connectedDevices.length >= 2;
  DeviceConnectionState? getDevice(String id) => connectedDevices[id];
}
```

Removed singular fields: `connectedDevice`, `connectedDeviceInstanceId`, `hasConflict`, `conflictDeviceInstanceId`, `needsSetup`, `setupDeviceInstanceId`, `selectedItemId`, `isSyncing`, `isOverriding`, `hasWrongAccount`.

### Claim-Aware Predicates

Phase 3 (UI) needs these predicates from Phase 2 to gate edit/delete actions:

```dart
/// Can this item be edited or deleted?
/// Unclaimed items are always editable.
/// Claimed items are editable only if the claiming device is online.
bool isItemEditable(Item item, Map<String, DeviceConnectionState> connectedDevices) {
  if (item.claimedBy == null) return true;
  final device = connectedDevices[item.claimedBy!];
  if (device == null) return false; // claiming device not connected = offline = locked
  return device.isOnline;
}
```

This enforces the parent spec rules (Section 3.1/3.2): online-claimed items are fully editable, offline-claimed items block edit page entry and deletion.

`BluetoothStatus` no longer includes `connected`/`disconnecting` — those are per-device via `SyncStatus`. Existing code that checks `state.status == BluetoothStatus.connected` must migrate to `state.isConnected`.

---

## 3. BLoC Event & Handler Changes

### Modified Events (gain deviceInstanceId)

```dart
SendItemsToDevice(items, categoryNames, {required String deviceInstanceId})
SendSelectedItem(firestoreId, deviceItemId, {required String deviceInstanceId})
MessageReceived(BleMessage message, {required String deviceInstanceId})
SyncConflictDetected({required String deviceInstanceId, ...})
ConfirmSyncOverride({required String deviceInstanceId})
CancelSyncConflict({required String deviceInstanceId})
DeviceSetupRequired({required String deviceInstanceId})
ConfirmDeviceSetup({required String deviceInstanceId})
```

### New Events

```dart
ClaimItem(String itemId, String deviceInstanceId)
ReleaseItem(String itemId)
HandshakeCompleted(String deviceInstanceId, HandshakeResult result)
```

### Connection Handler

```
On connected (device X):
  [1] Create DeviceConnectionState(device: X, syncStatus: handshaking)
  [2] Add to state.connectedDevices map
  [3] Subscribe to device X's message stream
  [4] Launch _performInitialSync(X) as fire-and-forget (don't await)
      → On completion, dispatch HandshakeCompleted(X, result)
  [5] Handler returns immediately → next device can process

On disconnected (device X):
  [1] Remove X from state.connectedDevices map
  [2] Cancel X's message subscription
  [3] Schedule auto-reconnect for X (per-device timer + attempt counter)
  [4] Do NOT release claims — X's items stay claimed (offline state)
```

Fire-and-forget handshake is critical: flutter_bloc processes events sequentially. If handler awaits the full handshake (~10 seconds), Device B's connection event queues behind Device A.

### Claim Handler

```
ClaimItem(itemId, deviceInstanceId):
  [1] Get previous claim: state.connectedDevices[deviceInstanceId].selectedItemId
  [2] Run SINGLE Firestore transaction:
      - Read new item's claimed_by
      - If null → claim it
      - If same device → no-op
      - If different device → throw ClaimConflictException
      - Release previous item (if any) in same transaction
  [3] Push set_items to affected devices:
      - For each connected device whose selected category contains the affected item(s):
        * Skip the claiming device
        * Filter items (unclaimed + that device's own claims)
        * Send filtered set_items
      - If previous claim's item was sent to another device, push corrective set_items
  [4] On ClaimConflictException (race condition):
      - Push corrective set_items to the losing device (item removed)
      - Send set_selected to redirect, or id: -1 if list empty
```

### Auto-Reconnect

Per-device state replaces global state:

```dart
// In BLoC
final Map<String, Timer> _reconnectTimers = {};
final Map<String, int> _reconnectAttempts = {};
```

Each device has independent reconnect with exponential backoff (2s, 4s, 8s... capped at 60s). Manual disconnect for one device doesn't affect others.

---

## 4. syncItemsToDevice Refactor

```dart
void syncItemsToDevice({
  required BluetoothBloc bluetoothBloc,
  required List<Item> allItems,
  required String deviceInstanceId,         // NEW
  required String? deviceSelectedId,
  required Map<String, String> categoryNames,
  String? excludeItemId,
  Item? includeItem,
  String? fallbackCategoryId,
}) {
  // [1] Existing: filter by selected item's category
  // [2] NEW: filter by claim state
  categoryItems = categoryItems.where((item) =>
    item.claimedBy == null || item.claimedBy == deviceInstanceId
  ).toList();
  // [3] Existing: sort by categoryOrder
  // [4] Send to specific device
  bluetoothBloc.add(SendItemsToDevice(
    categoryItems, categoryNames,
    deviceInstanceId: deviceInstanceId,
  ));
}
```

### Claim-Triggered Push Flow

After `ClaimItem` succeeds:

```
[1] Identify affected category (the claimed item's categoryId)
[2] For each connected device in state.connectedDevices:
    - Skip the claiming device (it already has the item selected)
    - Get device's selectedItemId → derive its selected category
    - If device's category != affected category → skip
    - Call syncItemsToDevice() for that device
[3] If previous claim's item was visible to another connected device:
    - That device needs corrective set_items (item removed from its list)
    - Send set_selected to redirect, or id: -1 if list empty
```

### sync_seq Not Updated on Claim Pushes

Claim-triggered `set_items` pushes do **not** send `sync_complete` and do **not** update `sync_seq`. Only the handshake-initiated sync flow updates `sync_seq` (via `sync_complete` / `override_end`). This is by design — the next handshake reconciles any discrepancies.

### Post-Handshake Push

After a device completes handshake (in-sync case):

- Device still has its old item list from last connection
- Items may have been claimed by other devices since then
- Push claim-filtered `set_items` after `sync_complete`

For conflict/override case: apply claim filtering during the override itself (filter before sending `override_chunk`).

### Call Site Migration

All 5 existing call sites pass `deviceInstanceId`:
- `items_list_page.dart` — item list changes
- `deleted_items_page.dart` — item restore
- `profile_page.dart` — profile reset
- `manage_categories_page.dart` — category changes

In single-device mode: `state.connectedDevices.keys.first`.
In multi-device mode: push to each affected device.

---

## 5. SyncDeviceDataUseCase & Event Logging

### Parameter Change

```dart
class SyncDeviceDataParams {
  final BleMessage message;
  final String userId;
  final String deviceInstanceId;    // NEW
}
```

Both EventLog creation sites (`_syncEventMessage`, `_syncLogsMessage`) add `deviceInstanceId` from params.

### Switch Event → Claim Dispatch

```
On event type "switch":
  [1] Map numeric deviceItemId → firestoreId (existing logic)
  [2] Return firestoreId as selectedItemId (existing)
  [3] BLoC dispatches ClaimItem(firestoreId, deviceInstanceId)
      → Triggers Firestore transaction + push to other devices
```

### App-Initiated Events

Events created from the app (item created, etc.) pass `deviceInstanceId: null`.

---

## 6. Handshake Orchestration

Handshakes run independently per device. No shared mutable state between devices — each operates on its own `DeviceConnection` (separate write queue, message stream, characteristics).

### Concurrent Connection Flow

```
Device A: synced, counting items
Device B: connects
  │
  ├── BLoC creates DeviceConnectionState(B, handshaking)
  ├── Subscribe to B's message stream
  ├── Launch _performInitialSync(B) — fire-and-forget
  │     ├── sendTimeSync to B
  │     ├── sendHandshake to B
  │     ├── in_sync → process prefs → sendSyncComplete → HandshakeCompleted(B, synced)
  │     └── conflict → HandshakeCompleted(B, conflict) → show dialog for B
  │
  ├── After B synced: push claim-filtered set_items to B
  │
  └── Device A unaffected throughout
```

Conflict/setup/wrongAccount dialogs must identify which device they're about (show device name).

---

## 7. Error Handling & Edge Cases

| Scenario | Handling |
|----------|----------|
| Device disconnects during claim transaction | Transaction completes server-side. Claim persists, device shows "claimed (offline)". On reconnect, gets correct set_items. |
| Two devices claim same item (race) | Transaction succeeds for one, fails for other. Loser gets corrective set_items + set_selected redirect (or id: -1 if empty). |
| Device sends switch for just-claimed item | ClaimItem transaction fails → same corrective flow as race. |
| App killed mid-handshake | Other device's connection unaffected. Killed device auto-reconnects, restarts handshake fresh. |
| Bluetooth adapter turns off | All reconnect timers pause. Resume when adapter turns back on. |
| Manual disconnect one device | Other devices unaffected. Only disconnected device's reconnect is disabled. |
| Unpair releases claims | `_onRemovePairedDevice` queries items where `claimed_by == deviceInstanceId`, batch writes all to null, then disconnects if connected. |

---

## 8. Migration Strategy

Ordered sub-phases, each independently testable:

### Phase 2a: Datasource Refactor (no behavior change)

- Extract `DeviceConnection` class from existing instance fields
- Refactor `BluetoothDataSourceImpl` to use `_connections` map
- Map has 0 or 1 entry — single-device behavior preserved
- All existing tests pass (same external API)

### Phase 2b: BLoC State Refactor (no behavior change)

- Replace singular state fields with `connectedDevices` map
- Add `DeviceConnectionState` and `DeviceSyncStatus`
- Update all UI code that reads `state.connectedDevice` to use map
- Add convenience getters (`isConnected`, `getDevice()`)
- Map has 0 or 1 entry — single-device behavior preserved

### Phase 2c: Multi-Connection Support

- Remove "disconnect existing before connecting new" gate
- Per-device message subscriptions in BLoC
- Fire-and-forget handshake pattern with `HandshakeCompleted` event
- Per-device auto-reconnect timers and attempt counters
- Test with 2 devices connected simultaneously

### Phase 2d: Claim Logic

- `ClaimItem` / `ReleaseItem` events and Firestore transaction handler
- Claim-filtered `set_items` pushes to affected devices
- Switch event → `ClaimItem` dispatch
- Post-handshake claim-filtered push
- Auto-release claims on unpair
- `syncItemsToDevice` gains `deviceInstanceId` + claim filtering

---

## Files Affected

| File | Sub-phase | Change |
|------|-----------|--------|
| `bluetooth_datasource_impl.dart` | 2a | Extract DeviceConnection, coordinator map |
| `bluetooth_datasource.dart` (abstract) | 2a | connectionState stream emits (deviceId, state) tuples |
| `bluetooth_repository_impl.dart` | 2a | Route to DeviceConnection by deviceId |
| `bluetooth_state.dart` | 2b | DeviceConnectionState, connectedDevices map, DeviceSyncStatus enum, isItemEditable predicate |
| `bluetooth_bloc.dart` | 2b-2d | Per-device state management, fire-and-forget handshake, claim handlers, per-device reconnect |
| `bluetooth_event.dart` | 2c-2d | Add deviceInstanceId to events, new ClaimItem/ReleaseItem/HandshakeCompleted |
| `device_sync_helper.dart` | 2d | Add deviceInstanceId param, claim filtering |
| `sync_device_data_usecase.dart` | 2d | Accept deviceInstanceId in params (SyncDeviceDataParams is nested in this file), pass to EventLog creation |
| `items_list_page.dart` | 2b, 2d | Read from connectedDevices map, pass deviceInstanceId to sync helper |
| `deleted_items_page.dart` | 2d | Pass deviceInstanceId to sync helper |
| `profile_page.dart` | 2d | Pass deviceInstanceId to sync helper |
| `manage_categories_page.dart` | 2d | Pass deviceInstanceId to sync helper |
| `sync_usecase.dart` | 2a, 2d | Contains both PerformSyncUseCase and PerformOverrideUseCase. Use DeviceConnection, apply claim filtering in override. |
| `event_log_model.dart` | Phase 1 (prerequisite) | device_instance_id serialization |
| `item.dart` / `item_model.dart` | Phase 1 (prerequisite) | claimedBy/claimedAt fields |
