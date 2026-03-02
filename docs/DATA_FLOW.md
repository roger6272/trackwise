# Data Flow & Sync Scenarios

> Visual guide to how data moves through the Traxelos system.
>
> **Related docs:** [BLE Protocol](BLE_PROTOCOL.md) · [Device Display](DEVICE_DISPLAY.md) · [Troubleshooting](TROUBLESHOOTING.md)

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
│  │   users/{uid}/syncState          ← sync_seq, last sync time       │  │
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
│  │   • sync_seq_no                  • Dirty flags                    │  │
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
| Conflict (old firmware safety net) | **Firestore** | Only occurs with firmware that doesn't understand `sync_seq=-1` |
| New device setup | **App (empty)** | Device starts with no items; user claims one to assign category |
| Re-pairing (`in_sync` + unknown) | **App (empty)** | Device was unpaired; treat as fresh setup even though handshake says `in_sync` |
| Real-time (connected) | **Device** | Immediate feedback on button press |
| Offline (disconnected) | **Device** | Only place tracking increments |

> **Note:** In multi-device mode, `sync_seq` is obsolete. The app sends `sync_seq=-1` so firmware always returns `in_sync`. After handshake, the app pushes claim-filtered items to the device via `RefreshDeviceItemsUseCase`.

---

## 2. Data Storage Layers

### 2.1 Firestore Schema

```
users/
└── {uid}/
    │
    │   ── User document fields ──
    │   sync_sequence_no: 42                ← Incremented on every sync
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
├── tc_<i>   → todaycount          ├── sync_seq_no    → last sync sequence
├── i_<i>    → increment           ├── tz_offset      → minutes from UTC
├── r_<i>    → reminder type       └── last_reset_date→ "YYYY-MM-DD"
├── rv_<i>   → reminder value
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
  // synced, staleClaim, conflict, etc.), and the device's selected item
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
         │  ⑤ Fetch sync_seq from Firestore              │
         │                                                │
         │  ⑥ Send handshake (FIRST command!)            │
         │ ─────────────────────────────────────────────►│
         │  {"cmd":"handshake","uid":"xxx","sync_seq":-1}│
         │                                                │
         │  ⑦ Receive handshake response                 │
         │ ◄─────────────────────────────────────────────│
         │  {"status":"...",                            │
         │   "protocol_version":2,                      │
         │   "firmware_version":"1.3.0"}                │
         │                                                │
         │  ⑧ Branch based on status...                  │
         │                                                │
```

### 3.2 Handshake Decision Tree

```
                        ┌──────────────────┐
                        │   HANDSHAKE      │
                        │   RESPONSE       │
                        └────────┬─────────┘
                                 │
         ┌───────────────────────┼───────────────────────┐
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   "in_sync"     │    │   "conflict"    │    │ "uninitialized" │
│                 │    │                 │    │                 │
│ seq=-1 → skip  │    │ Old firmware    │    │ No UID stored   │
│ (always match)  │    │ safety net     │    │                 │
└────────┬────────┘    └────────┬────────┘    └────────┬────────┘
         │                      │                      │
         ▼                      ▼                      ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ Is device in    │    │ Device enters   │    │ Device shows    │
│ pairedDevices?  │    │ CONFLICT state  │    │ "AWAITING       │
│                 │    │ Shows "SEE APP" │    │  SETUP"         │
└────────┬────────┘    └────────┬────────┘    └────────┬────────┘
    ┌────┴────┐                 │                      │
    │YES      │NO               │                      │
    ▼         ▼                 ▼                      ▼
┌────────┐ ┌────────┐  ┌─────────────────┐    ┌─────────────────┐
│ Normal │ │Redirect│  │ App shows       │    │ App shows       │
│ sync:  │ │to      │  │ conflict dialog │    │ setup wizard    │
│ prefs  │ │Device  │  │ User confirms   │    │                 │
│ + logs │ │Setup   │  └────────┬────────┘    └────────┬────────┘
└───┬────┘ │Required│           │                      │
    │      │(empty) │           │                      │
    │      └───┬────┘           │                      │
    ▼          └────────────────┴──────────┬───────────┘
┌─────────────────┐                        │
│ sync_complete   │                        ▼
│ Update seq      │             ┌─────────────────┐
└─────────────────┘             │ Override        │
                                │ Protocol        │
                                │ (App → Device)  │
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

### 4.1 Normal Sync (Stateless Handshake)

**When:** Any device connects (multi-device mode)
**How:** App sends `sync_seq=-1` so firmware skips comparison and always returns `in_sync`
**Flow:** Device counts → Firestore, then claim-filtered items → Device

```
┌─────────┐           ┌─────────┐           ┌─────────┐
│FIRESTORE│           │   APP   │           │ DEVICE  │
└────┬────┘           └────┬────┘           └────┬────┘
     │                     │                     │
     │                     │ ① handshake(uid,    │
     │                     │    sync_seq=-1)     │
     │                     │ ───────────────────►│ -1 → skip comparison
     │                     │                     │
     │                     │ ② {status:in_sync,  │
     │                     │    device_instance_id,
     │                     │    protocol_version:2}
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

Why sync_seq=-1?
  In multi-device mode, sync_seq is obsolete — each device connection
  would increment the global counter, causing every reconnection to
  be a "conflict". Sending -1 tells firmware to skip the comparison.
```

### 4.2 Conflict Resolution (Old Firmware Safety Net)

**When:** Firmware doesn't understand `sync_seq=-1` and compares against its stored value
**Trigger:** Only old firmware that predates the stateless model
**BLoC behavior:** Auto-overrides for already-paired devices (no user dialog)

```
┌─────────┐           ┌─────────┐           ┌─────────┐
│FIRESTORE│           │   APP   │           │ DEVICE  │
└────┬────┘           └────┬────┘           └────┬────┘
     │                     │                     │
     │                     │ ① handshake(seq=-1) │
     │                     │ ───────────────────►│ Old firmware compares
     │                     │                     │ -1 ≠ stored seq
     │                     │                     │
     │                     │ ② {status:conflict, │
     │                     │    device_seq:N}    │
     │                     │ ◄───────────────────│ Buttons disabled!
     │                     │                     │
     │                     │ ③ BLoC detects      │
     │                     │   device is paired  │
     │                     │   → auto-override   │
     │                     │                     │
     │ ④ Read claimed items│                     │
     │ ◄───────────────────│                     │
     │                     │                     │
     │                     │ ⑤ override_start    │
     │                     │ ───────────────────►│ Clears NVS items
     │                     │                     │
     │                     │ ⑥ override_chunk ×N │
     │                     │ ───────────────────►│ Writes to NVS
     │                     │                     │
     │                     │ ⑦ override_end      │
     │                     │ ───────────────────►│ Buttons enabled!
     │                     │                     │
     │                     │ ⑧ {override_complete}
     │                     │ ◄───────────────────│
     │                     │                     │

Data Flow:
  Firestore items → App → Device NVS
  Firestore is source of truth (device data overwritten)
```

### 4.3 New Device Setup

**When:** Device has never been paired (`paired_uid` empty)
**Source of Truth:** Firestore

```
┌─────────┐           ┌─────────┐           ┌─────────┐
│FIRESTORE│           │   APP   │           │ DEVICE  │
└────┬────┘           └────┬────┘           └────┬────┘
     │                     │                     │
     │                     │ ① handshake(uid,seq)│
     │                     │ ───────────────────►│ No UID stored
     │                     │                     │
     │                     │ ② {status:          │
     │                     │    uninitialized,   │
     │                     │    protocol_version:2}
     │                     │ ◄───────────────────│ Shows "AWAITING
     │                     │                     │  SETUP"
     │                     │                     │
     │                     │ ③ Show setup wizard │
     │                     │                     │
     │                     │ ④ override_start    │
     │                     │ ───────────────────►│
     │                     │ (uid, seq, 0 items) │ Stores UID!
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
     │                     │    protocol_version:2}
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
  Button → Event (immediate) → item_delta (+50ms)

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
     │                     │ ② handshake(seq=-1)│
     │                     │ ───────────────────►│
     │                     │                     │
     │                     │ ③ {status:in_sync, │
     │                     │    device_instance_id,
     │                     │    protocol_version:2}
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
        handshake(seq=-1) ───►
                              {in_sync}
                              prefs: count=105 ──►
        Write Firestore ◄──── count=105
        RefreshDeviceItems ──► (A's claimed items)

T2      Disconnect A ◄────────

T3                            User increments
                              count → 108
                              (offline)

T4      Connect B ────────────────────────────────►
        handshake(seq=-1) ───────────────────────►
                                                   {in_sync}
                                                   prefs: count=200 ─►
        Write Firestore ◄──── count=200 (B's items)
        RefreshDeviceItems ──────────────────────► (B's claimed items)

T5      Connect A ───────────►
        handshake(seq=-1) ───►
                              {in_sync}
                              prefs: count=108 ──►
        Write Firestore ◄──── count=108 (A's items)
        RefreshDeviceItems ──► (A's claimed items)

No conflict! Each device only reports counts for its own items.
Exclusive leasing (claimed_by) prevents two devices from
modifying the same item.
```

### 7.2 Handshake Decision Logic (Stateless)

```
                ┌─────────────────────────────┐
                │   App connects to device     │
                │   App sends sync_seq = -1    │
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
│ seq=-1 → skip  │ │ "uninitialized" │ │ "wrong_account" │
│ comparison      │ │                 │ │                 │
│                 │ └────────┬────────┘ └────────┬────────┘
│ "in_sync"       │          │                   │
└────────┬────────┘          ▼                   ▼
         │          ┌─────────────────┐ ┌─────────────────┐
         ▼          │ Override flow:  │ │ Error dialog:   │
┌─────────────────┐ │ empty setup    │ │ factory reset   │
│ Normal flow:    │ │ (App → Device) │ │ required        │
│ prefs/logs      │ └─────────────────┘ └─────────────────┘
│ then push items │
└─────────────────┘
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

---

## 8. Data Consistency Rules

### 8.1 Golden Rules

| Rule | Description |
|------|-------------|
| **Handshake First** | Always send handshake as the first command after connecting |
| **Stateless Handshake** | Send `sync_seq=-1` to skip comparison (multi-device mode) |
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
│   │  conflict    │                                                  │
│   │  or          │                                                  │
│   │  uninitialized│                                                 │
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
2. If conflict → override (Firestore wins)
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
1. Device sync completed (sync_complete sent)
2. Firestore write failed
3. Next connect → conflict (device has newer seq)
4. Override with Firestore data
⚠️ Device increments since last successful Firestore write are lost
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
│    • conflict (old firmware) → Firestore (auto-override for paired) │
│    • new device             → App empty (device starts clean)       │
│                                                                      │
│  SYNC FLOW (stateless):                                              │
│    1. Connect                                                        │
│    2. handshake(uid, sync_seq=-1) → always in_sync                  │
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
│    • ALWAYS send sync_seq=-1 (stateless multi-device mode)         │
│    • ALWAYS forward device counts to Firestore                     │
│    • ALWAYS push claim-filtered items after forwarding             │
│    • NEVER assume app state is current - verify with handshake      │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```
