# Multi-Device BLE Code Review Findings

> **Date:** 2026-02-27
> **Branch:** `feature/multi-device-ble`
> **Range:** `b4bc25b..03dde73` (31 commits, +6329/-914 lines)
> **Status:** Review complete — 2 critical bugs, several lower-priority items

---

## Critical (Must Fix Before Merge)

### C1. Wrong device disconnect on unpair

**File:** `bluetooth_bloc.dart:1054-1066`

`_onRemovePairedDevice` uses `state.connectedDeviceInstanceId` (returns `connectedDevices.keys.first`) to check whether the device being unpaired is connected. In multi-device mode, if device A connected first and you unpair device B:

- `keys.first == event.deviceInstanceId` is false → disconnect block skipped entirely
- Device B stays connected with released claims
- Line 1066 uses `state.connectedDevice!.id` (device A's transport ID) — would disconnect the wrong device if the condition did pass

**Fix:** Replace the first-device getter with a direct map lookup:

```dart
final isConnectedDevice = state.connectedDevices.containsKey(event.deviceInstanceId);
if (isConnectedDevice) {
    _manualDisconnects.add(event.deviceInstanceId);
    _devicesToReconnect.remove(event.deviceInstanceId);
    _reconnectTimers[event.deviceInstanceId]?.cancel();
    _reconnectTimers.remove(event.deviceInstanceId);
    _reconnectAttempts.remove(event.deviceInstanceId);
    // Use the device's own BLE transport ID, not another device's
    final device = state.connectedDevices[event.deviceInstanceId]?.device;
    if (device != null) {
      await _bluetoothRepository.disconnect(device.id);
    }
}
```

---

### C2. Wrong device log pagination and clear

**Files:**
- `bluetooth_event.dart:141-157` (event definitions)
- `bluetooth_bloc.dart:804-849` (handlers)
- `bluetooth_bloc.dart:944-952` (dispatch site)

`_onMessageReceived` knows `deviceInstanceId` (line 878), but dispatches `RequestDeviceData` and `ClearDeviceLogs` without it. Both events lack a `deviceInstanceId` field. The handlers fall back to `state.connectedDevice?.id` (first device in map).

When device B sends logs, the pagination request and clear command get sent to device A.

**Fix:** Add `deviceInstanceId` to both events:

```dart
class RequestDeviceData extends BluetoothEvent {
  final DeviceDataType type;
  final int page;
  final String deviceInstanceId;
  ...
}

class ClearDeviceLogs extends BluetoothEvent {
  final String deviceInstanceId;
  ...
}
```

Update handlers to use `event.deviceInstanceId` instead of `state.connectedDevice?.id`. Update dispatch sites (lines 947, 952) to pass `deviceInstanceId`.

---

## Important (Should Fix)

### I1. Claim + release are not atomic

**File:** `bluetooth_bloc.dart:1450-1459`

Spec (Section 7.4) requires a single Firestore transaction for release + claim. Code does two separate operations. If the app crashes between them, the old item is released but the new one is never claimed.

Practical risk is low (millisecond window, self-healing on next selection), but violates the spec's atomicity guarantee.

**Fix:** Create `atomicClaimSwap` in `ItemRemoteDataSource` that releases previous + claims new in one `runTransaction`.

---

### I2. Override test never exercises claim filtering

**File:** `sync_usecase_test.dart:431-475`

Test items have no `claimedBy` set, so the claim filter at `sync_usecase.dart:434-438` is never exercised. A bug in that condition would not be caught.

**Fix:** Add test case with items where some have `claimedBy` set to another device, verify those items are excluded from the override payload.

---

### I3. `deviceInstanceId` optional in `PerformOverrideParams`

**File:** `sync_usecase.dart` — `PerformOverrideParams` class

Claim filter at line 434 is behind `if (params.deviceInstanceId != null)`. If a caller omits it, all items (including those claimed by other devices) are sent to the device.

Current call sites all pass it, but the optional type creates a trap for future callers.

**Fix:** Make `deviceInstanceId` required in `PerformOverrideParams`.

---

## Low Priority (Track for Later)

### L1. Same-device re-claim wastes a Firestore write

**File:** `item_remote_datasource_impl.dart:852-861`

When the same device claims an item it already holds, the transaction still writes. Add `if (currentClaim == deviceInstanceId) return;` to save a write.

### L2. `releaseItem` uses `FieldValue.delete()` instead of null

**File:** `item_remote_datasource_impl.dart:870-878`

Spec says `claimed_by` should be null when unclaimed, not absent. Functionally equivalent today, but could matter if Firestore Security Rules are added later.

### L3. `_onSendTimeSync` and `_onUnpairDevice` use first-device fallback

**File:** `bluetooth_bloc.dart:791, 855`

Same pattern as C2, but these are dispatched from UI contexts where single-device is the common case. Lower risk but should get `deviceInstanceId` eventually.

### L4. Invisible space character reserves tile height in single-device mode

**File:** `items_list_page.dart:1553`

`Text(claimName ?? ' ')` renders an invisible space when no claim name exists, adding unnecessary padding to all tiles in single-device mode. Replace with `SizedBox.shrink()` when null.

### L5. Hardcoded hex colors in accent bar

**File:** `items_list_page.dart:1566-1569`

`Color(0xFFB8B4FF)` etc. violate `CLAUDE.md` rule to use `AppColors`. These are pre-existing but the Phase 3 plan called for replacing them with device colors.

---

## Dismissed Findings

### ~~I3 (original): Unlock swipe in single-device mode~~

The reviewer claimed `showUnlock` should be gated on `connectedDevices.length >= 2`. On re-examination, the current behavior is correct: Activate is for unclaimed items, Unlock is for claimed items, regardless of device count. The spec says single-device claiming uses Activate, but once claimed, Unlock to release is the logical action.

### ~~I5 (original): releaseAllClaims TOCTOU race~~

Query + batch write has a theoretical window, but this only runs during unpair. The chance of a simultaneous claim in that millisecond window is near zero. Not worth the complexity of a transaction that reads N documents.

### ~~I2 (original): Device name subtitle in single-device mode~~

Spec says "no device colors on item bars" for single device. Device *names* are not explicitly excluded. Showing the device name without color tinting is informative and harmless. This is a UX judgment call, not a bug.

---

## Strengths Noted

- Clean `DeviceConnection` extraction from monolithic datasource
- Backward-compatible `BluetoothState` with computed single-device getters
- Claim filtering consistently applied in all 3 push paths (helper, refresh use case, override)
- `fromDeviceEcho` flag correctly prevents infinite A→B→A cascade
- Firmware changes are minimal and correct (switch guard + display messages)
- All 824 tests pass with no regressions
- Docs updated alongside code changes
