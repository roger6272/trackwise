# Exclusive Leasing — Multi-Device Spec

> **Status:** Draft
> **Last Updated:** 2026-02-24
> **Replaces:** Sync-seq conflict resolution model for multi-device scenarios

---

## 1. Overview

Exclusive Leasing is a multi-device model where a device **claims exactly one item** at a time — the item it currently has selected. A claimed item belongs to one device; no other device can claim it. When the claiming device is online, the item remains editable (changes sync immediately). When offline, the item is locked to prevent unsyncable changes. This eliminates sync conflicts by design.

### 1.1 Core Principles

| Principle | Description |
|-----------|-------------|
| **One Device, One Item** | A device claims exactly one item at a time (its selected item). Selecting a new item releases the previous one. |
| **Exclusive Ownership** | A claimed item belongs to one device. While that device is online, the item is editable (changes sync immediately). While offline, the item is locked — no edits or deletions allowed. |
| **Offline Autonomy** | The claiming device can count/reset freely without connectivity. |
| **Fixed-Task Constraint** | A device cannot switch items while offline. Must reconnect to swap. |
| **Progressive Complexity** | Single-device use is unchanged. Multi-device UI only appears when 2+ devices are connected. |
| **Break-Glass Recovery** | Lost/dead device claims can be force-released from the app. |

### 1.2 Single vs Multi-Device Behavior

| Condition | Behavior |
|-----------|----------|
| 0 devices connected | App-only mode (no activate interaction) |
| 1 device connected | **Same as today.** Swipe to activate = select/claim. Claim is written to Firestore (`claimed_by`), but no dropdown, no device colors on item bars. |
| 2+ devices connected | Multi-device mode. Activate shows dropdown. Item bars show device colors and names. |

---

## 2. Claiming & Releasing

### 2.1 The One-Item-Per-Device Rule

A device can only claim **one item at a time**. This mirrors the current "selected item" behavior:

- When a device **selects a new item**, the previous item is **automatically released**.
- While **online**, a device can freely loop through items — each selection swaps the claim.
- While **offline**, the device is **locked to its current item** (fixed-task constraint).

### 2.2 How Claims Work

| Action | Trigger | Result |
|--------|---------|--------|
| **Claim (single device)** | Left-swipe item → tap Activate action | Item assigned to the only connected device. Previous item auto-released. |
| **Claim (multi-device)** | Left-swipe item → tap Activate → select device from dropdown | Item assigned to selected device. That device's previous item auto-released. |
| **Claim (device-side loop)** | User loops through items on physical device | Each item selected = claimed. Previous auto-released. Device only has unclaimed items (claimed items are never sent to it). |
| **Release (app)** | Left-swipe item → tap unlock icon → confirm | Claim removed, item available to all devices. |
| **Release (break-glass)** | Same unlock flow, but device is offline/lost | Claim removed with warning about unsynced data. |
| **Release (auto)** | Device selects a different item | Previous item automatically released. |

### 2.3 Claim State Transitions

```
                    ┌──────────┐
                    │ Unclaimed │ ◄──── device selects different item (auto-release)
                    └─────┬────┘ ◄──── user unlocks via swipe
                          │      ◄──── break-glass release
           swipe activate / select device / device-side select
                          │
                          ▼
                ┌─────────────────┐
                │ Claimed (online) │ ◄──── device reconnects
                └────────┬────────┘
                         │
                  device disconnects
                         │
                         ▼
              ┌──────────────────────┐
              │ Claimed (offline)    │
              │ (grayed-out color,   │
              │  "disconnected" tag) │
              └──────────┬───────────┘
                         │
            ┌────────────┼────────────┐
            │            │            │
    device reconnects  user releases  break-glass
            │          (unlock)       (unlock + warning)
            │            │            │
            ▼            ▼            ▼
    Claimed (online)  Unclaimed    Unclaimed
                                  (unsynced data
                                   discarded on
                                   next device sync)
```

### 2.4 Claim Persistence

- Claims **persist indefinitely** until manually released. No auto-expiry.
- Easy to release: left-swipe → unlock icon → confirm.

### 2.5 Break-Glass Release

When a device is offline/lost and the user force-releases an item:

1. App shows warning dialog:
   > "This will release [Item Name] from [Device Name]. When [Device Name] reconnects, its unsynced counts for this item will be discarded. Continue?"
2. User confirms → claim removed from Firestore.
3. Item becomes available to other devices immediately.
4. When the original device reconnects:
   - Handshake detects it no longer owns the item.
   - App offers: **"Override Device"** (push Firestore data to device — device counts for the released item are discarded) or **"Don't Sync"** (disconnect; device keeps counting offline independently, item stays released in Firestore).

---

## 3. Editing Rules for Claimed Items

The key factor is whether the claiming device is **online or offline** — not whose device it is.

### 3.1 Claiming Device is Online

When the device claiming an item is **connected to the app**, the item is **fully editable**:

| Action | Allowed? | Reason |
|--------|----------|--------|
| View item details | **Yes** | — |
| Enter item edit page | **Yes** | Device receives changes immediately |
| Edit name, notes, etc. | **Yes** | Device receives changes immediately |
| Move to different category (drag-and-drop) | **Yes** | Via drag-and-drop on list page or edit page. Device receives updated category info immediately. |
| Delete item | **Yes** | Device is notified; shows "no item selected" |
| Reorder in list | **Yes** | Order is app-local |
| Unlock/release | **Yes** | Standard release via swipe |

This applies whether it's your own device or another device. The claim is a **soft indicator** of which device is actively counting — not a hard lock.

### 3.2 Claiming Device is Offline

When the device claiming an item is **disconnected**, the item has restricted editing:

| Action | Allowed? | Reason |
|--------|----------|--------|
| View item details | **Yes** | Read-only |
| Enter item edit page | **No** | Edit icon locked; offline device can't receive changes |
| Delete item | **No** | Offline device would keep counting a deleted item |
| Reorder in list | **Yes** | Order is app-local, doesn't affect the device |
| Move to different category (drag-and-drop) | **Yes** | Done via drag-and-drop on the list page (no edit page needed). Offline device is locked to this item by ID regardless of category. On reconnect, updated category info syncs. |
| Unlock/release (break-glass) | **Yes** | With warning about unsynced data |

### 3.3 Why Allow Category Move Even When Offline?

The offline device doesn't care about categories — it's locked to one item by ID. Moving the item to a different category:
- Has **zero effect** on the offline device until it reconnects.
- On reconnection, the device receives the updated category list via `set_items`.

**Note:** Drag-and-drop reorder/category-move should be enabled regardless of connection state. With the fixed-task constraint, offline devices cannot switch items, so there is no risk from allowing reorder while disconnected. (The current implementation gates drag-and-drop on `isConnected` — this gate should be removed.)

---

## 4. UI Changes

### 4.1 Item List Page

#### Item Bar — Multi-Device Mode (2+ devices connected)

```
┌─────────────────────────────────────────────────────┐
│ ┌──┐                                                │
│ │🔵│  Push-ups                              > 150   │
│ │  │  Category: Exercise                            │
│ │  │  ── Office Counter ──                          │
│ └──┘                                                │
│ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │  ← device color tint on bar
└─────────────────────────────────────────────────────┘
```

The bar shows device color tint and device name. Activate/unlock actions remain **left-swipe actions** (not visible on the bar).

| Element | Unclaimed | Claimed (device online) | Claimed (device offline) |
|---------|-----------|------------------------|-------------------------|
| **Bar background** | Default | Device color tint (subtle) | Grayed-out device color |
| **Device name** | — | Small text: device name | Small text: device name + "disconnected" |
| **Tappable** | Yes (opens detail) | Yes (opens detail) | Yes (opens detail) |

**Note:** All items — claimed or not — appear in the app's item list page. On the **physical device**, the app only sends unclaimed items (and items claimed by the device itself), so the device never sees items claimed by other devices.

#### Left-Swipe Actions

| Item State | Swipe Actions |
|------------|--------------|
| Unclaimed (1+ devices connected) | Activate (or dropdown in multi-device mode), Edit, Delete |
| Unclaimed (0 devices connected) | Edit, Delete (no Activate action) |
| Claimed (device online) | Unlock, Edit, Delete |
| Claimed (device offline) | Unlock (break-glass), ~~Edit~~ (locked), ~~Delete~~ (locked) |

#### Activate Behavior

| Condition | Behavior |
|-----------|---------|
| 1 device connected, item unclaimed | Claim immediately (no dropdown) |
| 2+ devices connected, item unclaimed | Show dropdown of connected devices → select to claim. Selecting a device auto-releases that device's previous item. |
| Item already claimed | Activate action not shown (replaced by Unlock) |

#### Unlock Action

| Scenario | Dialog message |
|----------|----------------|
| Claimed (device online) | "Release [Item] from [Device]?" |
| Claimed (device offline) | "Release [Item] from [Device]? Unsynced counts will be discarded when it reconnects." |

### 4.2 Item Detail Page

The item detail page displays stats, charts, and cycle info. Cycle notes and cycle names are editable directly on this page, but these don't affect device state (they're app-only metadata). No special claim-aware changes needed here — it displays and allows cycle note/name editing regardless of claim state.

### 4.3 Paired Devices Page

#### Device Color

- Each device gets a **user-configurable color** from a palette of 10 options.
- Default colors auto-assigned on pairing (first available from palette).
- Color picker shown in rename dialog or as separate option in popup menu.

#### Color Palette (10 colors)

| Index | Name | Use |
|-------|------|-----|
| 0 | Blue | Default 1st device |
| 1 | Green | Default 2nd device |
| 2 | Orange | Default 3rd device |
| 3 | Purple | — |
| 4 | Red | — |
| 5 | Teal | — |
| 6 | Pink | — |
| 7 | Amber | — |
| 8 | Indigo | — |
| 9 | Brown | — |

Colors must be distinguishable in both light and dark mode.

---

## 5. Device-Side Behavior

### 5.1 App-Side Item Filtering

The app **only sends unclaimed items** (and items claimed by the receiving device) via `set_items` or override. Items claimed by other devices are never sent to the device. The filtering logic:

```dart
filteredItems = allItems.where((item) =>
  item.claimedBy == null || item.claimedBy == deviceInstanceId
).toList();
```

This means:

- The device only has items it can actually use — no skip logic needed.
- When a claim changes, the app pushes an updated `set_items` to affected devices. Only devices whose **selected category** contains the affected item need an update.
- If all items in the category are claimed by other devices, the device receives an empty list and shows "no item selected."

### 5.2 Fixed-Task Constraint (Offline)

When the device is **offline** (not connected to app):

- The device **cannot switch items**. When the user presses the cycle button, the device displays a two-line message on the 128x64 OLED: **Line 1: "SWITCH DISABLED"**, **Line 2: "SYNC TO APP"**.
- The device continues counting/resetting the currently selected item only.

When the device **reconnects**:

- App syncs latest item list (filtered by claims) and category info.
- Item switching is re-enabled.

### 5.3 Claimed Item Deleted While Device Online

When an item is deleted from the app while the claiming device is online:

1. App deletes the item from Firestore, then pushes updated `set_items` to all connected devices in the same category (the deleted item is simply absent from the list). This is the same approach used today for single-device deletion.
2. Claiming device receives the update, removes the item from NVS, and shows **"no item selected"**.
3. User can select a new item from the device or app.

### 5.4 Claiming from Device Side

When a user selects an item on the device (while connected):

1. Device sends `event` notification with `event: "switch"` (includes the new item's numeric `deviceItemId` — the app maps this to a Firestore ID). Note: switch events do **not** produce an `item_delta` notification.
2. App receives it and processes the claim:
   - **Unclaimed** → App writes claim to Firestore (releases previous item), pushes updated `set_items` to other affected devices.
   - **Claimed by this device** → Already owned, proceed.
   - **Claimed by another device** → Near-zero probability since the device only has unclaimed items. Only possible if another device claimed the same item in the brief window since the last `set_items`. Firestore transaction rejects the claim; app pushes updated `set_items` (excluding the now-claimed item), then sends `set_selected` to redirect to the first item in the updated list. If the updated list is empty, send `set_selected` with `id: -1` to explicitly clear the device's selection (the device does not auto-clear on empty `set_items`). App should verify the redirect succeeded by waiting for the expected `item_delta` response.

---

## 6. Protocol Changes

### 6.1 No Payload Format Changes

The claiming mechanism is handled entirely by the app filtering which items are sent to each device. The `set_items` and `override_chunk` JSON formats are **unchanged** — no new fields needed.

- **Handshake:** No changes. App knows claim state from Firestore before connecting.
- **set_items:** App sends only unclaimed items (and items claimed by the receiving device). Same JSON format as today.
- **override_chunk:** Same filtering applied. Same JSON format as today.

### 6.2 Claim-Triggered Updates

When a claim changes (item claimed or released), the app pushes an updated `set_items` to other connected devices whose **selected category** contains the affected item. Devices in a different category are unaffected and receive no update.

**Note:** `set_items` clears the device's event log buffer. Increment events are only buffered when disconnected (guarded by `isConnected`), so clearing is safe — no unsynced increments are lost. Reset events are logged unconditionally (no `isConnected` guard), which is correct: when disconnected, the buffer is the only way resets reach the app on reconnection; when connected, the redundant buffer copy is harmless since the app already received the real-time notification. Claim-triggered `set_items` pushes do not risk losing events.

### 6.3 Sync Sequence Compatibility

The existing `sync_seq` mechanism is **retained** as a secondary safeguard:

- Exclusive Leasing handles the common case (no conflicts by design).
- `sync_seq` catches edge cases where Firestore state changed between handshake and sync.
- If `sync_seq` mismatch is detected despite leasing, fall back to current override flow.
- Claim-triggered `set_items` pushes do **not** update `sync_seq` — only `sync_complete`/`override_end` do. This is acceptable because the next handshake will reconcile any discrepancies.

---

## 7. Firestore Schema Changes

### 7.1 Item Document — New Fields

Items are stored in a top-level `Item` collection (not nested under users), filtered by a `uid` DocumentReference field.

```
Item/{itemId}/
  ├── ... (existing fields: uid, item_name, count, etc.)
  ├── claimed_by: "AA:BB:CC:DD:EE:FF"   // NEW: deviceInstanceId, null if unclaimed (field present, set to null — not absent)
  └── claimed_at: Timestamp               // NEW: Firestore server timestamp, null when unclaimed
```

**Clearing claims in Dart:** `copyWith(claimedBy: null)` can't distinguish "set to null" from "don't change". Follow the existing `clearCategoryId` sentinel pattern — add a `clearClaimedBy` flag to `Item.copyWith()`.

### 7.2 Paired Device — New Field

Paired devices are stored as an array of maps in the `paired_devices` field on the user document (not a subcollection).

```
users/{uid}/
  └── paired_devices: [
        {
          device_instance_id: "AA:BB:CC:DD:EE:FF",
          device_name: "Office Counter",
          paired_at: Timestamp,
          color: 0                        // NEW: color palette index (0-9)
        },
        ...
      ]
```

### 7.3 EventLog Document — New Field

Event logs are stored in a top-level `EventLog` collection (not nested under users), filtered by a `uid` DocumentReference field (same pattern as Item).

```
EventLog/{eventId}/
  ├── ... (existing fields: uid, item_id, event_name, etc.)
  └── device_instance_id: "AA:BB:CC:DD:EE:FF"  // NEW: which device generated this event (null for app-initiated events)
```

Every event (increment, reset, created) should record which device generated it, for multi-device auditing.

### 7.4 Claim Enforcement

Claim rules are enforced at the **app layer**, not Firestore rules. Firestore authenticates by user UID — there's no mechanism to distinguish between device sessions from the same user. The app is responsible for:

- Checking claim state before allowing edits (online = allow, offline = block edit page/delete).
- Setting `claimed_by` only if currently null or matches the claiming device.
- Using Firestore transactions for atomic claim/release operations.

---

## 8. App Architecture Changes

### 8.1 Data Layer

| Component | Change |
|-----------|--------|
| **Item entity** | Add `claimedBy: String?`, `claimedAt: DateTime?` fields. Add `clearClaimedBy` sentinel to `copyWith()` (same pattern as existing `clearCategoryId`). |
| **Item model** | Add Firestore serialization for new fields (`claimed_by`, `claimed_at`). Note: ~21 manual `ItemModel(...)` constructor calls need updating across item_model.dart (3), repo_impl (4), datasource_impl (3), test_fixtures (2), and test files (9). |
| **PairedDevice entity** | Add `color: int` field (0-9). Note: PairedDevice has inline `fromFirestore()`/`toFirestore()` — no separate model class. Stored as map entries in the `paired_devices` array on the user document. |
| **EventLog entity** | Add `deviceInstanceId: String?` field (null for app-initiated events like "created") |
| **EventLog model** | Add Firestore serialization for `device_instance_id` |

### 8.2 BLoC Changes

| BLoC | Change |
|------|--------|
| **BluetoothBloc** | **Critical refactor:** Currently single-connection (`connectedDeviceInstanceId: String?`). Must refactor datasource, repository, BLoC, and state to track multiple simultaneous connections (`connectedDevices: Map<String, BleDevice>`). This is the deepest architectural change — handshake/sync must run per-device. |
| **ItemsBloc** | Expose claim state per item. Handle claim/release events. |
| **New events** | `ClaimItem(itemId, deviceInstanceId)`, `ReleaseItem(itemId)` |

### 8.3 Sync Helper Changes

| Component | Change |
|-----------|--------|
| **`syncItemsToDevice()`** | Must accept a `deviceInstanceId` parameter and **filter out items claimed by other devices** before sending. Only unclaimed items and items claimed by the receiving device are included in the payload. |
| **Event logging** | All events (increment, reset, created) must include `deviceInstanceId` to track which device generated the event. |

### 8.4 UI Components

| Component | Change |
|-----------|--------|
| **ItemTile** | Show device color tint, device name, claim-aware swipe actions (activate/unlock/edit/delete), locked edit/delete for offline-claimed items |
| **ItemDetailPage** | No claim-aware changes needed — already view-only (stats, chart, cycle notes) |
| **PairedDevicesPage** | Color picker in device options |
| **New: DeviceDropdown** | Popup for selecting device when claiming in multi-device mode |
| **New: UnlockConfirmDialog** | Warning dialog for releasing items (normal + break-glass variants) |
| **CSV Export** | Add optional "Device" column to export output using the new `deviceInstanceId` field on EventLog. Map device IDs to device names for readability. |

---

## 9. Sync Flow — Revised

### 9.1 Connection & Sync (Single Device)

Unchanged from current behavior. No claim UI shown.

### 9.2 Connection & Sync (Multi-Device)

```
App connects to Device B
  │
  ├── 1. Handshake (existing)
  │     └── Determines in_sync / conflict / wrong_account
  │
  ├── 2. Fetch claims from Firestore
  │     └── Which items are claimed by which devices
  │
  ├── 3. Sync data (existing in_sync or override flow)
  │     └── Filter items: send only unclaimed + Device B's own claimed items
  │
  ├── 4. Device receives only available items
  │     └── No claim flags needed — claimed-by-other items are simply absent
  │
  └── 5. UI updates
        ├── Item bars show device colors and names
        ├── Claimed items show claim state
        └── Swipe actions reflect claim state (activate vs unlock)
```

### 9.3 Break-Glass Reconnection

```
Device A reconnects after being force-released
  │
  ├── 1. Handshake → likely conflict (sync_seq mismatch)
  │
  ├── 2. App detects Device A's item was released while offline
  │
  ├── 3. App shows dialog:
  │     "Your item was released while this device was offline.
  │      Sync now? Device counts for released items will be discarded."
  │
  │     [Override Device]  [Don't Sync]
  │
  ├── If Override: Override flow → Firestore items pushed to device.
  │     Device receives filtered item list (only available items). Can now select a new item.
  │
  └── If Don't Sync: Disconnect. Device keeps local counts offline.
        Item stays released in Firestore.
```

---

## 10. Edge Cases

| Scenario | Behavior |
|----------|----------|
| Device selects new item while online | Previous item auto-released, new item claimed. Seamless. |
| User assigns item to Device B via dropdown | Device B's previous item auto-released first, then new item claimed. |
| Device disconnects mid-count | Claim persists. Item shows as "claimed (disconnected)". Device continues counting offline. |
| All items in category claimed by other devices | Device receives an empty item list. Display shows "no item selected." User must release items from app or switch categories. |
| User deletes a claimed item (device online) | Item deleted. Device is notified and shows "no item selected." |
| User deletes a claimed item (device offline) | **Blocked.** Must release (break-glass) or reconnect the device first. |
| User edits a claimed item (device online) | Allowed. Device receives changes immediately. |
| User edits a claimed item (device offline) | **Blocked.** Edit icon is locked. Must reconnect the device first. |
| Two devices try to claim same item simultaneously | Firestore transaction ensures only one succeeds. Loser's device receives updated `set_items` (item removed), then `set_selected` to redirect. |
| Device factory reset while holding claim | Claim orphaned in Firestore. User unpairs the old device entry from paired devices page → claims auto-released. Or user break-glass releases the item directly. |
| User unpairs device from paired devices page | All claims by that device are released automatically. (New behavior — unpair flow must be extended to clear `claimed_by` on all items claimed by the removed device.) |
| Offline device reconnects, item was moved to different category | Device receives updated category info via `set_items`. No data conflict. |
| Device user tries to switch items while offline | Device displays "SWITCH DISABLED" / "SYNC TO APP" on OLED and stays on current item. |
| App restarts (killed/relaunched) | Claims persist in Firestore. All devices appear disconnected until they reconnect and re-handshake. Claims flip to "claimed (offline)" state until devices reconnect. |
| Device connects but handshake returns conflict | Claiming is only available **after** handshake/sync completes successfully. During conflict resolution, the device cannot be used for claiming. |
| Only 1 device connected but 2+ paired | Single-device behavior. No claim UI, no colors. |

---

## 11. Migration & Compatibility

### 11.1 Existing Single-Device Users

- No migration needed. `claimed_by` defaults to null (unclaimed).
- Single-device behavior is completely unchanged.
- Multi-device features only activate when 2+ devices are simultaneously connected.

### 11.2 Firmware Compatibility

No payload format changes are needed for claiming — the app handles all claim logic by filtering which items are sent. Firmware update is required for:
- **Fixed-task constraint:** Disable item switching when offline and display the offline message (the `isConnected` flag already exists in firmware).
- **Production display rendering:** Current display functions (`displayMessage()`, etc.) are debug-only placeholders. Real display driver implementation is needed for offline messages, "no item selected" state, etc.
- **Protocol v3 handshake** (if other v3 changes exist beyond claiming).

### 11.3 Protocol Version

Claiming itself does **not** require a protocol version bump — the `set_items`/`override_chunk` JSON format is unchanged. If v3 is needed for other reasons, claiming works transparently on any protocol version since it's handled entirely app-side.

---

## 12. Implementation Phases

### Phase 1: Foundation (App-side)

- Add `claimedBy`, `claimedAt` to Item entity/model (~21 constructor calls across item_model, repo_impl, datasource_impl, test fixtures, and test files)
- Add `deviceInstanceId` to EventLog entity/model
- Add `color` to PairedDevice entity (inline serialization, no separate model)
- Firestore read/write for new fields
- No UI changes yet

### Phase 2: Multi-Device BLE & Claim Logic (App-side) — CRITICAL PATH *(blocked by Phase 1)*

**This is the deepest architectural change.** The current BLE stack is single-connection:
- `BluetoothDataSourceImpl` stores `BluetoothDevice? _connectedDevice` (singular)
- `BluetoothState` tracks `connectedDeviceInstanceId: String?` (singular)
- All handshake/sync logic assumes one device

Must refactor to:
- Datasource: `Map<String, BluetoothDevice> _connectedDevices`
- State: `Map<String, BleDevice> connectedDevices`
- Run handshake and sync per-device
- `syncItemsToDevice()` must accept `deviceInstanceId` and **filter out items claimed by other devices** before sending
- All event logging must include `deviceInstanceId`

Then add claim logic:
- Claim/release Firestore operations (with transactions for atomicity)
- Auto-release on new claim (one-item-per-device enforcement)
- Auto-release on device unpair
- `ItemsBloc`: expose claim state per item, handle `ClaimItem` and `ReleaseItem` events

### Phase 3: UI — Item List *(blocked by Phase 2)*

- Device color tinting on item bars
- Device name display on claimed items
- Locked edit/delete swipe actions for offline-claimed items
- Activate swipe action with device dropdown for multi-device claiming
- Unlock swipe action with confirmation dialogs (normal + break-glass)
- Enable drag-and-drop reorder/category-move regardless of connection state (remove `isConnected` gate)

### Phase 4: UI — Supporting Pages *(blocked by Phase 2; can parallel Phase 3)*

- Paired devices page: color picker
- Break-glass reconnection dialog
- CSV export: add optional "Device" column (map `deviceInstanceId` to device name)

### Phase 5: Firmware *(can parallel Phases 2-4)*

- Fixed-task constraint: guard item switch on `isConnected` flag (already tracked in firmware), display two-line OLED message ("SWITCH DISABLED" / "SYNC TO APP"). Insert guard in the `cmd == 's'` handler, after the `total == 0` early-return check. Applies to both serial command handler and item menu navigation.
- Device shows "no item selected" when it receives an empty item list or its claimed item is deleted
- Implement production display rendering (current `displayMessage()` is a debug-only placeholder)
- No payload format changes needed — claiming is handled entirely by app-side filtering

### Phase 6: Integration & Testing *(blocked by Phases 3-5)*

- End-to-end multi-device testing (2+ devices)
- Single-device regression testing
- Edge case scenarios from Section 10
- Offline/reconnection scenarios
- Verify `deviceInstanceId` is recorded on all events
