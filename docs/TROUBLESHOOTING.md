# Troubleshooting Playbook

> Quick diagnostic guides for common issues. Check here before diving into code.

---

## Table of Contents

1. [Connection Issues](#1-connection-issues)
2. [Sync Issues](#2-sync-issues)
3. [Count Mismatch Issues](#3-count-mismatch-issues)
4. [Notification Issues](#4-notification-issues)
5. [Daily Reset Issues](#5-daily-reset-issues)
6. [Device State Issues](#6-device-state-issues)
7. [Performance Issues](#7-performance-issues)
8. [Diagnostic Tools](#8-diagnostic-tools)
9. [App-Side Sync Pitfalls](#9-app-side-sync-pitfalls)

---

## 1. Connection Issues

### 1.1 "Can't find device"

**Symptoms:** Device doesn't appear in scan results

**Diagnostic Steps:**
1. Is device powered on? Check for LED/display activity
2. Is device already connected to another phone? (BLE is 1:1)
3. Is Bluetooth enabled on phone?
4. Is location permission granted? (Required for BLE on Android)

**Common Causes:**
| Cause | Solution |
|-------|----------|
| Device in low power mode | Press any button to wake it |
| Already connected elsewhere | Disconnect from other phone first |
| Device name filter wrong | Should be `"Traxelos"` |
| Android location permission | Request `ACCESS_FINE_LOCATION` |

---

### 1.2 "GATT 133 Error" (Android)

**Symptoms:** Connection fails with error code 133

**Diagnostic Steps:**
1. Was scan stopped before connecting?
2. Was there a 2-second delay after stopping scan?
3. How many retry attempts?

**Root Cause:** Android BLE stack race condition when scan overlaps connect

**Solution:**
```dart
await stopScan();
await Future.delayed(Duration(seconds: 2));  // Critical!
await connect(device);
```

**If still failing:**
- Clear Bluetooth cache: Settings → Apps → Bluetooth → Clear Cache
- Toggle Bluetooth off/on
- Restart phone (last resort)

---

### 1.3 "Connection drops immediately"

**Symptoms:** Connects then disconnects within seconds

**Diagnostic Steps:**
1. Check signal strength (RSSI) - should be > -80 dBm
2. Check if MTU negotiation completed
3. Check if service discovery completed
4. Check if NOTIFY subscription succeeded

**Common Causes:**
| Cause | Solution |
|-------|----------|
| Weak signal | Move closer to device |
| MTU negotiation failed | Fallback to 180 MTU |
| Missing characteristics | Check firmware version compatibility |
| Phone BLE stack busy | Wait and retry |

---

### 1.4 "Missing characteristics"

**Symptoms:** Service discovery succeeds but can't find expected characteristics

**Diagnostic Steps:**
1. Verify service UUID: `12345678-1234-1234-1234-123456789000`
2. Check all 4 characteristics found:
   - CHAR_READ: `...001`
   - CHAR_NOTIFY: `...002`
   - CHAR_SET_ITEMS: `...008`
   - CHAR_WRITE: `...010`

**Common Causes:**
| Cause | Solution |
|-------|----------|
| Firmware outdated | Update device firmware |
| Partial discovery | Retry service discovery |
| UUID mismatch | Check `bluetooth_constants.dart` |

---

## 2. Sync Issues

### 2.1 "Handshake returns 'conflict'"

**Symptoms:** Device shows "SEE APP", buttons disabled

**This is expected behavior when:**
- Device was used with a different phone
- App was reinstalled
- Firestore sync_seq differs from device sync_seq

**Resolution Flow:**
1. App receives `{"status":"conflict","device_seq":N}`
2. App shows conflict dialog to user
3. User confirms override
4. App sends: `override_start` → `override_chunk(s)` → `override_end`
5. Device responds: `{"status":"override_complete"}`
6. Device shows "SYNCED", buttons re-enabled

**If override fails:**
- Check `override_end` response for `"missing_chunks"` error
- Verify all chunks were sent with correct indices
- Check BLE connection didn't drop mid-transfer

---

### 2.2 "Handshake returns 'wrong_account'"

**Symptoms:** Device paired to different user

**Root Cause:** Device's `paired_uid` doesn't match app's Firebase UID

**Resolution:**
- This device belongs to another account
- User must factory reset the device to re-pair
- Or log into the correct account

**Factory Reset:** (device-specific - check hardware docs)

---

### 2.3 "Handshake returns 'uninitialized'"

**Symptoms:** New device or after factory reset

**This is expected for:**
- Brand new device
- Device after factory reset

**Resolution Flow:**
1. App receives `{"status":"uninitialized"}`
2. App shows setup dialog
3. User confirms setup
4. App sends: `override_start` (with UID) → `override_chunk(s)` → `override_end`
5. Device stores UID, becomes paired

---

### 2.4 "sync_complete not acknowledged"

**Symptoms:** App sends `sync_complete` but doesn't receive `{"status":"seq_updated"}`

**Diagnostic Steps:**
1. Check BLE connection still active
2. Check NOTIFY subscription still active
3. Check for error notifications

**Common Causes:**
| Cause | Solution |
|-------|----------|
| Connection dropped | Reconnect and re-sync |
| Notification missed | Check message buffer for pending data |
| Command malformed | Verify JSON format and newline terminator |

---

## 3. Count Mismatch Issues

### 3.1 "App count differs from device count"

**Symptoms:** UI shows different count than device display

**Key Principle:** Device is source of truth during normal sync

**Diagnostic Steps:**
1. What was handshake result?
   - `in_sync`: Device counts should be used
   - `conflict`: Firestore counts were pushed to device
2. Did app update state from `prefs` notification?
3. Did app update Firestore from device counts?

**Common Causes:**
| Cause | Solution |
|-------|----------|
| App using stale local state | Refresh from `prefs` notification |
| Firestore not updated | Check Firestore write succeeded |
| Race condition | Wait for full sync before showing counts |

---

### 3.2 "set_items didn't update counts"

**Symptoms:** Sent new counts via `set_items`, device still shows old counts

**This is by design!** `set_items` preserves device counts for existing items.

**How set_items works:**
```
For existing items (deviceItemId found in NVS):
  - PRESERVE: count, todaycount, lastResetTime, resetNumber
  - UPDATE: name, category, increment, reminder, reminder_value

For new items (deviceItemId not found):
  - USE all values from JSON
```

**If you need to override counts:** Use the `override_chunk` protocol instead.

---

### 3.3 "Counts lost after disconnect"

**Symptoms:** Increments made on device disappeared

**Diagnostic Steps:**
1. How many increments were made before disconnect?
2. Was disconnect graceful or abrupt (power loss)?

**Root Cause:** NVS writes are batched every 10 increments

**What happens:**
- Increments 1-9: Stored in RAM only
- Increment 10: Flushed to NVS
- On disconnect: Pending RAM data flushed to NVS

**Potential data loss:** If power is cut suddenly, up to 9 increments may be lost.

**Mitigation:** The 5-minute periodic flush reduces this window.

---

## 4. Notification Issues

### 4.1 "Not receiving notifications"

**Symptoms:** Device buttons work but app doesn't update

**Diagnostic Steps:**
1. Is NOTIFY characteristic subscribed?
2. Is notification callback registered?
3. Is BLE connection still active?
4. Check raw bytes received (log them)

**Common Causes:**
| Cause | Solution |
|-------|----------|
| Not subscribed | Call `setNotifyValue(true)` on CHAR_NOTIFY |
| Callback not set | Register listener before subscribing |
| Connection dropped | Reconnect and resubscribe |
| Buffer overflow | Check message reassembly logic |

---

### 4.2 "Notifications are garbled/incomplete"

**Symptoms:** JSON parse errors, partial messages

**Diagnostic Steps:**
1. Log raw bytes as they arrive
2. Check for newline delimiter (`\n`)
3. Check message reassembly buffer

**Root Cause:** Large messages are chunked (~180 bytes each)

**Reassembly Logic:**
```dart
// Accumulate chunks until newline
buffer += String.fromCharCodes(data);
if (buffer.contains('\n')) {
  final message = buffer.substring(0, buffer.indexOf('\n'));
  buffer = buffer.substring(buffer.indexOf('\n') + 1);
  // Parse message as JSON
}
```

**Common Causes:**
| Cause | Solution |
|-------|----------|
| Not accumulating chunks | Implement buffer |
| Missing newline check | Wait for `\n` before parsing |
| Buffer not cleared | Clear after extracting message |
| Timeout (5s) on device | Send chunks faster |

---

### 4.3 "Receiving event but not item_delta (or vice versa)"

**Symptoms:** Only one notification type received per button press

**Understanding the pairing:**

| Action | `event` sent? | `item_delta` sent? |
|--------|:-------------:|:------------------:|
| Increment button | ✓ | ✓ |
| Reset button | ✓ | ✓ |
| Switch button | ✓ | ✗ |
| set_selected command | ✗ | ✓ |

**If missing one:**
- Check they're being sent 50ms apart (device adds delay)
- Check message buffer isn't dropping messages
- Check notification listener handles multiple rapid notifications

---

## 5. Daily Reset Issues

### 5.1 "todaycount not resetting at midnight"

**Symptoms:** Daily progress doesn't reset

**Diagnostic Steps:**
1. What timezone is stored on device?
2. When was `set_time` last called?
3. What is `last_reset_date` in NVS?

**Common Causes:**
| Cause | Solution |
|-------|----------|
| Timezone not set | Send `set_time` after every connect |
| Wrong timezone offset | Check `offset` calculation (minutes from UTC) |
| Device clock drifted | Send `set_time` to resync |
| Crossed midnight while disconnected | Device checks every 60s, should self-correct |

**Timezone offset examples:**
| Timezone | Offset (minutes) |
|----------|------------------|
| UTC | 0 |
| EST (UTC-5) | -300 |
| PST (UTC-8) | -480 |
| IST (UTC+5:30) | 330 |

---

### 5.2 "todaycount reset at wrong time"

**Symptoms:** Reset happens at wrong hour

**Root Cause:** Timezone offset incorrect

**Diagnostic Steps:**
1. What offset is app sending?
2. What offset is stored in device NVS?
3. Calculate expected reset time: midnight local = midnight UTC + offset

**Fix:**
```dart
final offset = DateTime.now().timeZoneOffset.inMinutes;
// Send this with set_time command
```

---

## 6. Device State Issues

### 6.1 "Device stuck showing 'SEE APP'"

**Symptoms:** Device in conflict state, buttons don't work

**Root Cause:** Handshake detected sync_seq mismatch

**Resolution:**
1. Complete the override protocol in app
2. OR disconnect (device will exit conflict state on disconnect)
3. Reconnect to retry sync

**If app can't complete override:**
- Check BLE connection stable
- Check all override_chunks sent
- Check override_end response

---

### 6.2 "Device stuck showing 'AWAITING SETUP'"

**Symptoms:** Device unpaired, waiting for initial setup

**Resolution:**
1. Complete the override protocol with UID
2. `override_start` stores the UID, pairing the device

---

### 6.3 "Device not responding to commands"

**Symptoms:** Commands sent but no response/action

**Diagnostic Steps:**
1. Is device in conflict state? (buttons disabled)
2. Is command sent to correct characteristic?
   - Commands → CHAR_WRITE (`...010`)
   - Item array → CHAR_SET_ITEMS (`...008`)
3. Does command end with `\n` (newline)?
4. Is JSON valid?

**Common Causes:**
| Cause | Solution |
|-------|----------|
| Wrong characteristic | Route to correct UUID |
| Missing newline | Append `\n` to command |
| Invalid JSON | Validate before sending |
| Conflict state | Complete override or disconnect |

---

## 7. Performance Issues

### 7.1 "Sync is slow"

**Symptoms:** Initial sync takes long time

**Factors affecting speed:**
| Factor | Impact | Optimization |
|--------|--------|--------------|
| MTU size | Higher = fewer chunks | Request 512 MTU |
| Item count | More items = more data | Paginate if >50 items |
| Log count | More logs = more pages | Clear logs after sync |
| Connection priority | Higher = faster | Set HIGH priority |

---

### 7.2 "Chunked transfer failing"

**Symptoms:** Large payloads (set_items, override) fail

**Diagnostic Steps:**
1. How big is the payload?
2. How many chunks?
3. Is 20ms delay between chunks?
4. Any timeout errors?

**Limits:**
| Buffer | Max Size |
|--------|----------|
| CHAR_SET_ITEMS | 32KB |
| CHAR_WRITE | 8KB |
| Single chunk | MTU - 3 bytes |

**Common Causes:**
| Cause | Solution |
|-------|----------|
| Payload too large | Reduce item count or split |
| Chunks too fast | Ensure 20ms delay between |
| Timeout (5s) | Complete transfer faster |
| BLE congestion | Increase chunk delay |

---

## 8. Diagnostic Tools

### 8.1 App-side Logging

Add to BLE datasource:
```dart
// Log raw received bytes
notifyStream.listen((data) {
  debugPrint('BLE RX (${data.length} bytes): ${String.fromCharCodes(data)}');
});

// Log parsed messages
debugPrint('BLE MSG: ${message.type} - ${jsonEncode(message.data)}');

// Log commands sent
debugPrint('BLE TX: $command');
```

### 8.2 Device-side Logging

Connect serial monitor at 115200 baud. Firmware logs:
- All BLE events
- Command parsing
- NVS operations
- State transitions

### 8.3 Useful Debug Commands

**Check device state:**
```json
{"cmd": "prepare_read", "type": "prefs", "page": 0}
```

**Force daily reset (testing):**
```json
{"cmd": "force_reset_today"}
```

### 8.4 Quick Health Check Sequence

1. Connect
2. Send `handshake` → expect status response
3. If `in_sync`: expect `prefs` and `logs` automatically
4. Send `set_time` → silent success
5. Send `set_selected` with valid ID → expect `item_delta`

If all 5 work, BLE communication is healthy.

---

## 9. App-Side Sync Pitfalls

> Patterns that have caused bugs in the sync layer. Check here when items aren't syncing correctly.

### 9.1 "Newly created item not sent to device"

**Symptoms:** Item exists in Firestore but device doesn't have it

**Root Cause:** Firestore stream hasn't emitted the new item when the sync triggers.

**Pattern:** `createItem` writes to Firestore → `context.pop()` navigates back → `buildWhen` fires with **stale** items list → sync sends old list without new item → Firestore stream emits later but sync already happened.

**Fix Applied:** `ItemFormPage` returns the created item via `context.pop(createdItem)`. `items_list_page` passes it to `_syncDeviceWithSelectedCategory(includeItem: createdItem)`.

**Key Lesson:** Any operation that modifies Firestore and triggers a sync must explicitly pass the changed data. Don't rely on the Firestore stream being up-to-date immediately.

---

### 9.2 "Sync debounce swallows changes"

**Symptoms:** Item config changed but device never updates

**Root Cause:** Debounce logic updated the signature even when skipping the sync.

**Pattern:** Change A triggers sync (signature updated) → Change B arrives within 500ms → debounce skips sync but **updates signature** → future `buildWhen` sees matching signature → change B is permanently lost.

**Fix Applied:** Only update `_lastSyncedSignature` after a successful sync, never during debounce.

**Key Lesson:** Debounce should defer work, not discard it. Never mark state as "done" when you skipped the work.

---

### 9.3 "Override selects wrong item"

**Symptoms:** After conflict override, device shows different item than app

**Root Cause:** Multiple "selected item" sources with different staleness.

**Selection resolution chain:**
1. `event.currentSelectedItemId` (from `AppUiState.activeItemId` - user's last swipe)
2. `state.selectedItemId` (BluetoothBloc - from last device prefs notification)
3. `user.lastSelectedDeviceItemId` (Firestore - from last sync)
4. First item in category (fallback)

**Common issue:** If step 1 is null/empty (e.g., dialog didn't pass it), falls through to stale values from previous sessions.

**Fix Applied:** All conflict dialog paths now pass `AppUiState.activeItemId`.

**Key Lesson:** When multiple state sources exist for the same concept, always trace which one is used. Add debug logging at the resolution point.

---

### 9.4 "Multiple items with deviceItemId=0"

**Symptoms:** Device logs show multiple items sharing the same ID

**Root Cause:** Items with `null` deviceItemId default to `0` in `_formatItemsForEsp32`:
```dart
'id': item.deviceItemId ?? 0  // null becomes 0
```

**Common causes of null deviceItemId:**
- Legacy items created before the feature was added
- `updateItem` / `incrementItem` not preserving the field

**Fix Applied:** Migration (`ensureDeviceItemIds`) runs on startup. All model update paths now preserve `deviceItemId`.

**Key Lesson:** Any nullable field used as an ID must have a migration path. Default values (like `?? 0`) silently mask the problem.

---

### 9.5 Debugging Checklist: App → Device Sync

When items aren't syncing correctly, check in this order:

1. **Does the item have `device_item_id` in Firestore?** (null = not synced)
2. **Is the item in the selected item's category?** (only same-category items sync)
3. **Was the sync debounced?** (check `_lastSyncTime` - 500ms window)
4. **Is the Firestore stream up-to-date?** (check `current.items` in `buildWhen`)
5. **Which `selectedItemId` source is being used?** (check debug logs for resolution chain)
6. **Was `_lastSyncedSignature` updated without syncing?** (debounce bug pattern)

---

## Quick Reference: Error → Solution

| Error/Symptom | First Thing to Check |
|---------------|---------------------|
| Can't find device | Is it powered on? Already connected elsewhere? |
| GATT 133 | Stop scan, wait 2s, then connect |
| Conflict status | Expected - complete override protocol |
| Wrong account | Factory reset device or use correct account |
| Counts don't match | Device is source of truth - use prefs response |
| set_items didn't update | By design - use override for count changes |
| No notifications | Check NOTIFY subscription |
| Garbled JSON | Check chunk reassembly and newline delimiter |
| Daily reset wrong time | Check timezone offset |
| Device not responding | Check conflict state and command format |
| New item not on device | Firestore stream timing - check includeItem path |
| Override selects wrong item | Check which selectedItemId source is used |
| Multiple items with id=0 | Check device_item_id in Firestore (null?) |
| Sync silently lost | Check debounce signature update logic |
