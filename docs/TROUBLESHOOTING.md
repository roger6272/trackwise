# Troubleshooting Playbook

> Quick diagnostic guides for common issues. Check here before diving into code.
>
> **Related docs:** [BLE Protocol](BLE_PROTOCOL.md) · [Data Flow](DATA_FLOW.md) · [Device Display](DEVICE_DISPLAY.md)

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
| Device not advertising as expected | Device advertises as `"Traxelos_One"` |
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

### 5.3 "timezone offset always reads as 0"

**Symptoms:** Daily reset always happens at UTC midnight regardless of timezone sent by app. Device `localTime` is always UTC.

**Root Cause:** NVS key mismatch — `set_time` handler wrote the offset to `"tz_offset"` but `updateLocalTime()` read from `"timezone_offset"`. The read always returned the default (0).

**Fix:** Changed `updateLocalTime()` to read from `"tz_offset"` to match the write key (commit fixing this).

**Key Lesson:** When using NVS key-value storage, grep for the key string across the entire firmware to ensure reads and writes use the same key. A typo in either location silently returns the default value with no error.

---

### 5.4 "todaycount resets to 0 after power cycle"

**Symptoms:** Today's count shows 0 after turning the device off and on, even though it's the same day.

**Root Cause:** On boot, the RTC may have lost power and defaults to compile time. The daily reset check (`resetTodayCountsIfNeeded()`) compared the stale RTC date against `last_reset_date` in NVS, saw a mismatch, and reset all `todaycount` values to 0 before the app could send `set_time`.

**Fix:** Deferred the daily reset check from `setup()` — it now only runs after `set_time` is received from the app, when the RTC has a valid time.

**Key Lesson:** Never run date-dependent logic on boot before the clock source is validated. If the RTC is battery-backed but may lose power, treat its time as untrusted until the app confirms it.

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

Use `AppLogger` from `core/utils/logger.dart` (never raw `print`/`debugPrint`):
```dart
// Log raw received bytes
notifyStream.listen((data) {
  AppLogger.debug('BLE RX (${data.length} bytes): ${String.fromCharCodes(data)}');
});

// Log parsed messages
AppLogger.debug('BLE MSG: ${message.type} - ${jsonEncode(message.data)}');

// Log commands sent
AppLogger.debug('BLE TX: $command');
```

All `AppLogger` output is compiled out in release builds (guarded by `kDebugMode`).

### 8.2 Device-side Logging

Firmware serial logging is **off by default**. To enable:
1. Uncomment `#define DEBUG` at the top of `Trackwise_ESP32.ino`
2. Flash firmware
3. Connect serial monitor at 115200 baud

Firmware logs (when DEBUG enabled):
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

### 9.2 "Duplicate prefs sent after item move"

**Symptoms:** Moving an item out of the selected item's category sends prefs correctly, but the next count increment triggers another unnecessary prefs send.

**Root Cause:** Debounce logic skipped the sync **and** skipped updating the signature. The Firestore stream confirmation arrived within 500ms (debounced), but with slightly different `categoryOrder` values than the optimistic state. The stale `_lastSyncedSignature` persisted, and the next unrelated state change (count increment) saw a mismatch and triggered a duplicate sync.

**Pattern:** Move triggers sync (signature updated) → Firestore confirms within 500ms with reordered `categoryOrder` → debounce skips sync AND skips signature update → next `buildWhen` (from count increment) sees stale signature mismatch → unnecessary duplicate sync.

**Fix Applied:** Always update `_lastSyncedSignature` and `_lastSyncedCategoryId` regardless of debounce. Only the actual send is debounced.

**Key Lesson:** Debounce should defer sending, not defer acknowledging state. Always update the baseline signature so future comparisons are against the latest known state.

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

**Fix Applied:** Migration (`ensureDeviceItemIds`) runs on startup. All model update paths now preserve `deviceItemId` — including `resetAllItems` which was missing it (caused all items to get `id:0` after reset).

**Key Lesson:** Any nullable field used as an ID must have a migration path. Default values (like `?? 0`) silently mask the problem. When adding a field, grep for ALL `ItemModel(` constructors — every path that builds an item must include it.

---

### 9.5 "Override changes the selected item"

**Symptoms:** After reconnect + override, both app and device show a different selected item than before disconnect

**Root Cause:** Two independent state sources track "selected item":
- `AppUiState.activeItemId` (SharedPreferences, Firestore ID string) — set only on manual pin swipe
- `BluetoothState.selectedItemId` (BLoC, Firestore ID string) — set from device prefs notifications

When the device changes selection (e.g., via button press), only `BluetoothState.selectedItemId` updates. `AppUiState.activeItemId` stays stale. On reconnect → conflict → override, the dialog reads `AppUiState.activeItemId`, sending the wrong item to the device.

**Fix Applied:** Added a `BlocListener` that syncs `AppUiState.activeItemId` whenever `BluetoothState.selectedItemId` changes (from prefs, override, or any source).

**Key Lesson:** When two state sources track the same concept, always keep them in sync. One should be the source of truth and the other should mirror it.

---

### 9.6 "Device has items from wrong category after reset/sync"

**Symptoms:** After reset (or other bulk operation), pressing S on device cycles through items from multiple categories instead of staying in one.

**Root Cause:** The code path that sends items to the device after the operation bypasses the category filter.

**Pattern:** The normal `buildWhen` path in `items_list_page` always filters items by the selected item's category. But other code paths (reset, restore, future bulk operations) may call `SendItemsToDevice` directly with an unfiltered list.

**Fix Applied:** Extracted shared `syncItemsToDevice()` helper in `device_sync_helper.dart`. All callers (items_list_page, profile_page, deleted_items_page) now use this single function, which always filters by the selected item's category.

**Key Lesson:** Every path that sends items to the device must filter by the selected item's category. Always use `syncItemsToDevice()` from `device_sync_helper.dart` — never call `SendItemsToDevice` directly with unfiltered items.

---

### 9.7 "Device stuck on old category after drag across categories"

**Symptoms:** After Start New Cycle (or any action that causes `ItemsLoading` → `ItemsLoaded`), dragging the selected item to a different category doesn't update the device. The S button still cycles through the old category.

**Root Cause:** `buildWhen` sync tracking (`_lastSyncedSignature`) was null after an `ItemsLoading` → `ItemsLoaded` transition. The sync tracking block only runs when `previous is ItemsLoaded && current is ItemsLoaded`. After returning from the profile page, the state often passes through `ItemsLoading` (stream reconnect/reload), which means the sync block is skipped and `_lastSyncedSignature` stays null.

**Pattern:**
1. Start New Cycle on profile page → device gets Category A items
2. Return to items list → state goes `ItemsLoading` → `ItemsLoaded` → sync block skipped, `_lastSyncedSignature` stays null
3. Drag selected item from Category A → Category B → optimistic update emits
4. `buildWhen` fires → `_lastSyncedSignature` is null → old INIT branch just initialized without syncing → set `_lastSyncedCategoryId = B`
5. All subsequent `buildWhen` calls see `catChanged=false` → no sync ever fires
6. Device stuck on Category A

**Fix Applied:** Removed the INIT special case from `buildWhen`. When `_lastSyncedSignature` is null, the normal comparison `currentSignature != null` evaluates to `signatureChanged=true`, triggering a sync. Trade-off: one redundant (but harmless) sync on initial page load.

**Key Lesson:** Any state tracked inside `buildWhen` that only updates during `ItemsLoaded → ItemsLoaded` transitions will become stale after `ItemsLoading` interruptions. Don't assume tracking state is always initialized — handle the null/uninitialized case as "needs sync", not "skip sync".

---

### 9.8 "Missing fields in manually constructed ItemModel"

**Symptoms:** Items lose `deviceItemId` (or other fields) after certain operations, causing all items to show as `id:0` on device.

**Root Cause:** Manual `ItemModel(...)` constructors forget to include all 18+ fields. When a new field is added, existing constructors silently use the default value (often `null` or `0`).

**Fix Applied:** `resetAllItems` now uses `ItemModel.fromFirestore(doc).copyWith(count: 0, ...)` instead of manual construction. The factory method captures all fields; `copyWith` overrides only the ones that change.

**Key Lesson:** Never manually construct `ItemModel` from raw Firestore data when `ItemModel.fromFirestore(doc)` already does it correctly. Use `fromFirestore` + `copyWith` to ensure future fields are preserved.

---

### 9.9 "Unnecessary device sync after navigating back from another page"

**Symptoms:** After navigating to another page (e.g., item form, profile) and returning, the device receives a full item list even though nothing changed. Most visible when creating an item in a *different* category — the device gets an update it doesn't need.

**Root Cause:** Navigating away triggers `ItemsLoading` (stream re-subscribe), which resets `_lastSyncedSignature` to `null`. When `ItemsLoaded` arrives on return, `buildWhen` sees `signatureChanged = (currentSignature != null) = true` and syncs unconditionally.

This is a recurring pattern: **any code path that passes through `ItemsLoading` wipes the tracking state**, so the next `ItemsLoaded → ItemsLoaded` transition looks like a change.

**Fix Applied:** Split `buildWhen` into two branches:
- `ItemsLoaded → ItemsLoaded`: call `_checkDeviceSync()` (compare signature, debounce, sync if changed)
- `non-ItemsLoaded → ItemsLoaded` with `_lastSyncedSignature == null`: call `_initSyncTracking()` (set baseline signature *without* syncing)

This ensures the first `ItemsLoaded` after navigation establishes a baseline, and only *actual* changes trigger device sync.

**Key Lesson:** When tracking state (`_lastSyncedSignature`) is used to detect changes, every transition that resets it must re-initialize it *without* treating the reset as a change. Watch for `ItemsLoading` transitions — they are the most common source of null tracking state. The pattern is: **initialize tracking on state recovery, sync on state change**.

**Related:** Section 9.7 (same null-signature root cause, different trigger — Start New Cycle instead of navigation).

---

### 9.10 "Device not updated after category deletion" / "Empty item list after deleting viewed category"

**Symptoms (device):** After deleting a category from Manage Categories, the device still shows the old category's items. The S button cycles through stale items until the user manually navigates back to the items list.

**Symptoms (UI):** If the user was viewing the deleted category's items, returning to the items list shows "All Categories" in the dropdown but an empty list.

**Root Cause (device):** Category deletion happens on `manage_categories_page` (under the Profile tab). The items list page is disposed on tab switch (`ShellRoute`, not `StatefulShellRoute`), so `buildWhen` can't detect the change. When the page is recreated, `_initSyncTracking` sets a baseline from the already-changed items (now uncategorized) — no diff is detected, no sync fires.

**Root Cause (UI):** The dropdown resets `validCategoryId` to `null` visually when the category is gone, but the BLoC's `selectedCategoryId` still holds the deleted category's ID. `getFilteredItemsWithCategoryOrder` filters by the stale ID, finding zero items.

**Fix Applied:**
- **Device:** `manage_categories_page` now calls `_syncDeviceAfterCategoryDeletion()` immediately after dispatching `DeleteCategoryEvent`. It waits 500ms for the Firestore batch to clear `category_id`, fetches updated items, and syncs the device if the selected item was in the deleted category.
- **UI:** `_buildCategoryDropdown` fires `FilterByCategoryEvent(null)` via `addPostFrameCallback` when the selected category no longer exists, resetting both the BLoC filter and `AppUiState`.

**Key Lesson:** When the items list page can be disposed during an operation (tab navigation), don't rely on `buildWhen` to detect changes. Sync the device from the page where the operation happens. Also, visual-only resets (dropdown display) must be accompanied by state resets (BLoC + AppUiState).

---

### 9.11 Debugging Checklist: App → Device Sync

When items aren't syncing correctly, check in this order:

1. **Does the item have `device_item_id` in Firestore?** (null = not synced)
2. **Is the item in the selected item's category?** (only same-category items sync)
3. **Is the sync going through `syncItemsToDevice()`?** (direct `SendItemsToDevice` bypasses category filter)
4. **Was the sync debounced?** (check `_lastSyncTime` - 500ms window; category changes bypass debounce)
5. **Is `_lastSyncedSignature` null?** (happens after any `ItemsLoading` state — should trigger sync, not skip it)
6. **Is the Firestore stream up-to-date?** (check `current.items` in `buildWhen`)
7. **Which `selectedItemId` source is being used?** (check debug logs for resolution chain)
8. **Was `_lastSyncedSignature` updated without syncing?** (debounce bug pattern)
9. **Was tracking updated after an explicit sync?** (explicit sync + stream sync = duplicate; update `_lastSyncedSignature`/`_lastSyncedCategoryId`/`_lastSyncTime` after every explicit `_syncDeviceWithSelectedCategory` call)

### 9.12 "Stream errors crash categories watcher"

**Symptoms:** Categories stop updating after a transient Firestore error. App may show stale category list or empty state.

**Root Cause:** `watchCategories()` in `category_repository_impl.dart` used `.handleError()` + `throw error`, which terminates the stream. Unlike `watchItems()` which used `.onErrorResume()` to wrap errors in `Left(ServerFailure(...))` and keep the stream alive.

**Fix Applied:** Changed `watchCategories()` to use `.onErrorResume()` matching the items pattern, so errors are emitted as `Left` values instead of killing the stream.

**Key Lesson:** Repository stream methods should always use `onErrorResume` (not `handleError` + rethrow) to convert exceptions into `Left` values. Rethrowing terminates the stream permanently.

---

### 9.13 "Email empty on Edit Profile after Google sign-in"

**Symptoms:** Edit Profile page shows empty email field even though user signed in with Google.

**Root Cause:** `getProfile()` in `profile_remote_datasource_impl.dart` merges Firebase Auth data into the Firestore profile using `copyWith()`, but only merged `displayName` and `photoUrl` — not `email`. If Firestore had a blank email field, the Firebase Auth email was ignored.

**Fix Applied:** Added `email: user.email ?? firestoreProfile.email` to the `copyWith()` call.

**Key Lesson:** When merging data from two sources (Firebase Auth + Firestore), ensure all fields are included in the merge. Missing a field silently returns the empty/default value.

### 9.14 "Sticky header shows wrong category when first category is empty"

**Symptoms:** In the "All Categories" view, scrolling up replaces the first (empty) category's header with the second category's name. The sticky header at the top shows the wrong category.

**Root Cause:** `_calculateStickyCategory()` in `items_list_page.dart` only iterated over `filteredItems` (actual items), completely ignoring empty category labels. The actual list includes empty categories as label entries (for drag-drop zones), but the offset calculation didn't account for their height. So when the first category had no items, the method started at the first item's category (the second one).

**Fix Applied:** Rewrote `_calculateStickyCategory()` to iterate through all categories from `_cachedCategoryOrder` (including empty ones) in the same order as the actual list layout, properly accounting for empty category label heights.

**Key Lesson:** When calculating scroll-based positions for a list, the calculation must match the actual list structure exactly — including non-data entries like empty section headers.

---

### 9.15 "Wrong account / sync conflict dialog shows twice during onboarding"

**Symptoms:** During onboarding device pairing, the "Wrong Account" or "Sync Conflict" dialog appears twice, stacked on top of each other.

**Root Cause:** Two independent listeners were both showing the same dialog. `main.dart` has global `BlocListener`s (with proper `listenWhen` guards) for `hasWrongAccount`, `hasConflict`, and `needsSetup`. `onboarding_step_device.dart` had its own duplicate listeners for wrong account and conflict, with inline dialog implementations. During onboarding, both widgets are in the tree, so both fired.

**Fix Applied:** Removed the duplicate wrong account and conflict dialog handling from `onboarding_step_device.dart`. The global listeners in `main.dart` already handle these for all pages, including onboarding.

**Key Lesson:** When `main.dart` has global `BlocListener`s for a state flag, don't add page-level listeners for the same flag. Check `main.dart` first before adding dialog-showing listeners to individual pages/widgets.

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
| Override selects wrong item | Check AppUiState vs BluetoothState selectedItemId sync |
| Wrong category after drag | Check `_lastSyncedSignature` null after `ItemsLoading` transition |
| Wrong category after reset | Ensure sync goes through `syncItemsToDevice()`, not raw `SendItemsToDevice` |
| Dialog shows twice | Guard `BlocConsumer.listener` with `listenWhen` or tracking boolean |
| Items missing deviceItemId | Use `fromFirestore` + `copyWith`, not manual `ItemModel(...)` |
| Multiple items with id=0 | Check device_item_id in Firestore (null?) |
| Unnecessary sync after navigation | `_lastSyncedSignature` null after `ItemsLoading` — needs `_initSyncTracking` |
| Device stale after category deletion | Sync from `manage_categories_page`, not `buildWhen` (page disposed on tab switch) |
| Empty list after deleting viewed category | Reset BLoC filter with `FilterByCategoryEvent(null)` when category is gone |
| Duplicate device sync | Explicit sync missing tracking update — `buildWhen` re-syncs on stream |
| Sync silently lost | Check debounce signature update logic |
| S button crosses categories | Check if sync path filters by selected category |
| Categories stop updating | Stream killed by rethrow — use `onErrorResume` not `handleError` |
| Email empty after Google sign-in | `getProfile()` missing email in `copyWith()` merge |
| Sticky header wrong category | `_calculateStickyCategory` ignores empty categories — must match list layout |
