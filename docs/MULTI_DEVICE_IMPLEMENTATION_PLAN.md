# Multi-Device Enablement - Implementation Plan

> **Status:** Implemented. This document was the original design spec. For current protocol details, see [BLE_PROTOCOL.md](BLE_PROTOCOL.md). For current UI details, see [UX_SPEC_2026-02-15.md](UX_SPEC_2026-02-15.md).

## Overview

Enable users to pair multiple physical Traxelos devices to a single account, with proper synchronization and conflict resolution when switching between devices.

**Key Principles:**
- One active BLE connection at a time
- Same device reconnects (sync_seq matches) → Device is Source of Truth
- Different device connects (sync_seq mismatch) → App is Source of Truth
- New/factory-reset device (uninitialized) → App is Source of Truth
- Firebase `uid` used as account identifier
- `sync_seq` comparison alone determines conflict (simple!)

---

## Terminology

| Term | Definition |
|------|------------|
| `device_item_id` | Item slot index (0-99) on device. **Renamed from "device id"** |
| `device_instance_id` | Unique identifier for a physical device. Regenerated on factory reset |
| `sync_seq` | Global sync counter. Increments on every successful sync with any device |
| `paired_uid` | Firebase uid stored on device to lock it to one account |

---

## Conflict Detection Logic

```
Connect to device → Handshake
         ↓
    Check device state
         ↓
┌────────┼────────┬──────────────┐
↓        ↓        ↓              ↓
No UID   Wrong    sync_seq       sync_seq
(new)    UID      matches        mismatch
↓        ↓        ↓              ↓
Setup    Error    Device is      App is SOT
Dialog   Dialog   SOT (normal)   (override)
```

**Why this works:**
- `sync_seq` increments on EVERY sync
- Only the last-synced device has the current `sync_seq`
- All other devices have older values
- No need to track `last_synced_device_id`
- Uninitialized devices (no UID) always get overridden from app

---

## Phase 1: Firmware Preparation

### 1.0 Rename device_id → device_item_id

**Before starting multi-device work**, rename all references:
- `device_id` (item slot 0-99) → `device_item_id`
- This frees up "device_id" terminology for `device_instance_id`

Files to update:
- Firmware: variable names, JSON keys
- App: BLE message parsing, item model field names

### 1.1 NVS Storage Schema

```cpp
// NVS Keys
"paired_uid"          // String: Firebase uid (empty = unpaired)
"device_instance_id"  // String: Unique device identifier (UUID)
"sync_seq_no"         // int32: Last sync sequence number
```

### 1.2 Device Instance ID

The device instance ID is the device's BLE MAC address (e.g., `"AA:BB:CC:DD:EE:FF"`), obtained from `BLEDevice::getAddress()`. This is hardware-native and requires no generation logic. The MAC address is normalized to uppercase in the app.

```cpp
void setup() {
  // Device instance ID is the BLE MAC address — no generation needed
  String deviceInstanceId = BLEDevice::getAddress().toString();
}
```

### 1.3 Pairing Mode Detection

```cpp
void setup() {
  String pairedUid = nvs_get_string("paired_uid");

  if (pairedUid.isEmpty()) {
    // Unpaired device - enter pairing mode
    enterPairingMode();
    displayWelcomeScreen();
  } else {
    // Paired device - normal operation
    enterNormalMode();
  }
}
```

### 1.4 Handshake Protocol (Account Lock + Sync Check)

The handshake is the FIRST message after BLE connection. It performs both:
1. Account lock check (is this device paired to this user?)
2. Sync sequence check (is this device in sync or conflicted?)

```cpp
// App sends: { "cmd": "handshake", "uid": "xxx", "sync_seq": 42 }
void handleHandshake(String uid, int appSyncSeq) {
  String pairedUid = nvs_get_string("paired_uid");
  String deviceInstanceId = BLEDevice::getAddress().toString();

  // All responses include version fields for compatibility checking
  // "protocol_version": 2, "firmware_version": "1.5.0"

  // Step 1: Uninitialized check (new or factory-reset device)
  if (pairedUid.isEmpty()) {
    sendResponse({
      "status": "uninitialized",
      "device_instance_id": deviceInstanceId,
      "protocol_version": PROTOCOL_VERSION,
      "firmware_version": FIRMWARE_VERSION
    });
    displayMessage("AWAITING SETUP");
    return;
    // UID is stored later when override_start is received
  }

  // Step 2: Account lock check
  if (pairedUid != uid) {
    // Different account - reject
    sendResponse({
      "status": "wrong_account",
      "device_instance_id": deviceInstanceId,
      "protocol_version": PROTOCOL_VERSION,
      "firmware_version": FIRMWARE_VERSION
    });
    displayMessage("PAIRED TO");
    displayMessage("OTHER ACCOUNT");
    return;
  }

  // Step 3: Sync sequence check
  int deviceSyncSeq = nvs_get_int("sync_seq_no", 0);

  if (appSyncSeq == deviceSyncSeq) {
    // In sync - device is SOT, proceed with normal sync
    sendResponse({
      "status": "in_sync",
      "device_instance_id": deviceInstanceId,
      "protocol_version": PROTOCOL_VERSION,
      "firmware_version": FIRMWARE_VERSION
    });
  } else {
    // Out of sync - app is SOT, wait for override
    sendResponse({
      "status": "conflict",
      "device_seq": deviceSyncSeq,
      "device_instance_id": deviceInstanceId,
      "protocol_version": PROTOCOL_VERSION,
      "firmware_version": FIRMWARE_VERSION
    });
    enterConflictState();
  }
}
```

### 1.5 Conflict State Handling

```cpp
bool inConflictState = false;

void enterConflictState() {
  inConflictState = true;
  displayMessage("SEE APP");
  // Disable increment/decrement buttons
}

void exitConflictState() {
  inConflictState = false;
  enableButtons();
  clearDisplay();
}

void onDisconnect() {
  // If disconnected while in conflict, exit conflict state
  if (inConflictState) {
    exitConflictState();
  }
}

void onButtonPress() {
  if (inConflictState) {
    displayMessage("SEE APP");  // Remind user
    return;  // Ignore button press
  }
  // Normal increment/decrement logic
}
```

### 1.6 Override Handling

See **1.11 Override Chunking Protocol** for the multi-message override implementation.

Override is chunked because a full item list (up to 100 items) may exceed BLE MTU.

### 1.7 Normal Sync Completion

```cpp
// After device sends prefs and app processes them:
// App sends: { "cmd": "sync_complete", "sync_seq": 43 }
void handleSyncComplete(int newSyncSeq) {
  nvs_set_int("sync_seq_no", newSyncSeq);

  // Send acknowledgment so app knows it's safe to update Firestore
  sendResponse({ "status": "seq_updated" });

  // No display change needed - normal operation continues
}
```

### 1.8 Factory Reset

```cpp
void handleFactoryReset() {
  displayMessage("FACTORY RESET?");
  displayMessage("F=CONFIRM");

  if (waitForConfirmation('F', 10000)) {
    // Clear pairing
    nvs_erase_key("paired_uid");
    nvs_erase_key("sync_seq_no");

    // Generate NEW device instance ID
    generateDeviceInstanceId();

    // Clear item data
    for (int i = 0; i < 100; i++) {
      clearItemSlot(i);
    }

    // Clear BLE bonding
    clearBleBonding();

    displayMessage("RESET COMPLETE");
    delay(2000);

    ESP.restart();
  } else {
    displayMessage("CANCELLED");
  }
}
```

### 1.9 BLE Command Timeouts

All BLE commands should have a 10-second timeout. On timeout:
- Treat as disconnect
- App discards partial sync state
- User can reconnect to retry

### 1.10 BLE Protocol Messages

> **Source of truth:** See [BLE_PROTOCOL.md](BLE_PROTOCOL.md) Section 4 for full protocol specification.

All handshake responses include `protocol_version` (int) and `firmware_version` (string) for version compatibility. Device instance ID is the BLE MAC address.

| Direction | Message | Purpose |
|-----------|---------|---------|
| App → Device | `{"cmd":"handshake","uid":"xxx","sync_seq":42}` | Start sync handshake |
| Device → App | `{"status":"in_sync","device_instance_id":"AA:BB:CC:DD:EE:FF","protocol_version":2,"firmware_version":"1.5.0"}` | Proceed with normal sync |
| Device → App | `{"status":"conflict","device_seq":40,"device_instance_id":"...","protocol_version":2,"firmware_version":"..."}` | Conflict detected, wait for override |
| Device → App | `{"status":"uninitialized","device_instance_id":"...","protocol_version":2,"firmware_version":"..."}` | New/reset device, needs setup |
| Device → App | `{"status":"wrong_account","device_instance_id":"...","protocol_version":2,"firmware_version":"..."}` | Device paired to different account |
| Device → App | Prefs + logs notifications (automatic after `in_sync`) | Device sends items, selected_id, and logs |
| App → Device | `{"cmd":"override_start","uid":"xxx","sync_seq":43,"total_chunks":N}` | Begin override (chunked) |
| App → Device | `{"cmd":"override_chunk","index":0,"items":[...]}` | Send items chunk |
| App → Device | `{"cmd":"override_end","selected_id":2}` | Complete override |
| Device → App | `{"status":"override_complete"}` | Confirm override done |
| Device → App | `{"status":"error","message":"missing_chunks"}` | Override failed - chunks were lost |
| App → Device | `{"cmd":"sync_complete","sync_seq":43}` | After normal sync, update device seq |
| Device → App | `{"status":"seq_updated"}` | Confirm sync_seq stored |

**Normal Sync Flow (in_sync):**
1. App sends `handshake` → Device responds `in_sync`
2. Device automatically sends prefs + logs via NOTIFY
3. App processes data, sends `sync_complete` → Device responds `seq_updated`

**Override Flow (conflict or uninitialized):**
1. App sends `handshake` → Device responds `conflict` or `uninitialized`
2. User confirms in app (conflict dialog or setup dialog)
3. App sends `override_start` → `override_chunk`(s) → `override_end`
4. Device responds `override_complete`

### 1.11 Override Chunking Protocol

Override messages are chunked to fit within BLE MTU limits.

**Item fields sent during override:**

| Field | Type | Description |
|-------|------|-------------|
| `device_item_id` | int | Item slot ID (0-99) |
| `name` | string | Item name (max 30 chars) |
| `category` | string | Category name (max 30 chars) |
| `count` | int | Total count |
| `todaycount` | int | Today's count |
| `increment` | int | Count per press (1-1000) |
| `reminder` | int | Reminder type |
| `reminder_value` | int | Reminder threshold |
| `lastResetTime` | long | Last reset timestamp (UTC) |
| `reset_number` | int | Reset counter |

**`selected_id` behavior:**
- App sends `selected_id` from last successful sync with ANY device (stored in Firestore)
- If unavailable, send `-1` and device will select nothing
- If `selected_id` doesn't exist in overridden items, device falls back to first item (index 0)
- If no items at all, device selects nothing

```cpp
int overrideSyncSeq;
int overrideTotalChunks;
int overrideReceivedChunks;

void handleOverrideStart(int syncSeq, int totalChunks) {
  overrideSyncSeq = syncSeq;
  overrideTotalChunks = totalChunks;
  overrideReceivedChunks = 0;

  // Clear existing items to prepare for new data
  clearAllItemSlots();
}

void handleOverrideChunk(int index, JsonArray items) {
  for (JsonObject item : items) {
    int slotId = item["device_item_id"];
    if (slotId >= 0 && slotId < 100) {  // Enforce 100 item limit
      saveItemToSlot(slotId, item);
    }
  }
  overrideReceivedChunks++;
}

void handleOverrideEnd(int selectedId) {
  if (overrideReceivedChunks != overrideTotalChunks) {
    sendResponse({ "status": "error", "message": "missing_chunks" });
    return;
  }

  setSelectedItem(selectedId);
  nvs_set_int("sync_seq_no", overrideSyncSeq);
  exitConflictState();

  sendResponse({ "status": "override_complete" });
  displayMessage("SYNCED");
}
```

---

## Phase 2: Firestore Schema

### 2.1 User Document Updates

```
users/{uid}:
  // Existing fields...

  // New fields for multi-device:
  sync_sequence_no: int (default: 0)
  last_selected_device_item_id: int (default: -1, updated after each sync)
  paired_devices: [
    {
      device_instance_id: String,
      device_name: String,
      paired_at: Timestamp
    }
  ]
```

### 2.2 Device Limit

Maximum 10 paired devices per account.

---

## Limitations & Constraints

| Constraint | Reason |
|------------|--------|
| **Item creation requires BLE connection** | Items need `device_item_id` assigned by device. Creating items while disconnected would leave them un-syncable. |
| **Maximum 100 items per account** | Device has 100 item slots (0-99). Both app and device enforce this limit. |
| **Maximum 10 paired devices** | Prevents excessive device registry growth. |
| **One BLE connection at a time** | BLE hardware limitation + simplifies sync logic. |
| **Sync requires internet connection** | App must fetch fresh sync_seq from Firestore. Show error: "Internet connection required to sync." |

---

## Phase 3: App Implementation

### 3.1 Data Models

```dart
// lib/features/bluetooth/domain/entities/paired_device.dart
class PairedDevice {
  final String deviceInstanceId;
  final String deviceName;
  final DateTime pairedAt;

  const PairedDevice({
    required this.deviceInstanceId,
    required this.deviceName,
    required this.pairedAt,
  });
}
```

```dart
// lib/features/bluetooth/domain/entities/sync_state.dart
enum SyncStatus { inSync, conflict, wrongAccount, uninitialized }

class HandshakeResult {
  final SyncStatus status;
  final String deviceInstanceId;
  final int? deviceSyncSeq;      // Only present if conflict
  final int? protocolVersion;     // For compatibility checking
  final String? firmwareVersion;  // For compatibility checking

  const HandshakeResult({
    required this.status,
    required this.deviceInstanceId,
    this.deviceSyncSeq,
    this.protocolVersion,
    this.firmwareVersion,
  });
}
```

### 3.2 Sync Flow - Handshake

```dart
Future<Either<Failure, SyncResult>> performSync() async {
  // Step 0: Check internet connectivity FIRST
  final hasInternet = await connectivityService.hasInternetConnection();
  if (!hasInternet) {
    return Left(NoInternetFailure('Internet connection required to sync.'));
  }

  // Step 1: Get current user's sync state
  // CRITICAL: Fetch FRESH from Firestore, not cached!
  // This prevents stale data issues with multiple app instances (phone + tablet)
  final user = await userRepository.getCurrentUser();
  final appSyncSeq = await userRepository.fetchSyncSequenceFromServer();

  // Step 2: Send handshake
  final handshake = await bleService.sendHandshake(
    uid: user.uid,
    syncSeq: appSyncSeq,
  );

  // Step 3: Check for wrong account FIRST (before adding to paired_devices)
  if (handshake.status == SyncStatus.wrongAccount) {
    // Device is paired to different account - can't sync, don't add to our list
    // UI shows WrongAccountDialog with recovery instructions
    return Left(WrongAccountFailure(
      'This device is paired to another account.',
    ));
  }

  // Step 4: Handle uninitialized device (new or factory-reset)
  if (handshake.status == SyncStatus.uninitialized) {
    // UI shows DeviceSetupDialog: "New Device Detected"
    // User confirms → performOverride() which also stores UID on device
    return Left(DeviceSetupRequired(
      deviceInstanceId: handshake.deviceInstanceId,
    ));
  }

  // Step 5: Add to paired devices if new (only after confirming it's our device)
  final isNewDevice = !user.pairedDevices.any(
    (d) => d.deviceInstanceId == handshake.deviceInstanceId
  );

  if (isNewDevice) {
    // Check device limit
    if (user.pairedDevices.length >= 10) {
      return Left(DeviceLimitFailure());
    }
    // Add to paired devices list
    await userRepository.addPairedDevice(PairedDevice(
      deviceInstanceId: handshake.deviceInstanceId,
      deviceName: 'Traxelos One',  // Default name
      pairedAt: DateTime.now(),
    ));
  }

  // Step 6: Handle sync based on status
  if (handshake.status == SyncStatus.inSync) {
    return _performNormalSync(appSyncSeq);
  } else {
    // Return conflict for UI to handle
    // UI shows SyncConflictDialog with device name and ID
    return Left(SyncConflictFailure(
      deviceSyncSeq: handshake.deviceSyncSeq,
      appSyncSeq: appSyncSeq,
    ));
  }
}
```

### 3.3 Normal Sync Flow

```dart
Future<Either<Failure, SyncResult>> _performNormalSync(int currentSeq) async {
  // Step 1: Request prefs from device (existing flow)
  // IMPORTANT: Collect ALL chunks before proceeding
  // Device sends: items + selected_device_item_id
  final prefs = await bleService.requestPrefs();

  // Step 2: Increment sync_seq
  final newSyncSeq = currentSeq + 1;

  // Step 3: Send sync_complete and WAIT for acknowledgment
  final ack = await bleService.sendSyncComplete(newSyncSeq);
  if (ack.status != 'seq_updated') {
    return Left(SyncFailure('Device did not acknowledge sync_complete'));
  }

  // Step 4: ONLY NOW update Firestore (after device confirmed)
  // This prevents false conflicts if BLE disconnects
  // CRITICAL: Retry on failure to prevent sync_seq desync
  try {
    await itemRepository.batchUpdateCounts(userId, prefs.items);
    await userRepository.updateSyncState(
      syncSequenceNo: newSyncSeq,
      lastSelectedDeviceItemId: prefs.selectedDeviceItemId,  // Save for future override
    );
  } catch (e) {
    // Firestore update failed after device already stored new sync_seq
    // Retry up to 3 times to prevent desync
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        await Future.delayed(Duration(seconds: attempt));  // Backoff
        await itemRepository.batchUpdateCounts(userId, prefs.items);
        await userRepository.updateSyncState(
          syncSequenceNo: newSyncSeq,
          lastSelectedDeviceItemId: prefs.selectedDeviceItemId,
        );
        return Right(SyncResult.success);
      } catch (_) {
        if (attempt == 3) {
          // All retries failed - warn user
          return Left(FirestoreUpdateFailure(
            'Sync incomplete. Please ensure internet connection and try again.',
          ));
        }
      }
    }
  }

  return Right(SyncResult.success);
}
```

**Disconnect Handling:** If BLE disconnects at any point before Step 4:
- Discard partial data (don't update Firestore)
- On reconnect, handshake will succeed again (sync_seq still matches)
- Sync restarts cleanly

**Firestore Update Failure:** If Firestore update fails after device ack:
- App retries up to 3 times with backoff
- If all retries fail, show error and prompt user to retry
- Device has new sync_seq, so reconnect will show conflict
- User must resolve conflict (override) to resync

### 3.4 Override Flow (After User Confirms)

```dart
Future<Either<Failure, SyncResult>> performOverride() async {
  // Re-check internet (user may have lost connection while viewing conflict dialog)
  final hasInternet = await connectivityService.hasInternetConnection();
  if (!hasInternet) {
    return Left(NoInternetFailure('Internet connection required to sync.'));
  }

  final user = await userRepository.getCurrentUser();
  final items = await itemRepository.getItems(user.uid);

  // Filter to items with device_item_id (synced items only)
  final deviceItems = items.where((i) => i.deviceItemId != null).toList();

  // Validate 100 item limit
  if (deviceItems.length > 100) {
    return Left(TooManyItemsFailure('Cannot sync more than 100 items'));
  }

  // Get selected item from last sync (stored in Firestore), -1 if none
  final selectedItemId = user.lastSelectedDeviceItemId ?? -1;
  final newSyncSeq = user.syncSequenceNo + 1;

  // Push to device using chunked protocol
  final result = await bleService.sendOverrideChunked(
    syncSeq: newSyncSeq,
    selectedId: selectedItemId,
    items: deviceItems,
  );

  if (result.status != 'override_complete') {
    return Left(SyncFailure('Override failed: ${result.message}'));
  }

  // Update Firestore only after device confirms
  // Retry on failure to prevent sync_seq desync
  try {
    await userRepository.updateSyncSequence(newSyncSeq);
  } catch (e) {
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        await Future.delayed(Duration(seconds: attempt));
        await userRepository.updateSyncSequence(newSyncSeq);
        return Right(SyncResult.overrideComplete);
      } catch (_) {
        if (attempt == 3) {
          return Left(FirestoreUpdateFailure(
            'Sync incomplete. Please ensure internet connection and try again.',
          ));
        }
      }
    }
  }

  return Right(SyncResult.overrideComplete);
}
```

**Disconnect Handling:** If BLE disconnects during override:
- Device may have partial data, but sync_seq NOT updated
- On reconnect, conflict detected again (sync_seq mismatch)
- User confirms again, override restarts
- Idempotent - no data corruption

### 3.5 Conflict Dialog (SyncConflictDialog)

Shows device context (name and ID) so users know which device needs syncing.

- Title: "Sync Required"
- Body: "Your device '[name]' needs to be updated to match your app." with device ID in monospace
- Warning: "Any counts on this device since your last sync will be replaced."
- Actions: "Cancel" (disconnects), "Sync Now" (triggers override)
- Non-dismissible (barrierDismissible: false)

### 3.5b Device Setup Dialog (DeviceSetupDialog)

Shown when an uninitialized device is detected (new or factory-reset). This was not in the original plan but fills a necessary gap for the `uninitialized` handshake status.

- Title: "New Device Detected"
- Body: "This will pair the device to your account. Your items will sync automatically."
- Actions: "Cancel" (disconnects), "Set Up" (triggers override, which also stores UID on device via `override_start`)
- Non-dismissible

### 3.5c Wrong Account Dialog (WrongAccountDialog)

Shown when device is locked to a different user account.

- Title: "Wrong Account"
- Body: "This device is paired to a different account." with recovery instructions (sign in with original account or factory reset)
- Actions: "OK" (dismisses and disconnects)
- Non-dismissible

### 3.6 Cancel = Disconnect

All three dialogs disconnect on cancel. The device exits its pending state (conflict/setup) on disconnect.

### 3.7 Paired Devices Page

**Layout:**
- App bar: "Paired Devices" title with back button
- List of paired devices with connection status indicators (green highlight, spinner, device ID)
- Empty state: icon with "No devices paired yet" message

**Device Tile Visual States:**
- Connected: Green left border, green background tint, "Connected" subtitle
- Connecting: Spinner replacing Bluetooth icon, "Connecting..." subtitle
- Disconnected: Default appearance, "Paired [relative date]" subtitle
- All states show device instance ID in monospace

**Popup Menu Options (per device):**

| Option | Condition | Action |
|--------|-----------|--------|
| "Connect" | Disconnected and not connecting | Initiates BLE connection using `deviceInstanceId` as MAC address |
| "Disconnect" | Connected | Disconnects from device |
| "Rename" | Always | Opens rename dialog (max 32 chars) |
| "Unpair" | Always | Opens unpair confirmation with factory reset instructions |

**Tap-to-connect:** Tapping a disconnected device tile initiates connection directly (same as "Connect" menu option).

**Feedback:**
- Connection success: SnackBar "[Device name] connected" and auto-navigates back
- Connection error: SnackBar with error message

**Dialogs:**

| Dialog | Content | Actions |
|--------|---------|---------|
| Rename Device | Text field with current name, max 32 characters | "Cancel", "Save" |
| Unpair Device | Warning about factory reset instructions ("Hold A+B for 7 seconds") | "Cancel", "Remove from List" |

---

## Phase 4: BLE Service Updates

```dart
Future<HandshakeResult> sendHandshake({
  required String uid,
  required int syncSeq,
}) async {
  final response = await sendCommand({
    'cmd': 'handshake',
    'uid': uid,
    'sync_seq': syncSeq,
  });

  SyncStatus status;
  switch (response['status']) {
    case 'in_sync':
      status = SyncStatus.inSync;
      break;
    case 'wrong_account':
      status = SyncStatus.wrongAccount;
      break;
    case 'uninitialized':
      status = SyncStatus.uninitialized;
      break;
    default:  // 'conflict'
      status = SyncStatus.conflict;
  }

  return HandshakeResult(
    status: status,
    deviceInstanceId: response['device_instance_id'],
    deviceSyncSeq: response['device_seq'],
    protocolVersion: response['protocol_version'],
    firmwareVersion: response['firmware_version'],
  );
}

Future<OverrideResult> sendOverrideChunked({
  required int syncSeq,
  required int selectedId,
  required List<Item> items,
}) async {
  // Chunk items (e.g., 10 items per chunk to fit BLE MTU)
  const chunkSize = 10;
  final chunks = <List<Item>>[];
  for (var i = 0; i < items.length; i += chunkSize) {
    chunks.add(items.sublist(i, min(i + chunkSize, items.length)));
  }

  // Send override_start (uid included for uninitialized devices to store pairing)
  await sendCommand({
    'cmd': 'override_start',
    'uid': uid,
    'sync_seq': syncSeq,
    'total_chunks': chunks.length,
  });

  // Send each chunk
  // Note: Chunks don't have individual responses - device validates at override_end
  // If a chunk fails (BLE error), sendCommand will throw and abort the override
  for (var i = 0; i < chunks.length; i++) {
    await sendCommand({
      'cmd': 'override_chunk',
      'index': i,
      'items': chunks[i].map((item) => item.toDeviceJson()).toList(),
    });
  }

  // Send override_end and wait for response
  // Device validates all chunks received before responding
  final response = await sendCommand({
    'cmd': 'override_end',
    'selected_id': selectedId,
  });

  return OverrideResult(
    status: response['status'],
    message: response['message'],
  );
}

Future<SyncCompleteResult> sendSyncComplete(int syncSeq) async {
  final response = await sendCommand({
    'cmd': 'sync_complete',
    'sync_seq': syncSeq,
  });

  return SyncCompleteResult(status: response['status']);
}
```

---

## Phase 5: Testing

### Manual Test Scenarios

| # | Scenario | Expected |
|---|----------|----------|
| 1 | Fresh device pairs to account | `uninitialized` → setup dialog → override stores uid, sync_seq=1 |
| 2 | Same device reconnects | sync_seq matches → device is SOT → normal sync |
| 3 | Different device connects | sync_seq mismatch → conflict dialog with device name/ID |
| 4 | Confirm override | App data pushed to device (chunked), sync_seq increments |
| 5 | Cancel conflict dialog | BLE disconnects, device returns to normal |
| 6 | Factory reset device | Re-uses BLE MAC as instance_id, enters uninitialized state |
| 7 | Re-pair after factory reset | `uninitialized` → setup dialog → override as new device |
| 8 | Reach 10 device limit | Error shown, pairing rejected |
| 9 | Unpair from app | Removed from list, device still paired until factory reset |
| 10 | BLE disconnect during normal sync | Partial data discarded, reconnect restarts sync cleanly |
| 11 | BLE disconnect during override | On reconnect, conflict detected again, override restarts |
| 12 | sync_complete not acknowledged | Retry or fail gracefully, don't update Firestore |
| 13 | Try to create item while disconnected | UI prevents item creation (disabled or error message) |
| 14 | Try to sync >100 items | Error shown before sync attempt |
| 15 | Connect to device paired to different account | `wrong_account` → dialog with recovery instructions, BLE disconnects |
| 16 | Override when app has 0 items | Device clears all items successfully, sync_seq increments |
| 17 | Try to sync without internet | Error: "Internet connection required to sync." |
| 18 | Firestore update fails after device ack | Retry up to 3 times, then show error prompting user to retry |
| 19 | Connect from Paired Devices page | Tap device tile or "Connect" menu → connects using BLE MAC address |
| 20 | Connect to different device while one is connected | Auto-disconnects current device, connects to new one |

---

## Implementation Order

### Sprint 1: Firmware Preparation
1. Rename device_id → device_item_id throughout firmware
2. Rename device_id → device_item_id in app BLE parsing
3. Test existing functionality still works

### Sprint 2: Firmware Core
1. NVS storage for paired_uid, device_instance_id, sync_seq_no
2. Device instance ID generation (and regeneration on factory reset)
3. Pairing mode detection
4. Single-account lock
5. Factory reset updates

### Sprint 3: Firmware Protocol
1. Handshake message handling
2. Conflict state (SEE APP display, disable buttons, exit on disconnect)
3. Override message handling
4. Sync complete message handling

### Sprint 4: App Core
1. Firestore schema (sync_sequence_no, paired_devices)
2. Handshake BLE command
3. Updated sync flow with handshake
4. Override BLE command
5. Sync complete BLE command
6. Internet connectivity check before sync/override
7. Firestore update retry logic (3 attempts with backoff)

### Sprint 5: App UI
1. Conflict resolution dialog
2. Paired devices page
3. Device rename functionality
4. Unpair functionality
5. Device limit check

---

## Summary

**The key insight:** `sync_seq` alone determines if a device is in sync or needs override. No need to track which device was last used - if the numbers match, it was this device.

**Flow summary:**
1. App checks internet connectivity (required for Firestore)
2. App fetches FRESH sync_seq from Firestore (not cached - supports multi-instance)
3. App sends handshake with uid + sync_seq
4. Device responds with one of four statuses:
   - `in_sync` → normal sync (device → app), then sync_complete with acknowledgment
   - `conflict` → user confirms via SyncConflictDialog → override (app → device, chunked)
   - `uninitialized` → user confirms via DeviceSetupDialog → override (pairs + syncs)
   - `wrong_account` → WrongAccountDialog → disconnect
5. Either way, sync_seq increments and both sides store it
6. Firestore only updated AFTER device acknowledgment (with retry on failure)
7. All BLE commands have 10-second timeout
8. All handshake responses include `protocol_version` and `firmware_version` for compatibility

**Key constraints:**
- Sync requires internet connection (for Firestore access)
- Items can only be created while BLE connected
- Maximum 100 items per account (device slot limit)
- Maximum 10 paired devices per account
- Override uses chunked messages for BLE MTU compatibility
- Device instance ID is BLE MAC address (not generated UUID)
- Users can connect to paired devices directly from Paired Devices page
