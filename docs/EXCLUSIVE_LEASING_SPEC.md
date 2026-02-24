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
| 0 devices connected | App-only mode (no ping icon interaction) |
| 1 device connected | **Same as today.** Tap ping = select/claim. No dropdown, no device colors on item bars. |
| 2+ devices connected | Multi-device mode. Ping shows dropdown. Item bars show device colors and names. |

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
| **Claim (single device)** | Tap ping icon on item list page | Item assigned to the only connected device. Previous item auto-released. |
| **Claim (multi-device)** | Tap ping icon → select device from dropdown | Item assigned to selected device. That device's previous item auto-released. |
| **Claim (device-side loop)** | User loops through items on physical device | Each item selected = claimed. Previous auto-released. Items claimed by other devices are skipped. |
| **Release (app)** | Left-swipe item → tap unlock icon → confirm | Claim removed, item available to all devices. |
| **Release (break-glass)** | Same unlock flow, but device is offline/lost | Claim removed with warning about unsynced data. |
| **Release (auto)** | Device selects a different item | Previous item automatically released. |

### 2.3 Claim State Transitions

```
                    ┌──────────┐
                    │ Unclaimed │ ◄──── device selects different item (auto-release)
                    └─────┬────┘ ◄──── user unlocks via swipe
                          │      ◄──── break-glass release
              tap ping / select device / device-side select
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
   - App offers: **"Sync to app"** (discard device counts, accept Firestore) or **"Don't sync"** (keep device counting offline independently, item stays released in Firestore).

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
| Move to different category | **Yes** | Device receives updated category info immediately |
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
| Move to different category | **Yes** | Offline device is locked to this item by ID regardless of category. On reconnect, updated category info syncs. |
| Unlock/release (break-glass) | **Yes** | With warning about unsynced data |

### 3.3 Why Allow Category Move Even When Offline?

The offline device doesn't care about categories — it's locked to one item by ID. Moving the item to a different category:
- Has **zero effect** on the offline device until it reconnects.
- On reconnection, the device receives the updated category list via `set_items`.

---

## 4. UI Changes

### 4.1 Item List Page

#### Item Bar — Multi-Device Mode (2+ devices connected)

```
┌─────────────────────────────────────────────────────┐
│ ┌──┐                                                │
│ │🔵│  Push-ups                    [ping/lock icon]  │
│ │  │  Category: Exercise                            │
│ │  │  ── Office Counter ──                          │
│ └──┘                                                │
│ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │  ← device color tint on bar
└─────────────────────────────────────────────────────┘
```

| Element | Unclaimed | Claimed (device online) | Claimed (device offline) |
|---------|-----------|------------------------|-------------------------|
| **Bar background** | Default | Device color tint (subtle) | Grayed-out device color |
| **Device name** | — | Small text: device name | Small text: device name + "disconnected" |
| **Edit icon** | Normal | Normal | **Locked** (tap shows "reconnect device to edit") |
| **Ping icon** | Ping (dropdown on tap) | Filled ping (device color, non-interactive) | Filled ping (grayed, non-interactive) |
| **Left swipe** | Normal actions | Shows **unlock icon** + normal actions | Shows **unlock icon** (break-glass) |
| **Tappable** | Yes (opens detail) | Yes (opens detail) | Yes (opens detail) |

**Note:** All items — claimed or not — appear in the app's item list page. On the **physical device**, items claimed by other devices are skipped when the user loops through items (see Section 5.1).

#### Ping Icon Behavior

| Condition | Tap behavior |
|-----------|-------------|
| 1 device connected, item unclaimed | Claim immediately (no dropdown) |
| 2+ devices connected, item unclaimed | Show dropdown of connected devices → select to claim. Selecting a device auto-releases that device's previous item. |
| Item already claimed (any device) | No action (use unlock swipe to release first) |

#### Unlock Action (Left Swipe)

| Scenario | Unlock available? | Dialog message |
|----------|------------------|----------------|
| Claimed (device online) | Yes | "Release [Item] from [Device]?" |
| Claimed (device offline) | Yes (break-glass) | "Release [Item] from [Device]? Unsynced counts will be discarded when it reconnects." |
| Unclaimed | No | — |

### 4.2 Item Detail Page

The item detail page is view-only (stats, chart, cycle notes). No special claim-aware changes needed here — it displays data regardless of claim state.

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

### 5.1 Item Looping with Claims

When a user navigates items on the physical device (button press to cycle) while **online**:

- Items claimed by **other connected devices** are **skipped**.
- The device only stops on items that are: unclaimed, or claimed by itself.
- Selecting a new item = claiming it, auto-releasing the previous.

### 5.2 Claim Flag per Item

Each item in device NVS gains a new field:

| NVS Key | Type | Values | Description |
|---------|------|--------|-------------|
| `cl_<i>` | uint8 | 0 = unclaimed/self, 1 = claimed by other | Skip flag for item looping |

- Set during sync via `set_items` or override chunks.
- Device treats `cl_<i> = 1` items as "skip during navigation."
- Device does NOT modify claimed-by-other items' counts.

### 5.3 Fixed-Task Constraint (Offline)

When the device is **offline** (not connected to app):

- The device **cannot switch items**. Button press to cycle is disabled.
- The device continues counting/resetting the currently selected item only.
- Display shows a lock indicator to signal "reconnect to switch."

When the device **reconnects**:

- App syncs latest claim state and category list.
- Item switching is re-enabled.
- Device receives updated `cl_<i>` flags for all items.

### 5.4 Claimed Item Deleted While Device Online

When an item is deleted from the app while the claiming device is online:

1. App sends updated item list via `set_items` (without the deleted item).
2. Device receives the update and removes the item from NVS.
3. Device shows **"no item selected"** — same as current behavior when no item is selected.
4. User can select a new item from the device or app.

### 5.5 Claiming from Device Side

When a user selects an item on the device (while connected):

1. Device sends `item_delta` notification for the new item.
2. App receives it and checks claim status in Firestore:
   - **Unclaimed** → App writes claim to Firestore (and releases previous item), allows selection.
   - **Claimed by this device** → Already owned, proceed.
   - **Claimed by another device** → Should not happen (item was skipped via `cl_<i>` flag), but if it does: app sends `set_selected` to skip to next available item.

---

## 6. Protocol Changes

### 6.1 Handshake Extension

**No change to handshake command** — the app already knows claim state from Firestore before connecting. Claim flags are communicated via `set_items`/override.

### 6.2 set_items Extension

Add claim flag to each item in the `set_items` payload:

```json
[
  {
    "id": 0,
    "name": "Push-ups",
    "count": 150,
    "claimed": 1,
    ...
  }
]
```

`claimed` values: `0` = unclaimed or claimed by this device, `1` = claimed by another device.

Device uses this to populate `cl_<i>` NVS keys.

### 6.3 Override Chunks Extension

Same addition to `override_chunk` items:

```json
{
  "cmd": "override_chunk",
  "index": 0,
  "items": [
    {
      "device_item_id": 5,
      "name": "Push-ups",
      "claimed": 0,
      ...
    }
  ]
}
```

### 6.4 Sync Sequence Compatibility

The existing `sync_seq` mechanism is **retained** as a secondary safeguard:

- Exclusive Leasing handles the common case (no conflicts by design).
- `sync_seq` catches edge cases where Firestore state changed between handshake and sync.
- If `sync_seq` mismatch is detected despite leasing, fall back to current override flow.

---

## 7. Firestore Schema Changes

### 7.1 Item Document — New Fields

```
users/{uid}/items/{itemId}/
  ├── ... (existing fields)
  ├── claimed_by: "AA:BB:CC:DD:EE:FF"   // NEW: deviceInstanceId, null if unclaimed
  └── claimed_at: Timestamp               // NEW: when claim was established
```

### 7.2 Device Document — New Field

```
users/{uid}/devices/{deviceInstanceId}/
  ├── ... (existing fields)
  └── color: 0                            // NEW: color palette index (0-9)
```

### 7.3 EventLog Document — New Field

```
users/{uid}/event_logs/{eventId}/
  ├── ... (existing fields)
  └── device_instance_id: "AA:BB:CC:DD:EE:FF"  // NEW: which device generated this event
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
| **Item entity** | Add `claimedBy: String?`, `claimedAt: DateTime?` fields |
| **Item model** | Add Firestore serialization for new fields (`claimed_by`, `claimed_at`). Note: 11+ manual `ItemModel(...)` constructors need updating across repo_impl, datasource_impl, and test fixtures. |
| **PairedDevice entity** | Add `color: int` field (0-9). Note: PairedDevice has inline `fromFirestore()`/`toFirestore()` — no separate model class. |
| **EventLog entity** | Add `deviceInstanceId: String?` field |
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
| **`syncItemsToDevice()`** | Must accept a `deviceInstanceId` parameter to compute the `claimed` flag per item relative to the receiving device (0 = unclaimed or self, 1 = claimed by another device). |
| **Event logging** | All events (increment, reset, created) must include `deviceInstanceId` to track which device generated the event. |

### 8.4 UI Components

| Component | Change |
|-----------|--------|
| **ItemTile** | Show device color tint, device name, claim-aware ping/edit icons, locked edit icon for offline-claimed items |
| **ItemDetailPage** | No claim-aware changes needed — already view-only (stats, chart, cycle notes) |
| **PairedDevicesPage** | Color picker in device options |
| **New: DeviceDropdown** | Popup for selecting device when claiming in multi-device mode |
| **New: UnlockConfirmDialog** | Warning dialog for releasing items (normal + break-glass variants) |

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
  │     └── Include `claimed` flag per item in set_items/override
  │
  ├── 4. Device receives items with claim flags
  │     └── Stores cl_<i> per item, skips claimed-by-other during loop
  │
  └── 5. UI updates
        ├── Item bars show device colors and names
        ├── Claimed items show claim state
        └── Ping icons reflect claim state
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
  │     [Sync to App]  [Don't Sync]
  │
  ├── If Sync: Override flow → Firestore items pushed to device.
  │     Device gets updated claim flags. Can now loop and claim a new item.
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
| All items claimed by other devices | Device has nothing to count. Display shows "No available items — release items from app." |
| User deletes a claimed item (device online) | Item deleted. Device is notified and shows "no item selected." |
| User deletes a claimed item (device offline) | **Blocked.** Must release (break-glass) or reconnect the device first. |
| User edits a claimed item (device online) | Allowed. Device receives changes immediately. |
| User edits a claimed item (device offline) | **Blocked.** Edit icon is locked. Must reconnect the device first. |
| Two devices try to claim same item simultaneously | Firestore transaction ensures only one succeeds. Loser's app sends `set_selected` to skip. |
| Device factory reset while holding claim | Claim orphaned in Firestore. App detects stale claim (device no longer in paired list) and auto-releases. |
| User unpairs device from paired devices page | All claims by that device are released automatically. |
| Offline device reconnects, item was moved to different category | Device receives updated category info via `set_items`. No data conflict. |
| Only 1 device connected but 2+ paired | Single-device behavior. No claim UI, no colors. |

---

## 11. Migration & Compatibility

### 11.1 Existing Single-Device Users

- No migration needed. `claimed_by` defaults to null (unclaimed).
- Single-device behavior is completely unchanged.
- Multi-device features only activate when 2+ devices are simultaneously connected.

### 11.2 Firmware Compatibility

- Older firmware without `claimed` flag support: app sends items without the flag, device ignores unknown fields (existing JSON parsing behavior).
- Firmware update required to: respect claim flags during item looping, enforce fixed-task constraint offline.

### 11.3 Protocol Version

- Bump protocol version to **v3** for Exclusive Leasing support.
- App checks `protocol_version` in handshake response to determine if device supports leasing.
- If device is v2: fall back to current sync_seq conflict model.

---

## 12. Implementation Phases

### Phase 1: Foundation (App-side)

- Add `claimedBy`, `claimedAt` to Item entity/model (11+ constructors across repo_impl, datasource_impl, test fixtures)
- Add `deviceInstanceId` to EventLog entity/model
- Add `color` to PairedDevice entity (inline serialization, no separate model)
- Firestore read/write for new fields
- No UI changes yet

### Phase 2: Multi-Device BLE & Claim Logic (App-side) — CRITICAL PATH

**This is the deepest architectural change.** The current BLE stack is single-connection:
- `BluetoothDataSourceImpl` stores `BluetoothDevice? _connectedDevice` (singular)
- `BluetoothState` tracks `connectedDeviceInstanceId: String?` (singular)
- All handshake/sync logic assumes one device

Must refactor to:
- Datasource: `Map<String, BluetoothDevice> _connectedDevices`
- State: `Map<String, BleDevice> connectedDevices`
- Run handshake and sync per-device
- `syncItemsToDevice()` must accept `deviceInstanceId` to compute `claimed` flag relative to the receiving device
- All event logging must include `deviceInstanceId`

Then add claim logic:
- Claim/release Firestore operations (with transactions for atomicity)
- Auto-release on new claim (one-item-per-device enforcement)
- Stale claim detection and auto-release (device no longer paired)
- Auto-release on device unpair

### Phase 3: UI — Item List

- Device color tinting on item bars
- Device name display on claimed items
- Locked edit icon for offline-claimed items
- Ping icon dropdown for multi-device claiming
- Unlock swipe action with confirmation dialogs (normal + break-glass)

### Phase 4: UI — Supporting Pages

- Paired devices page: color picker
- Break-glass reconnection dialog

### Phase 5: Protocol & Firmware

- Add `claimed` flag to `set_items` and `override_chunk` payloads
- `cl_<i>` NVS flag per item on device
- Skip claimed items during device-side looping
- Fixed-task constraint (disable item switching when offline)
- Protocol v3 handshake
- Device shows "no item selected" when claimed item is deleted

### Phase 6: Integration & Testing

- End-to-end multi-device testing (2+ devices)
- Single-device regression testing
- Edge case scenarios from Section 10
- Protocol v2 backward compatibility testing
- Offline/reconnection scenarios
- Verify `deviceInstanceId` is recorded on all events
