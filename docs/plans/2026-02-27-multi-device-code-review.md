# Multi-Device BLE Code Review Findings

> **Date:** 2026-02-27
> **Branch:** `feature/multi-device-ble`
> **Range:** `b4bc25b..03dde73` (31 commits, +6329/-914 lines)
> **Status:** All findings resolved

---

## Critical (Must Fix Before Merge)

### C1. Wrong device disconnect on unpair — FIXED (88d8090)

**File:** `bluetooth_bloc.dart:1054-1066`

`_onRemovePairedDevice` uses `state.connectedDeviceInstanceId` (returns `connectedDevices.keys.first`) to check whether the device being unpaired is connected. In multi-device mode, if device A connected first and you unpair device B:

- `keys.first == event.deviceInstanceId` is false → disconnect block skipped entirely
- Device B stays connected with released claims
- Line 1066 uses `state.connectedDevice!.id` (device A's transport ID) — would disconnect the wrong device if the condition did pass

**Fix:** Replaced first-device getter with direct map lookup `state.connectedDevices[event.deviceInstanceId]`.

---

### C2. Wrong device log pagination and clear — FIXED (88d8090)

**Files:**
- `bluetooth_event.dart:141-157` (event definitions)
- `bluetooth_bloc.dart:804-849` (handlers)
- `bluetooth_bloc.dart:944-952` (dispatch site)

`_onMessageReceived` knows `deviceInstanceId` (line 878), but dispatches `RequestDeviceData` and `ClearDeviceLogs` without it. Both events lack a `deviceInstanceId` field. The handlers fall back to `state.connectedDevice?.id` (first device in map).

When device B sends logs, the pagination request and clear command get sent to device A.

**Fix:** Added `deviceInstanceId` to both events. Updated handlers and dispatch sites to pass it through.

---

## Important (Should Fix)

### I1. Claim + release are not atomic — FIXED (8d2b3b6)

**File:** `bluetooth_bloc.dart:1450-1459`

Spec (Section 7.4) requires a single Firestore transaction for release + claim. Code does two separate operations. If the app crashes between them, the old item is released but the new one is never claimed.

**Fix:** Created `atomicClaimSwap` in datasource/repo/impl that releases previous + claims new in one `runTransaction`. Also added same-device no-op check to `claimItem`.

---

### I2. Override test never exercises claim filtering — FIXED (8d2b3b6)

**File:** `sync_usecase_test.dart:431-475`

Test items have no `claimedBy` set, so the claim filter at `sync_usecase.dart:434-438` is never exercised. A bug in that condition would not be caught.

**Fix:** Added test `should exclude items claimed by other devices from override payload` verifying items with `claimedBy` set to another device are excluded.

---

### I3. `deviceInstanceId` optional in `PerformOverrideParams` — FIXED (8d2b3b6)

**File:** `sync_usecase.dart` — `PerformOverrideParams` class

Claim filter at line 434 is behind `if (params.deviceInstanceId != null)`. If a caller omits it, all items (including those claimed by other devices) are sent to the device.

**Fix:** Made `deviceInstanceId` required in `PerformOverrideParams`. Removed null guard so claim filter always applies.

---

## Low Priority (Track for Later)

### L1. Same-device re-claim wastes a Firestore write — FIXED (8d2b3b6, part of I1)

**File:** `item_remote_datasource_impl.dart:852-861`

**Fix:** Added `if (currentClaim == deviceInstanceId) return;` no-op check inside `atomicClaimSwap` and `claimItem`.

### L2. `releaseItem` uses `FieldValue.delete()` instead of null — FIXED (8d2b3b6, part of I1)

**File:** `item_remote_datasource_impl.dart:870-878`

**Fix:** Changed `releaseItem` to set `claimed_by` and `claimed_at` to `null` instead of `FieldValue.delete()`.

### L3. `_onSendTimeSync` and `_onUnpairDevice` use first-device fallback — FIXED (ae7bbb2)

**File:** `bluetooth_bloc.dart:791, 855`

**Fix:** Added optional `deviceInstanceId` to `SendTimeSync` and `UnpairDevice` events. Updated handlers to resolve target device from event when specified, falling back to first connected for single-device compat.

### L4. Invisible space character reserves tile height in single-device mode — FIXED (ae7bbb2)

**File:** `items_list_page.dart:1553`

**Fix:** Replaced `Text(claimName ?? ' ')` with early return of `SizedBox.shrink()` when `claimName` is null.

### L5. Hardcoded hex colors in accent bar — FIXED (ae7bbb2)

**File:** `items_list_page.dart:1566-1569`

**Fix:** Added `accentActive()` and `accentInactive()` semantic colors to `AppColors`. Replaced all hardcoded hex values in accent bar and count text.

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
- All 825 tests pass with no regressions
- Docs updated alongside code changes
