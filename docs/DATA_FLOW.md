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
│  │   • Connection state                                              │  │
│  │   • sync_seq (from Firestore)                                     │  │
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
| Normal sync (`in_sync`) | **Device** | User may have incremented while disconnected |
| Conflict sync | **Firestore** | Another device synced more recently |
| New device setup | **Firestore** | Device has no data yet |
| Real-time (connected) | **Device** | Immediate feedback on button press |
| Offline (disconnected) | **Device** | Only place tracking increments |

---

## 2. Data Storage Layers

### 2.1 Firestore Schema

```
users/
└── {uid}/
    ├── items/
    │   └── {itemId}/
    │       ├── name: "Push-ups"
    │       ├── category: "Exercise"
    │       ├── count: 1523
    │       ├── todaycount: 75
    │       ├── increment: 1
    │       ├── reminder: 1
    │       ├── reminderValue: 100
    │       ├── lastResetTime: Timestamp
    │       ├── resetNumber: 15
    │       └── deviceItemId: 0          ← Maps to device slot
    │
    ├── syncState/
    │   ├── syncSeq: 42                  ← Incremented on every sync
    │   └── lastSyncTime: Timestamp
    │
    └── devices/
        └── {deviceInstanceId}/
            ├── lastSeen: Timestamp
            └── syncSeq: 42              ← Last sync_seq this device saw
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
  // Connection
  BluetoothConnectionStatus status;
  BleDeviceEntity? connectedDevice;

  // Items (from device during sync, from Firestore otherwise)
  List<ItemEntity> items;
  int? selectedItemId;

  // Sync tracking
  int syncSeq;              // From Firestore
  int? deviceSyncSeq;       // From handshake response
  SyncStatus syncStatus;    // in_sync, conflict, etc.
}
```

---

## 3. Connection & Handshake Flow

### 3.1 Connection Sequence

```
┌─────────────────┐                              ┌─────────────────┐
│       APP       │                              │     DEVICE      │
└────────┬────────┘                              └────────┬────────┘
         │                                                │
         │  ① BLE Scan (filter: "Traxelos")              │
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
         │  {"cmd":"handshake","uid":"xxx","sync_seq":42}│
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
│ sync_seq match  │    │ sync_seq differ │    │ No UID stored   │
└────────┬────────┘    └────────┬────────┘    └────────┬────────┘
         │                      │                      │
         ▼                      ▼                      ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ Device sends    │    │ Device enters   │    │ Device shows    │
│ prefs + logs    │    │ CONFLICT state  │    │ "AWAITING       │
│ automatically   │    │ Shows "SEE APP" │    │  SETUP"         │
└────────┬────────┘    └────────┬────────┘    └────────┬────────┘
         │                      │                      │
         ▼                      ▼                      ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ App uses device │    │ App shows       │    │ App shows       │
│ counts (source  │    │ conflict dialog │    │ setup wizard    │
│ of truth)       │    │ User confirms   │    │                 │
└────────┬────────┘    └────────┬────────┘    └────────┬────────┘
         │                      │                      │
         ▼                      └──────────┬───────────┘
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

### 4.1 Normal Sync (in_sync)

**When:** Device and Firestore have matching `sync_seq`
**Source of Truth:** Device

```
┌─────────┐           ┌─────────┐           ┌─────────┐
│FIRESTORE│           │   APP   │           │ DEVICE  │
└────┬────┘           └────┬────┘           └────┬────┘
     │                     │                     │
     │ ① Read sync_seq=42  │                     │
     │ ◄───────────────────│                     │
     │                     │                     │
     │                     │ ② handshake(seq=42) │
     │                     │ ───────────────────►│
     │                     │                     │
     │                     │ ③ {status:in_sync,  │
     │                     │    protocol_version:2}
     │                     │ ◄───────────────────│
     │                     │                     │
     │                     │ ④ prefs (automatic) │
     │                     │ ◄───────────────────│
     │                     │   [Device counts!]  │
     │                     │                     │
     │                     │ ⑤ logs (automatic)  │
     │                     │ ◄───────────────────│
     │                     │                     │
     │ ⑥ Write counts      │                     │
     │ ◄───────────────────│                     │
     │   (from device)     │                     │
     │                     │                     │
     │ ⑦ Increment seq→43  │                     │
     │ ◄───────────────────│                     │
     │                     │                     │
     │                     │ ⑧ sync_complete(43) │
     │                     │ ───────────────────►│
     │                     │                     │
     │                     │ ⑨ {seq_updated}     │
     │                     │ ◄───────────────────│
     │                     │                     │

Data Flow:
  Device counts → App state → Firestore
  Device is source of truth
```

### 4.2 Conflict Resolution

**When:** Device has `sync_seq=40`, Firestore has `sync_seq=42`
**Source of Truth:** Firestore (another device synced more recently)

```
┌─────────┐           ┌─────────┐           ┌─────────┐
│FIRESTORE│           │   APP   │           │ DEVICE  │
└────┬────┘           └────┬────┘           └────┬────┘
     │                     │                     │
     │ ① Read seq=42       │                     │
     │ ◄───────────────────│                     │
     │                     │                     │
     │                     │ ② handshake(seq=42) │
     │                     │ ───────────────────►│ Device has seq=40
     │                     │                     │
     │                     │ ③ {status:conflict, │
     │                     │    device_seq:40,   │
     │                     │    protocol_version:2}
     │                     │ ◄───────────────────│ Buttons disabled!
     │                     │                     │ Shows "SEE APP"
     │                     │                     │
     │ ④ Read all items    │                     │
     │ ◄───────────────────│                     │
     │   (Firestore data)  │                     │
     │                     │                     │
     │                     │ ⑤ Show conflict UI  │
     │                     │   User confirms     │
     │                     │                     │
     │                     │ ⑥ override_start    │
     │                     │ ───────────────────►│
     │                     │ (uid, seq=43, N chunks)
     │                     │                     │ Clears NVS items
     │                     │                     │
     │                     │ ⑦ override_chunk ×N │
     │                     │ ───────────────────►│
     │                     │ (Firestore items)   │ Writes to NVS
     │                     │                     │
     │                     │ ⑧ override_end      │
     │                     │ ───────────────────►│
     │                     │ (selected_id)       │
     │                     │                     │ Buttons enabled!
     │                     │ ⑨ {override_complete}│ Shows "SYNCED"
     │                     │ ◄───────────────────│
     │                     │                     │
     │ ⑩ Update seq→43     │                     │
     │ ◄───────────────────│                     │
     │                     │                     │

Data Flow:
  Firestore items → App → Device NVS
  Firestore is source of truth
```

### 4.3 New Device Setup

**When:** Device has never been paired (`paired_uid` empty)
**Source of Truth:** Firestore

```
┌─────────┐           ┌─────────┐           ┌─────────┐
│FIRESTORE│           │   APP   │           │ DEVICE  │
└────┬────┘           └────┬────┘           └────┬────┘
     │                     │                     │
     │ ① Read items        │                     │
     │ ◄───────────────────│                     │
     │                     │                     │
     │                     │ ② handshake(uid,seq)│
     │                     │ ───────────────────►│ No UID stored
     │                     │                     │
     │                     │ ③ {status:          │
     │                     │    uninitialized,   │
     │                     │    protocol_version:2}
     │                     │ ◄───────────────────│ Shows "AWAITING
     │                     │                     │  SETUP"
     │                     │                     │
     │                     │ ④ Show setup wizard │
     │                     │                     │
     │                     │ ⑤ override_start    │
     │                     │ ───────────────────►│
     │                     │ (uid, seq, N)       │ Stores UID!
     │                     │                     │ (Pairing complete)
     │                     │                     │
     │                     │ ⑥ override_chunks   │
     │                     │ ───────────────────►│
     │                     │                     │
     │                     │ ⑦ override_end      │
     │                     │ ───────────────────►│
     │                     │                     │
     │                     │ ⑧ {override_complete}
     │                     │ ◄───────────────────│
     │                     │                     │

Data Flow:
  Firestore items → App → Device NVS
  Also: UID stored on device (pairing)
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
     │                     │ ② handshake(seq=42)│
     │                     │ ───────────────────►│ (Device has seq=42)
     │                     │                     │
     │                     │ ③ {status:in_sync, │
     │                     │    protocol_version:2}
     │                     │ ◄───────────────────│
     │                     │                     │
     │                     │ ④ prefs             │ Includes offline
     │                     │ ◄───────────────────│ increments!
     │                     │ [count: 1598]       │
     │                     │                     │
     │                     │ ⑤ logs              │ Includes offline
     │                     │ ◄───────────────────│ events!
     │                     │ [15 events...]      │
     │                     │                     │
     │ ⑥ Write new counts  │                     │
     │ ◄───────────────────│                     │
     │   1523 → 1598       │                     │
     │                     │                     │
     │ ⑦ Write events      │                     │
     │ ◄───────────────────│                     │
     │   (to activity log) │                     │
     │                     │                     │
     │ ⑧ Increment seq     │                     │
     │ ◄───────────────────│                     │
     │                     │                     │
     │                     │ ⑨ sync_complete     │
     │                     │ ───────────────────►│
     │                     │                     │
     │                     │ ⑩ clear_logs        │
     │                     │ ───────────────────►│ Prevent duplicates
     │                     │                     │

Key insight: Device accumulated counts while offline
             → App uses device counts (source of truth)
             → Firestore gets updated with new counts
```

---

## 7. Multi-Device Sync

### 7.1 Two Devices, Same Account

```
Timeline showing Phone A and Phone B syncing with Device:

Time    Phone A              Device               Phone B
────    ───────              ──────               ───────
T0      [Firestore: seq=40]
        [count=100]

T1      Connect ─────────────►
        handshake(seq=40) ───►
                              {in_sync}
                              prefs: count=105 ───►

T2      Update Firestore ◄───
        [count=105, seq=41]
        sync_complete(41) ───►

T3      Disconnect ◄──────────

T4                            User increments
                              count → 106
                              count → 107
                              count → 108
                              (offline)

T5                                                Connect ────────────►
                                                  handshake(seq=41) ──►

                              🔴 Device seq=41
                                 Phone seq=41
                                 MATCH!           {in_sync} ──────────►
                                                  prefs: count=108 ───►

T6                                                Update Firestore ◄──
                                                  [count=108, seq=42]
                                                  sync_complete(42) ──►

T7      (offline)             [seq now 42]        Disconnect ◄─────────

T8      Connect ─────────────►
        handshake(seq=41) ───►

                              🔴 Device seq=42
                                 Phone seq=41
                                 MISMATCH!
                              {conflict,
                               device_seq=42} ───►

T9      Fetch Firestore ◄─────
        [count=108, seq=42]

        Show conflict dialog
        User confirms "Use
        cloud data"

        override_start ──────►
        override_chunks ─────►  (count=108)
        override_end ────────►
                              {override_complete}

T10     [Both in sync at seq=43]
```

### 7.2 Conflict Decision Logic

```
                ┌─────────────────────────────┐
                │   App connects to device     │
                │   App has sync_seq = A       │
                │   Device has sync_seq = D    │
                └──────────────┬──────────────┘
                               │
                               ▼
                        ┌──────────────┐
                        │    A == D?   │
                        └──────┬───────┘
                               │
              ┌────────────────┼────────────────┐
              │ YES            │                │ NO
              ▼                │                ▼
    ┌─────────────────┐        │      ┌─────────────────┐
    │    in_sync      │        │      │    conflict     │
    │                 │        │      │                 │
    │ Device is       │        │      │ Firestore is    │
    │ source of truth │        │      │ source of truth │
    └─────────────────┘        │      └─────────────────┘
                               │
                               │ (D == 0)
                               ▼
                     ┌─────────────────┐
                     │  uninitialized  │
                     │                 │
                     │ Firestore is    │
                     │ source of truth │
                     │ (new device)    │
                     └─────────────────┘
```

---

## 8. Data Consistency Rules

### 8.1 Golden Rules

| Rule | Description |
|------|-------------|
| **Handshake First** | Always send handshake as the first command after connecting |
| **Device Wins (in_sync)** | When sequences match, trust device counts |
| **Cloud Wins (conflict)** | When sequences differ, trust Firestore |
| **Increment sync_seq** | Always increment after every successful sync |
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
│    • in_sync    → Device (user may have incremented offline)        │
│    • conflict   → Firestore (another device synced recently)        │
│    • new device → Firestore (device has no data)                    │
│                                                                      │
│  SYNC FLOW:                                                          │
│    1. Connect                                                        │
│    2. handshake(uid, sync_seq)                                      │
│    3a. in_sync → receive prefs/logs → sync_complete                 │
│    3b. conflict → override_start → chunks → override_end            │
│                                                                      │
│  NOTIFICATIONS:                                                      │
│    • event      = what happened (history)                           │
│    • item_delta = current state (UI)                                │
│    • Both sent on button press; serve different purposes            │
│                                                                      │
│  CRITICAL:                                                           │
│    • ALWAYS handshake first after connect                           │
│    • ALWAYS use device counts when in_sync                          │
│    • ALWAYS increment sync_seq after sync                           │
│    • NEVER assume app state is current - verify with handshake      │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```
