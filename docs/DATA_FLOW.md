# Data Flow & Sync Scenarios

> Visual guide to how data moves through the Traxelos system.
>
> **Related docs:** [BLE Protocol](BLE_PROTOCOL.md) · [Device Display](DEVICE_DISPLAY.md) · [Troubleshooting](TROUBLESHOOTING.md)

---

## Glossary

| Term | Meaning |
|------|---------|
| **Activate** | User action: swipe item → tap Pin icon → select device. Creates a claim in Firestore. |
| **Claim** | Firestore mechanism: `claimed_by` field on an Item document set to a `deviceInstanceId`. At most one device can claim an item at a time. |
| **Exclusive Leasing** | The multi-device feature: each device "leases" items exclusively. Enforced by claims in Firestore + filtered item lists sent to devices. Active when 2+ devices are connected. |
| **atomicClaimSwap** | Firestore transaction that atomically releases the previous claim and creates the new one. Prevents partial states. |
| **Stale Claim** | A claim left behind when a device disconnects. The device still believes it owns the item, but the user may have force-released it. Detected on reconnect; override dialog shown. |
| **Force-Release** | Break-glass action: swipe item → tap Unlock → confirm warning. Clears `claimed_by` for an offline device's item. Unsynced counts on the device will be lost on next sync. |
| **Global Claim Queue** | Single `Future<void>` that serializes all claim operations across all devices. Prevents concurrent Firestore transactions from reading stale `claimed_by` state. See [ADR-005](decisions/ADR-005-global-claim-queue.md). |

---

## Table of Contents

1. [System Overview](#1-system-overview)
2. [Data Storage Layers](#2-data-storage-layers)
3. [Connection & Handshake Flow](#3-connection--handshake-flow)
4. [Sync Scenarios](#4-sync-scenarios)
5. [Real-time Event Flow](#5-real-time-event-flow) (incl. category deletion)
6. [Offline & Reconnection](#6-offline--reconnection)
7. [Multi-Device Sync](#7-multi-device-sync)
8. [Data Consistency Rules](#8-data-consistency-rules)
9. [OTA Firmware Update Flow](#9-ota-firmware-update-flow)

---

## 1. System Overview

### 1.1 Three-Tier Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              CLOUD                                       │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                         FIRESTORE                                  │  │
│  │                                                                    │  │
│  │   users/{uid}/items/{itemId}     ← Item definitions + counts      │  │
│  │   users/{uid}/syncState          ← last sync time                 │  │
│  │   users/{uid}/deviceMappings     ← deviceItemId ↔ Firestore ID    │  │
│  │                                                                    │  │
│  │   Source of truth for: Multi-device consistency                   │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ Cloud Sync
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                              APP (Flutter)                               │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                      BLoC State + Local Cache                      │  │
│  │                                                                    │  │
│  │   • Item list with counts                                         │  │
│  │   • Selected item                                                 │  │
│  │   • Connection state (per-device)                                 │  │
│  │   • Paired devices list + claim state                             │  │
│  │                                                                    │  │
│  │   Source of truth for: UI state, sync orchestration               │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ BLE (JSON over GATT)
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                           DEVICE (ESP32)                                 │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                      NVS (Flash) + RAM                             │  │
│  │                                                                    │  │
│  │   NVS:                           RAM:                             │  │
│  │   • Item data (name, count...)   • Current item counts            │  │
│  │   • paired_uid                   • Event log buffer (1000)        │  │
│  │                                   • Dirty flags                    │  │
│  │   • selected_did                 • BLE transmit queue             │  │
│  │                                                                    │  │
│  │   Source of truth for: Counts during normal sync                  │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

### 1.2 Source of Truth by Scenario

| Scenario | Source of Truth | Why |
|----------|-----------------|-----|
| Normal sync (`in_sync`) | **Device → Firestore → Device** | Device counts forwarded to Firestore, then claim-filtered items pushed back |
| New device setup | **App (empty)** | Device starts with no items; user claims one to assign category |
| Re-pairing (`in_sync` + unknown) | **App (empty)** | Device was unpaired; treat as fresh setup even though handshake says `in_sync` |
| Real-time (connected) | **Device** | Immediate feedback on button press |
| Offline (disconnected) | **Device** | Only place tracking increments |

> **Note:** After handshake, the app pushes claim-filtered items to the device via `RefreshDeviceItemsUseCase`.

---

## 2. Data Storage Layers

### 2.1 Firestore Schema

```
users/
└── {uid}/
    │
    │   ── User document fields ──
    │   last_selected_device_item_id: 3     ← Device slot of last selected item
    │   onboarding_completed: true
    │   onboarding_device_paired: true
    │   onboarding_item_created: true
    │   primary_use_case: "habit_tracking"  ← Optional
    │   referral_source: "friend"           ← Optional
    │
    │   paired_devices: [                   ← Array of paired device objects
    │     {
    │       device_instance_id: "AA:BB:CC:DD:EE:FF"
    │       device_name: "Traxelos One (1)"
    │       paired_at: Timestamp
    │       color: 0                        ← Palette index (0-9)
    │       stale_claims: ["Water"]         ← Items released while offline
    │     }
    │   ]
    │
    ├── items/
    │   └── {itemId}/
    │       ├── item_name: "Push-ups"       ← Note: "item_name" not "name"
    │       ├── count: 1523
    │       ├── todaycount: 75              ← Note: lowercase, no underscore
    │       ├── increment_by: 1
    │       ├── reminder: "NONE"            ← "NONE" | "TARGET" | "INTERVAL"
    │       ├── reminder_value: 100
    │       ├── lastResetTime: int (ms)     ← Milliseconds since epoch
    │       ├── reset_number: 15
    │       ├── lastUpdated: int (ms)
    │       ├── uid: DocumentReference      ← Reference to users/{uid}
    │       ├── user_id: "abc123"           ← String copy of uid
    │       ├── order: 0                    ← Global sort order
    │       ├── initial_count: 0            ← Count at start of current cycle
    │       ├── goal: 100                   ← Optional daily goal
    │       ├── category_id: "cat123"       ← Optional category reference
    │       ├── category_order: 0           ← Sort order within category
    │       ├── device_item_id: 0           ← Maps to device slot (0-99)
    │       ├── cycle_names: {              ← Optional per-cycle labels
    │       │     "1": "Week 1", "2": "Week 2"
    │       │   }
    │       ├── cycle_notes: {              ← Optional per-cycle notes
    │       │     "1": "Started strong"
    │       │   }
    │       ├── claimed_by: "AA:BB:CC:DD:EE:FF"  ← Device instance ID
    │       ├── claimed_at: Timestamp       ← When claimed
    │       └── deletedAt: int (ms)         ← Soft-delete timestamp
    │
    └── (No separate syncState or devices subcollection —
         sync state and paired devices are fields on the user document)
```

### 2.2 Device NVS Schema

```
NVS Namespace: "counter"

Per-Item (index 0-99):              Global:
├── did_<i>   → deviceItemId        ├── item_total     → count of items
├── n_<i>     → name                ├── selected_did   → current selection
├── cat_<i>  → category            ├── selected_index → index of selection
├── c_<i>    → count               ├── paired_uid     → Firebase UID
├── tc_<i>   → todaycount          ├── tz_offset      → minutes from UTC
├── i_<i>    → increment           └── last_reset_date→ "YYYY-MM-DD"
├── r_<i>    → reminder type
├── rv_<i>   → reminder value
├── g_<i>    → goal
├── lr_<i>   → lastResetTime
└── rn_<i>   → resetNumber
```

### 2.3 App State (BLoC)

```dart
class BluetoothState {
  // Connection (multi-device)
  BluetoothStatus status;                              // ready, scanning, etc.
  Map<String, DeviceConnectionState> connectedDevices;  // instanceId → state
  List<PairedDevice> pairedDevices;                      // all paired devices
  String? connectingDeviceId;                           // device currently connecting

  // Per-device connection state
  // DeviceConnectionState tracks: device info, sync status (handshaking,
  // synced, staleClaim, etc.), and the device's selected item
}
```

> **Single-device vs multi-device:** When `connectedDevices.length < 2`, the app operates in classic single-device mode — no color tinting, no claim UI. When `>= 2`, exclusive leasing activates: each item can be claimed by one device at a time, and devices only see their claimed items.

---

## 3. Connection & Handshake Flow

### 3.1 Connection Sequence

```
┌─────────────────┐                              ┌─────────────────┐
│       APP       │                              │     DEVICE      │
└────────┬────────┘                              └────────┬────────┘
         │                                                │
         │  ① BLE Scan (filter: service UUID)              │
         │ ─────────────────────────────────────────────►│
         │                                                │
         │  ② Stop scan + wait 2s (GATT 133 prevention)  │
         │                                                │
         │  ③ Connect + MTU negotiation                  │
         │ ◄─────────────────────────────────────────────│
         │                                                │
         │  ④ Subscribe to NOTIFY characteristic         │
         │ ─────────────────────────────────────────────►│
         │                                                │
         │  ⑤ Send handshake (FIRST command!)              │
         │ ─────────────────────────────────────────────►│
         │  {"cmd":"handshake","uid":"xxx"}              │
         │                                                │
         │  ⑥ Receive handshake response                 │
         │ ◄─────────────────────────────────────────────│
         │  {"status":"...",                            │
         │   "protocol_version":3,                      │
         │   "firmware_version":"2.1.0"}                │
         │                                                │
         │  ⑦ Branch based on status...                  │
         │                                                │
```

### 3.2 Handshake Decision Tree

```
                        ┌──────────────────┐
                        │   HANDSHAKE      │
                        │   RESPONSE       │
                        └────────┬─────────┘
                                 │
         ┌───────────────────────┴───────────────────────┐
         │                                               │
         ▼                                               ▼
┌─────────────────┐                            ┌─────────────────┐
│   "in_sync"     │                            │ "uninitialized" │
│                 │                            │                 │
│ Device paired   │                            │ No UID stored   │
│ to this UID     │                            │                 │
└────────┬────────┘                            └────────┬────────┘
         │                                              │
         ▼                                              ▼
┌─────────────────┐                            ┌─────────────────┐
│ Is device in    │                            │ Device shows    │
│ pairedDevices?  │                            │ "AWAITING       │
│                 │                            │  SETUP"         │
└────────┬────────┘                            └────────┬────────┘
    ┌────┴────┐                                         │
    │YES      │NO                                       │
    ▼         ▼                                         ▼
┌────────┐ ┌────────┐                         ┌─────────────────┐
│ Normal │ │Redirect│                         │ App shows       │
│ sync:  │ │to      │                         │ setup wizard    │
│ prefs  │ │Device  │                         │                 │
│ + logs │ │Setup   │                         └────────┬────────┘
└───┬────┘ │Required│                                  │
    │      │(empty) │                                  │
    │      └───┬────┘                                  │
    │          └───────────────────────────┬───────────┘
    ▼                                      │
┌─────────────────┐                        ▼
│ Refresh device  │             ┌─────────────────┐
│ items (set_items│             │ Override        │
│ with claims)    │             │ Protocol        │
└─────────────────┘             │ (App → Device)  │
                                └─────────────────┘

                                         │
                        ┌────────────────┴────────────────┐
                        ▼                                 │
              ┌─────────────────┐                         │
              │ "wrong_account" │                         │
              │                 │                         │
              │ UID mismatch    │                         │
              └────────┬────────┘                         │
                       │                                  │
                       ▼                                  │
              ┌─────────────────┐                         │
              │ Device shows    │                         │
              │ "PAIRED TO      │                         │
              │  OTHER ACCOUNT" │                         │
              └────────┬────────┘                         │
                       │                                  │
                       ▼                                  │
              ┌─────────────────┐                         │
              │ App shows error │                         │
              │ Must factory    │                         │
              │ reset device    │                         │
              └─────────────────┘                         │
```

---

## 4. Sync Scenarios

### 4.1 Normal Sync

**When:** Any paired device connects
**Flow:** Device counts → Firestore, then claim-filtered items → Device

```
┌─────────┐           ┌─────────┐           ┌─────────┐
│FIRESTORE│           │   APP   │           │ DEVICE  │
└────┬────┘           └────┬────┘           └────┬────┘
     │                     │                     │
     │                     │ ① handshake(uid)    │
     │                     │ ───────────────────►│
     │                     │                     │
     │                     │ ② {status:in_sync,  │
     │                     │    device_instance_id,
     │                     │    protocol_version:3}
     │                     │ ◄───────────────────│
     │                     │                     │
     │                     │ ③ prefs (automatic) │
     │                     │ ◄───────────────────│
     │                     │   [Device counts!]  │
     │                     │                     │
     │                     │ ④ logs (automatic)  │
     │                     │ ◄───────────────────│
     │                     │                     │
     │ ⑤ Write counts      │                     │
     │ ◄───────────────────│                     │
     │   (from device)     │                     │
     │                     │                     │
     │ ⑥ Read claimed items│                     │
     │ ◄───────────────────│                     │
     │   (for this device) │                     │
     │                     │                     │
     │                     │ ⑦ RefreshDeviceItems │
     │                     │   (claim-filtered)  │
     │                     │ ───────────────────►│
     │                     │                     │ Updates NVS with
     │                     │                     │ claimed items only
     │                     │                     │

Data Flow:
  1. Device counts → App state → Firestore (preserve device's work)
  2. Firestore claimed items → App → Device (push latest assignments)
```

### 4.2 New Device Setup

**When:** Device has never been paired (`paired_uid` empty)
**Source of Truth:** Firestore

```
┌─────────┐           ┌─────────┐           ┌─────────┐
│FIRESTORE│           │   APP   │           │ DEVICE  │
└────┬────┘           └────┬────┘           └────┬────┘
     │                     │                     │
     │                     │ ① handshake(uid)    │
     │                     │ ───────────────────►│ No UID stored
     │                     │                     │
     │                     │ ② {status:          │
     │                     │    uninitialized,   │
     │                     │    protocol_version:3}
     │                     │ ◄───────────────────│ Shows "AWAITING
     │                     │                     │  SETUP"
     │                     │                     │
     │                     │ ③ Show setup wizard │
     │                     │                     │
     │                     │ ④ override_start    │
     │                     │ ───────────────────►│
     │                     │ (uid, 0 items)      │ Stores UID!
     │                     │                     │ (Pairing complete)
     │                     │                     │
     │                     │ ⑤ override_end      │
     │                     │ ───────────────────►│
     │                     │ (selected_id: -1)   │ No selection
     │                     │                     │
     │                     │ ⑥ {override_complete}
     │                     │ ◄───────────────────│
     │                     │                     │

Data Flow:
  App → Device NVS (UID only; no items sent)
  Device starts empty — user must claim an item to assign it a category.
```

### 4.4 Wrong Account

**When:** Device paired to different Firebase UID
**Resolution:** Factory reset required

```
┌─────────┐           ┌─────────┐           ┌─────────┐
│FIRESTORE│           │   APP   │           │ DEVICE  │
└────┬────┘           └────┬────┘           └────┬────┘
     │                     │                     │
     │                     │ ① handshake(uid_A)  │
     │                     │ ───────────────────►│ Has uid_B stored
     │                     │                     │
     │                     │ ② {status:          │
     │                     │    wrong_account,   │
     │                     │    protocol_version:3}
     │                     │ ◄───────────────────│ Shows "PAIRED TO
     │                     │                     │  OTHER ACCOUNT"
     │                     │                     │
     │                     │ ③ Show error dialog │
     │                     │   "Device belongs   │
     │                     │    to another       │
     │                     │    account"         │
     │                     │                     │
     │                     │ ④ Disconnect        │
     │                     │ ───────────────────►│
     │                     │                     │

Resolution options:
  A) Log into the correct account (uid_B)
  B) Factory reset the device (clears paired_uid)
```

---

## 5. Real-time Event Flow

### 5.1 Button Press (Connected)

```
┌─────────┐           ┌─────────┐           ┌─────────┐
│FIRESTORE│           │   APP   │           │ DEVICE  │
└────┬────┘           └────┬────┘           └────┬────┘
     │                     │                     │
     │                     │                     │ ① User presses
     │                     │                     │   increment button
     │                     │                     │
     │                     │                     │ ② count++ in RAM
     │                     │                     │   Check reminder
     │                     │                     │   Log to buffer
     │                     │                     │
     │                     │ ③ event notification│
     │                     │ ◄───────────────────│
     │                     │ {type:event,        │
     │                     │  event:increment,   │
     │                     │  timestamp, count}  │
     │                     │                     │
     │                     │ ④ item_delta notif. │
     │                     │ ◄───────────────────│
     │                     │ {type:item_delta,   │
     │                     │  count, todaycount} │
     │                     │                     │
     │                     │ ⑤ Update BLoC state │
     │                     │   Update UI         │
     │                     │                     │
     │ ⑥ Write to Firestore│                     │
     │ ◄───────────────────│                     │
     │   (async)           │                     │
     │                     │                     │

Timing:
  Button → item_delta (inline) → Event (queued, ~10ms later)

Why two notifications?
  • event: For history/logging (has timestamp, event type)
  • item_delta: For UI state (has todaycount, lastResetTime)
```

### 5.2 Selection Change (From App)

```
┌─────────┐           ┌─────────┐           ┌─────────┐
│FIRESTORE│           │   APP   │           │ DEVICE  │
└────┬────┘           └────┬────┘           └────┬────┘
     │                     │                     │
     │                     │ ① User taps item   │
     │                     │   in app UI        │
     │                     │                     │
     │                     │ ② set_selected(id) │
     │                     │ ───────────────────►│
     │                     │                     │ ③ Flush old item
     │                     │                     │   Load new item
     │                     │                     │   Update display
     │                     │                     │
     │                     │ ④ item_delta       │
     │                     │ ◄───────────────────│
     │                     │ {id, count,        │
     │                     │  todaycount,...}   │
     │                     │                     │
     │                     │ ⑤ Update BLoC      │
     │                     │   (use device vals)│
     │                     │                     │

Note: No 'event' notification because no action occurred
      (switching is not an increment/reset)
```

### 5.3 Selection Change (From Device)

```
┌─────────┐           ┌─────────┐           ┌─────────┐
│FIRESTORE│           │   APP   │           │ DEVICE  │
└────┬────┘           └────┬────┘           └────┬────┘
     │                     │                     │
     │                     │                     │ ① User presses
     │                     │                     │   switch button
     │                     │                     │
     │                     │                     │ ② Change selection
     │                     │                     │   (cycle to next)
     │                     │                     │
     │                     │ ③ event notification│
     │                     │ ◄───────────────────│
     │                     │ {type:event,        │
     │                     │  event:switch,      │
     │                     │  itemId:newId}      │
     │                     │                     │
     │                     │ ④ Update BLoC      │
     │                     │   selectedId       │
     │                     │                     │

Note: Only 'event', no 'item_delta'
      (item_delta for the new item wasn't needed
       because counts didn't change)
```

### 5.4 Category Deletion (While Connected)

```
┌─────────┐           ┌─────────┐           ┌─────────┐
│FIRESTORE│           │   APP   │           │ DEVICE  │
└────┬────┘           └────┬────┘           └────┬────┘
     │                     │                     │
     │                     │ ① User deletes      │
     │                     │   category from      │
     │                     │   Manage Categories  │
     │                     │                     │
     │ ② Soft-delete       │                     │
     │   category          │                     │
     │ ◄───────────────────│                     │
     │   (set deleted_at)  │                     │
     │                     │                     │
     │ ③ Batch clear       │                     │
     │   category_id from  │                     │
     │   all items         │                     │
     │ ◄───────────────────│                     │
     │                     │                     │
     │                     │ ④ Wait 500ms for    │
     │                     │   Firestore batch   │
     │                     │                     │
     │                     │ ⑤ Fetch updated     │
     │ ──────────────────► │   items             │
     │                     │                     │
     │                     │ ⑥ If selected item  │
     │                     │   was in deleted    │
     │                     │   category:         │
     │                     │   set_items (uncat) │
     │                     │ ───────────────────►│
     │                     │   set_selected      │
     │                     │ ───────────────────►│
     │                     │                     │ ⑦ Device updates
     │                     │                     │   to uncategorized
     │                     │                     │   items
     │                     │                     │

Key points:
  • Sync happens from manage_categories_page, not items_list_page
    (items page is disposed on tab switch — ShellRoute)
  • Only syncs if selected item was in the deleted category
  • Items list page resets stale BLoC filter on return via
    FilterByCategoryEvent(null)
```

---

## 6. Offline & Reconnection

### 6.1 Offline Operation

```
┌─────────────────────────────────────────────────────────────────────┐
│                    DEVICE (Disconnected)                             │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  User presses buttons...                                            │
│                                                                      │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐             │
│  │  Button     │───►│  RAM        │───►│  NVS        │             │
│  │  Press      │    │  count++    │    │  (every 10) │             │
│  └─────────────┘    │  log event  │    └─────────────┘             │
│                     └─────────────┘                                  │
│                                                                      │
│  Data accumulates:                                                   │
│  • Counts in RAM (flushed to NVS every 10 increments)               │
│  • Events in RAM buffer (up to 1000 entries)                        │
│                                                                      │
│  ⚠️ Risk: Up to 9 increments lost on sudden power loss              │
│     (mitigated by 5-minute periodic flush)                          │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 6.2 Reconnection Sync

```
┌─────────┐           ┌─────────┐           ┌─────────┐
│FIRESTORE│           │   APP   │           │ DEVICE  │
└────┬────┘           └────┬────┘           └────┬────┘
     │                     │                     │
     │                     │ ① Connect          │
     │                     │ ───────────────────►│
     │                     │                     │
     │                     │ ② handshake(uid)   │
     │                     │ ───────────────────►│
     │                     │                     │
     │                     │ ③ {status:in_sync, │
     │                     │    device_instance_id,
     │                     │    protocol_version:3}
     │                     │ ◄───────────────────│
     │                     │                     │
     │                     │ ④ Check stale claims│
     │                     │   (from paired_devices
     │                     │    staleClaims list) │
     │                     │                     │
     │                     │ ⑤ prefs             │ Includes offline
     │                     │ ◄───────────────────│ increments!
     │                     │ [count: 1598]       │
     │                     │                     │
     │                     │ ⑥ logs              │ Includes offline
     │                     │ ◄───────────────────│ events!
     │                     │ [15 events...]      │
     │                     │                     │
     │ ⑦ Write new counts  │                     │
     │ ◄───────────────────│                     │
     │   1523 → 1598       │                     │
     │                     │                     │
     │ ⑧ Write events      │                     │
     │ ◄───────────────────│                     │
     │   (to activity log) │                     │
     │                     │                     │
     │                     │ ⑨ RefreshDeviceItems│
     │                     │ ───────────────────►│ Push claim-filtered
     │                     │   (claimed items)   │ items to device
     │                     │                     │
     │                     │ ⑩ clear_logs        │
     │                     │ ───────────────────►│ Prevent duplicates
     │                     │                     │

Key insight: Device accumulated counts while offline
             → App forwards device counts to Firestore
             → App pushes claim-filtered items back to device
             → If stale claims detected, "Items Released" dialog shown first
```

---

## 7. Multi-Device Sync

### 7.1 Two Devices, Same Account (Stateless Model)

```
Timeline showing Device A and Device B connecting to same account:

Time    App                  Device A              Device B
────    ───────              ────────              ────────
T0      [Firestore: item "Water" claimed by A]

T1      Connect A ───────────►
        handshake(uid) ──────►
                              {in_sync}
                              prefs: count=105 ──►
        Write Firestore ◄──── count=105
        RefreshDeviceItems ──► (A's claimed items)

T2      Disconnect A ◄────────

T3                            User increments
                              count → 108
                              (offline)

T4      Connect B ────────────────────────────────►
        handshake(uid) ──────────────────────────►
                                                   {in_sync}
                                                   prefs: count=200 ─►
        Write Firestore ◄──── count=200 (B's items)
        RefreshDeviceItems ──────────────────────► (B's claimed items)

T5      Connect A ───────────►
        handshake(uid) ─────►
                              {in_sync}
                              prefs: count=108 ──►
        Write Firestore ◄──── count=108 (A's items)
        RefreshDeviceItems ──► (A's claimed items)

No conflicts by design! Each device only reports counts for its
own items. Exclusive leasing (claimed_by) prevents two devices
from modifying the same item.
```

### 7.2 Handshake Decision Logic

```
                ┌─────────────────────────────┐
                │   App connects to device     │
                │   App sends handshake(uid)   │
                └──────────────┬──────────────┘
                               │
                               ▼
                  ┌────────────────────────┐
                  │ Device checks UID      │
                  └──────────┬─────────────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
         ▼                   ▼                   ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│  UID matches    │ │  No UID stored  │ │  UID mismatch   │
│                 │ │                 │ │                 │
│ "in_sync"       │ │ "uninitialized" │ │ "wrong_account" │
│                 │ │                 │ │                 │
└────────┬────────┘ └────────┬────────┘ └────────┬────────┘
         │                   │                   │
         ▼                   ▼                   ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│ Normal flow:    │ │ Override flow:  │ │ Error dialog:   │
│ prefs/logs      │ │ empty setup    │ │ factory reset   │
│ then push items │ │ (App → Device) │ │ required        │
└─────────────────┘ └─────────────────┘ └─────────────────┘
```

### 7.3 Cross-Category Push Optimization

When a device switches items, the app pushes updated item lists to other connected devices. However, devices in different categories don't need each other's updates.

```
BLoC maintains: _deviceCategories = { deviceId → categoryId }

On claim change (device A switches item):
  1. resolveCategory(A) → look up A's new category from Firestore (no BLE send)
  2. _deviceCategories[A] = resolved category
  3. For each other online device B:
     - If _deviceCategories[B] != _deviceCategories[A] → SKIP (different category)
     - Otherwise → RefreshDeviceItems(B) → sends filtered item list over BLE

Result: If BLUE is in "Fruits" and GREEN is in "Vegetables",
        switching an item on BLUE does NOT push to GREEN.
```

**Key design choice:** `resolveCategory()` is a lightweight Firestore-only lookup (no BLE send). The full `RefreshDeviceItemsUseCase.call()` sends items over BLE — calling it on the source device would redundantly push items it already has.

### 7.4 Item Reorder / Drag-and-Drop (Multi-Device)

```
┌─────────┐           ┌─────────┐           ┌─────────┐
│FIRESTORE│           │   APP   │           │ DEVICES │
└────┬────┘           └────┬────┘           └────┬────┘
     │                     │                     │
     │                     │ ① User reorders     │
     │                     │   items via drag    │
     │                     │                     │
     │ ② Write new order   │                     │
     │ ◄───────────────────│                     │
     │   (categoryOrder)   │                     │
     │                     │                     │
     │ ③ watchItems stream │                     │
     │ ───────────────────►│                     │
     │                     │                     │
     │                     │ ④ _checkDeviceSync  │
     │                     │   detects signature │
     │                     │   change            │
     │                     │                     │
     │                     │ ⑤ RefreshAllDevices │
     │                     │ ───────────────────►│
     │                     │   (each device gets │
     │                     │    claim-filtered   │
     │                     │    item list)       │
     │                     │                     │

Single device: uses SendItemsToDevice (legacy path)
Multi-device:  uses RefreshAllDevices → _pushToAllDevices()
               Each device receives only its claimed items
               in the updated order.
               Only devices in affected categories get pushed
               (source + target of the move); others are skipped.
```

### 7.5 Item Claim Sequence (Multi-Device)

When a user activates (claims) an item for a device, the following sequence runs. Claiming is entirely app-side — no BLE "claim" command exists. The device learns about claims when the app sends filtered item lists.

```
User              App (BLoC)           Firestore              Device A        Device B
│                 │                    │                      │               │
│ ① Swipe item,  │                    │                      │               │
│   tap Activate, │                    │                      │               │
│   select Dev A  │                    │                      │               │
│ ───────────────►│                    │                      │               │
│                 │                    │                      │               │
│                 │ ② Optimistic       │                      │               │
│                 │   selectedItemId   │                      │               │
│                 │   = item X         │                      │               │
│                 │   (instant UI)     │                      │               │
│                 │                    │                      │               │
│                 │ ③ ClaimItem enters │                      │               │
│                 │   global queue     │                      │               │
│                 │   ─────────────────┤                      │               │
│                 │                    │                      │               │
│                 │ ④ atomicClaimSwap  │                      │               │
│                 │ ───────────────────►                      │               │
│                 │   (transaction:    │                      │               │
│                 │    release prev,   │                      │               │
│                 │    claim new)      │                      │               │
│                 │                    │                      │               │
│                 │ ⑤ watchItems       │                      │               │
│                 │ ◄──────────────────┤ stream fires         │               │
│                 │   claimed_by = A   │                      │               │
│                 │                    │                      │               │
│                 │ ⑥ _pushToOtherDevices (skips Device A)    │               │
│                 │ ──────────────────────────────────────────────────────────►
│                 │   (B gets: unclaimed + B's items — item X removed)        │
│                 │                    │                      │               │
│                 │ ⑦ watchItems stream updates Device A's local state        │
│                 │   (A sees confirmed claim; no direct BLE push needed)     │
│                 │                    │                      │               │

On claim FAILURE (item already claimed by another device):
│                 │ ④' ClaimConflict   │                      │               │
│                 │ ◄──────────────────┤                      │               │
│                 │                    │                      │               │
│                 │ ⑤' Corrective push │                      │               │
│                 │ ──────────────────────────────────────────►               │
│                 │   (revert device   │                      │               │
│                 │    to correct list)│                      │               │
│                 │                    │                      │               │
│                 │ ⑥' Revert BLoC     │                      │               │
│                 │   selectedItemId   │                      │               │
│                 │   = previousItemId │                      │               │
```

**Device-filtered item lists:** When the app sends items to a device via `set_items`, it filters:
- `claimedBy == null` (unclaimed) OR `claimedBy == thisDevice`
- Within the selected item's category only

Each device sees only its own items. Devices in different categories don't affect each other.

### 7.6 atomicClaimSwap Internals

The claim transaction (`item_remote_datasource_impl.dart`) runs inside the global claim queue (see [ADR-005](decisions/ADR-005-global-claim-queue.md)):

```
atomicClaimSwap(newItemId, deviceInstanceId, previousItemId):

  ┌─────────────────────────────────────────────────┐
  │ 1. PRE-QUERY (outside transaction)              │
  │    Query: WHERE claimed_by == deviceInstanceId   │
  │    Result: actualPrevId (real claim, not stale   │
  │    BLoC state)                                   │
  └──────────────────────┬──────────────────────────┘
                         │
  ┌──────────────────────▼──────────────────────────┐
  │ 2. FIRESTORE TRANSACTION                        │
  │                                                  │
  │  a) Read newItem document                       │
  │  b) Read actualPrevItem document (if different) │
  │     (all reads before any writes — Firestore    │
  │      requirement)                                │
  │                                                  │
  │  c) Validate newItem:                           │
  │     - claimed_by == deviceInstanceId? → no-op   │
  │     - claimed_by == someOtherDevice?            │
  │       → ClaimConflictException                  │
  │     - claimed_by == null? → proceed             │
  │                                                  │
  │  d) Release previous (if we still own it):      │
  │     UPDATE actualPrevItem                       │
  │       SET claimed_by = null, claimed_at = null  │
  │     (ownership check: only if                   │
  │      prevItem.claimed_by == deviceInstanceId)   │
  │                                                  │
  │  e) Claim new:                                  │
  │     UPDATE newItem                              │
  │       SET claimed_by = deviceInstanceId         │
  │           claimed_at = serverTimestamp()         │
  └─────────────────────────────────────────────────┘

Key properties:
  - Atomic: release + claim happen in one transaction (no partial states)
  - Ownership-checked: only releases items we actually own
  - Idempotent: re-claiming our own item is a no-op
  - Serialized: global claim queue ensures no concurrent transactions
```

---

## 8. Data Consistency Rules

### 8.1 Golden Rules

| Rule | Description |
|------|-------------|
| **Handshake First** | Always send handshake as the first command after connecting |
| **Simple Handshake** | Send `handshake(uid)` — device checks UID and returns status |
| **Device Counts Forwarded** | After `in_sync`, write device prefs/logs to Firestore |
| **Push Claimed Items** | After forwarding, push claim-filtered items back to device |
| **Exclusive Leasing** | Each item claimed by at most one device (`claimed_by` field) |
| **Atomic Override** | Override is all-or-nothing (start → chunks → end) |
| **Log Before Clear** | Retrieve all log pages before calling clear_logs |

### 8.2 Count Flow Summary

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                      │
│   ┌──────────────┐                                                  │
│   │  in_sync     │                                                  │
│   └──────┬───────┘                                                  │
│          │                                                          │
│          ▼                                                          │
│   Device → App → Firestore                                          │
│                                                                      │
│   ┌──────────────┐                                                  │
│   │  override    │                                                  │
│   │  (new device │                                                  │
│   │  or stale)   │                                                  │
│   └──────┬───────┘                                                  │
│          │                                                          │
│          ▼                                                          │
│   Firestore → App → Device                                          │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 8.3 What Can Go Wrong

| Scenario | Problem | Prevention |
|----------|---------|------------|
| App crashes mid-sync | Firestore updated, device not | Override on next connect |
| Power loss on device | Up to 9 increments lost | 5-min periodic flush |
| Both devices sync simultaneously | Race condition | Firestore transactions |
| Disconnect during override | Incomplete data on device | override_end validation |
| Network error to Firestore | App and device out of sync | Retry with backoff |

### 8.4 Recovery Patterns

**App Crash Recovery:**
```
1. Next connect → handshake
2. App detects stale claim → override (Firestore wins)
3. If in_sync → normal flow (device has correct data)
```

**Device Power Loss Recovery:**
```
1. Device boots with last NVS data
2. May have lost up to 9 increments
3. Next sync → device data is source of truth
4. Lost increments cannot be recovered
```

**Network Error Recovery:**
```
1. Device sync completed, Firestore write failed
2. Next connect → normal sync (device counts forwarded again)
3. Firestore write retried
⚠️ If Firestore write keeps failing, counts may be lost
```

---

## 9. OTA Firmware Update Flow

### 9.1 Full OTA Sequence

**When:** App detects newer firmware via Firebase Storage check after device connect.
**Critical prerequisite:** Sync device count logs to Firestore before starting OTA (logs are RAM-only, lost on reboot).

```
┌──────────┐        ┌─────────┐        ┌─────────┐        ┌─────────┐
│ FIREBASE │        │   APP   │        │ DEVICE  │        │  USER   │
│ STORAGE  │        │         │        │         │        │         │
└────┬─────┘        └────┬────┘        └────┬────┘        └────┬────┘
     │                    │                  │                   │
     │                    │                  │                   │
     │                    │ ① Check latest.json                 │
     │ ◄──────────────────│                  │                   │
     │                    │                  │                   │
     │ ② {version, sha256,│                  │                   │
     │    filePath, ...}  │                  │                   │
     │ ──────────────────►│                  │                   │
     │                    │                  │                   │
     │                    │ ③ Compare device │                   │
     │                    │   firmware_version                   │
     │                    │   (from handshake)                   │
     │                    │                  │                   │
     │                    │ ④ Show update    │                   │
     │                    │   banner         │──────────────────►│
     │                    │                  │                   │
     │                    │                  │              ⑤ User taps
     │                    │ ◄───────────────────────────────────│
     │                    │                  │              "Update"
     │                    │                  │                   │
     │                    │ ⑥ Sync logs to   │                   │
     │                    │   Firestore first │                  │
     │                    │   (count logs are │                  │
     │                    │    RAM-only!)     │                  │
     │                    │                  │                   │
     │ ⑦ Download binary  │                  │                   │
     │ ◄──────────────────│                  │                   │
     │                    │                  │                   │
     │ ⑧ Binary data      │                  │                   │
     │ ──────────────────►│                  │                   │
     │                    │                  │                   │
     │                    │ ⑨ ota_start      │                   │
     │                    │ {size, sha256,   │                   │
     │                    │  version}        │                   │
     │                    │ ────────────────►│                   │
     │                    │                  │                   │
     │                    │ ⑩ {ota_ready}    │                   │
     │                    │ ◄────────────────│                   │
     │                    │                  │                   │
     │                    │ ⑪ Binary chunks  │                   │
     │                    │ (CHAR_OTA_DATA,  │                   │
     │                    │  write-with-resp)│                   │
     │                    │ ════════════════►│                   │
     │                    │  ... repeat ...  │                   │
     │                    │ ════════════════►│                   │
     │                    │                  │                   │
     │                    │ ⑫ ota_end        │                   │
     │                    │ ────────────────►│                   │
     │                    │                  │ ⑬ SHA256 verify   │
     │                    │ ⑭ {ota_verified} │                   │
     │                    │ ◄────────────────│                   │
     │                    │                  │                   │
     │                    │ ⑮ reboot         │                   │
     │                    │ ────────────────►│                   │
     │                    │                  │                   │
     │                    │ ⑯ {ota_rebooting}│                   │
     │                    │ ◄────────────────│                   │
     │                    │                  │ ⑰ Device reboots  │
     │                    │  ~~disconnect~~  │    with new       │
     │                    │                  │    firmware        │
     │                    │                  │                   │
     │                    │  ...wait up to 30s...                │
     │                    │                  │                   │
     │                    │ ⑱ Reconnect      │                   │
     │                    │ ◄────────────────│                   │
     │                    │                  │                   │
     │                    │ ⑲ handshake      │                   │
     │                    │ ────────────────►│                   │
     │                    │                  │                   │
     │                    │ ⑳ {in_sync,      │                   │
     │                    │  firmware_version│                   │
     │                    │  :"2.1.0"}       │                   │
     │                    │ ◄────────────────│                   │
     │                    │                  │                   │
     │                    │ ㉑ Version match! │                   │
     │                    │   Show success   │──────────────────►│
     │                    │                  │                   │

Data flow:
  Firebase Storage → App (binary) → Device (OTA partition)
  Device reboots → reconnects → handshake confirms new version

⚠️ Critical: Count logs are RAM-only on the device.
   Sync logs to Firestore BEFORE starting OTA, or they will be
   lost when the device reboots.
```

### 9.2 OTA Error Recovery

```
Error during download:
  → App shows error banner
  → User can retry (re-download from Firebase Storage)

Error during transfer (write_failed, timeout):
  → Device returns to IDLE state
  → App shows error, user retries from step ⑨

Error during verification (hash_mismatch):
  → Device stays on current firmware (OTA partition discarded)
  → App shows error, user re-downloads and retries

Error after reboot (device doesn't reconnect in 60s):
  → App shows timeout error
  → User can power-cycle device
  → Rollback: device boots to last working firmware
```

---

## Quick Reference

```
┌─────────────────────────────────────────────────────────────────────┐
│                    DATA FLOW QUICK REFERENCE                         │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  SOURCE OF TRUTH:                                                    │
│    • in_sync (known device) → Device counts → Firestore → push back│
│    • in_sync (unknown)      → App empty (re-pair as fresh setup)    │
│    • stale claim            → Firestore (override device)           │
│    • new device             → App empty (device starts clean)       │
│                                                                      │
│  SYNC FLOW:                                                          │
│    1. Connect                                                        │
│    2. handshake(uid) → in_sync / uninitialized / wrong_account      │
│    3. Receive prefs/logs → write to Firestore                       │
│    4. RefreshDeviceItems → push claim-filtered items to device      │
│                                                                      │
│  NOTIFICATIONS:                                                      │
│    • event      = what happened (history)                           │
│    • item_delta = current state (UI)                                │
│    • Both sent on button press; serve different purposes            │
│                                                                      │
│  CRITICAL:                                                           │
│    • ALWAYS handshake first after connect                           │
│    • ALWAYS send handshake(uid) as first command                   │
│    • ALWAYS forward device counts to Firestore                     │
│    • ALWAYS push claim-filtered items after forwarding             │
│    • NEVER assume app state is current - verify with handshake      │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```
