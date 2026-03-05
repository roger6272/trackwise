# Traxelos One BLE Protocol Specification

> **Protocol Version:** 3
> **Last Updated:** 2026-03-01
> **Device:** ESP32 (Traxelos One)
> **App:** Flutter (Traxelos One)

This document defines the Bluetooth Low Energy communication protocol between the Traxelos One mobile app and ESP32 firmware. It serves as the **source of truth** for app-device communication.

**Related docs:** [Device Display](DEVICE_DISPLAY.md) · [Data Flow](DATA_FLOW.md) · [User Guide](USER_GUIDE.md) · [Troubleshooting](TROUBLESHOOTING.md)

### Version History

| Protocol | Firmware | Changes |
|----------|----------|---------|
| v3 | 2.0.0+ | Removed `sync_seq` from handshake/override, removed `sync_complete` command, removed conflict state |
| v2 | 1.5.0+ | Added `unpair` command for account deletion flow |
| v2 | 1.4.0+ | Added `delete_item` command for single-item deletion |
| v2 | 1.3.0+ | Added numeric `error_code` to all error notifications |
| v2 | 1.2.0+ | Added optional `ack` parameter to `set_time` and `clear_logs` commands |
| v2 | 1.1.0+ | Added `protocol_version` and `firmware_version` to handshake responses |
| v2 | 1.0.x | Multi-device sync with handshake-first approach |
| v1 | 0.x | Initial protocol (single device) |

---

## Table of Contents

1. [Overview](#1-overview)
2. [Service & Characteristics](#2-service--characteristics)
3. [Commands (App → Device)](#3-commands-app--device)
4. [Multi-Device Sync Protocol](#4-multi-device-sync-protocol)
5. [Notifications (Device → App)](#5-notifications-device--app)
6. [Data Structures](#6-data-structures)
7. [Timing & Constants](#7-timing--constants)
8. [Connection Flow](#8-connection-flow)
9. [Sync Sequences](#9-sync-sequences)
10. [Chunked Transfer Protocol](#10-chunked-transfer-protocol)
11. [Device Storage (NVS)](#11-device-storage-nvs)
12. [Device States](#12-device-states)
13. [Power Management](#13-power-management)
14. [Error Handling](#14-error-handling)
15. [Edge Cases & Gotchas](#15-edge-cases--gotchas)
16. [Troubleshooting](#16-troubleshooting)
17. [Appendices](#appendices)

---

## 1. Overview

### 1.1 Architecture

```
┌─────────────────┐              BLE               ┌─────────────────┐
│                 │                                │                 │
│  Flutter App    │ ◄────────────────────────────► │  ESP32 Device   │
│                 │        JSON over GATT          │                 │
│  - UI/UX        │                                │  - Button input │
│  - Firestore    │                                │  - NVS storage  │
│  - BLoC state   │                                │  - Vibration    │
│                 │                                │                 │
└─────────────────┘                                └─────────────────┘
        │                                                  │
        │                                                  │
        ▼                                                  ▼
   Cloud Sync                                      Physical Counter
   (Firestore)                                     (Standalone use)
```

### 1.2 Key Design Principles

| Principle | Description | Rationale |
|-----------|-------------|-----------|
| **Device is source of truth for counts** | During normal sync, device preserves its counts | Prevents losing increments made while disconnected |
| **App is source of truth on override** | App pushes Firestore data to device | Ensures multi-device consistency via Firestore |
| **Handshake-first protocol** | All connections start with handshake | Enables account verification and sync routing |
| **JSON protocol** | All messages are JSON strings | Human-readable, easy debugging |
| **Newline delimiter** | Messages terminate with `\n` | Enables reliable chunk reassembly |
| **Chunked transfer** | Large payloads split into ~180 byte chunks | Works within BLE MTU limits |
| **Numeric IDs** | Items use `deviceItemId` (0-99) | Memory efficient on ESP32 |
| **Non-blocking I/O** | Device uses async transmission | Prevents BLE stack blocking |
| **Batch writes** | NVS writes batched per 10 increments | Reduces flash wear |

### 1.3 Communication Patterns

| Pattern | Direction | Use Case |
|---------|-----------|----------|
| **Command/Response** | App → Device → App | Request data (prepare_read → notification) |
| **Fire-and-forget** | App → Device | set_time, clear_logs |
| **Push notification** | Device → App | Real-time events from button presses |
| **Bulk transfer** | App → Device | set_items (chunked JSON array) |

---

## 2. Service & Characteristics

### 2.1 BLE Service

| Property | Value |
|----------|-------|
| **Device Name** | `Traxelos_One` |
| **Service UUID** | `12345678-1234-1234-1234-123456789000` |
| **Max MTU** | 517 bytes (negotiated, fallback 180) |

### 2.2 Characteristics

| Name | Full UUID | Properties | Direction | Purpose |
|------|-----------|------------|-----------|---------|
| **CHAR_READ** | `12345678-1234-1234-1234-123456789001` | READ | Device → App | One-shot data reads |
| **CHAR_NOTIFY** | `12345678-1234-1234-1234-123456789002` | NOTIFY | Device → App | Streaming notifications |
| **CHAR_SET_ITEMS** | `12345678-1234-1234-1234-123456789008` | WRITE | App → Device | Send item list |
| **CHAR_WRITE** | `12345678-1234-1234-1234-123456789010` | WRITE | App → Device | Send commands |

### 2.3 Characteristic Usage Matrix

| Operation | Characteristic | Notes |
|-----------|---------------|-------|
| Send command | CHAR_WRITE | JSON command object |
| Send item list | CHAR_SET_ITEMS | JSON array, chunked |
| Receive notifications | CHAR_NOTIFY | Subscribe on connect |
| Read data (legacy) | CHAR_READ | Prefer NOTIFY pattern |

---

## 3. Commands (App → Device)

All commands are JSON strings sent to **CHAR_WRITE** unless otherwise noted.

### 3.1 set_selected

Select which item is currently active on the device.

**Request:**
```json
{
  "cmd": "set_selected",
  "id": 5
}
```

**Fields:**

| Field | Type | Required | Range | Description |
|-------|------|----------|-------|-------------|
| `cmd` | string | Yes | - | Always `"set_selected"` |
| `id` | int | Yes | -1 to 99 | `deviceItemId`, or -1 for no selection |

**Device Behavior:**
1. Flushes pending NVS writes for previous item
2. Loads new item data from NVS into runtime variables
3. Updates `selected_did` and `selected_index` in NVS
4. Sends `item_delta` notification with current counts

**Response:** `item_delta` notification

**Example Flow:**
```
App: {"cmd": "set_selected", "id": 3}
Device: Loads item 3 from NVS
Device: {"type": "item_delta", "id": 3, "count": 42, ...}
```

---

### 3.2 set_time

Synchronize device RTC clock with phone time.

**Request:**
```json
{
  "cmd": "set_time",
  "utc_time": "2025-01-24 14:30:45",
  "offset": -300,
  "ack": true
}
```

**Fields:**

| Field | Type | Required | Format | Description |
|-------|------|----------|--------|-------------|
| `cmd` | string | Yes | - | Always `"set_time"` |
| `utc_time` | string | Yes | `yyyy-MM-dd HH:mm:ss` | Current UTC time |
| `offset` | int | Yes | Minutes | Timezone offset from UTC |
| `ack` | bool | No | - | If `true`, device sends acknowledgment response |

**Timezone Offset Examples:**

| Timezone | Offset (minutes) |
|----------|------------------|
| UTC | 0 |
| EST (UTC-5) | -300 |
| PST (UTC-8) | -480 |
| IST (UTC+5:30) | 330 |
| JST (UTC+9) | 540 |

**Device Behavior:**
1. Parses UTC time string using `sscanf`
2. Sets internal RTC clock
3. Stores timezone offset in NVS (`tz_offset`)
4. Triggers daily reset check via `resetTodayCountsIfNeeded()` (in case date changed)
5. If `ack: true`, sends acknowledgment response

**Response:** None by default. If `ack: true`:
```json
{"status": "ok", "cmd": "set_time"}
```
Or on error:
```json
{"status": "error", "cmd": "set_time", "reason": "Missing utc_time parameter"}
```

**App-side Formatting:**
```dart
final now = DateTime.now();
final utcTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(now.toUtc());
final offset = now.timeZoneOffset.inMinutes;
```

---

### 3.3 prepare_read

Request device to prepare data for reading.

**Request:**
```json
{
  "cmd": "prepare_read",
  "type": "prefs",
  "page": 0
}
```

**Fields:**

| Field | Type | Required | Values | Description |
|-------|------|----------|--------|-------------|
| `cmd` | string | Yes | - | Always `"prepare_read"` |
| `type` | string | Yes | `"prefs"`, `"logs"` | Data type to retrieve |
| `page` | int | No | 0+ | Page number (for logs only) |

**Type: "prefs"**
- Returns full item list with current counts
- `page` parameter ignored
- Response: `prefs` notification

**Type: "logs"**
- Returns paginated event history
- 15 entries per page
- `page` 0 = most recent entries
- Response: `logs` notification with `hasMore` flag

**Device Behavior:**
1. Assembles requested data into JSON
2. Sends via non-blocking chunked transmission on NOTIFY
3. Each chunk delayed 20ms to prevent BLE congestion

**Response:** `prefs` or `logs` notification

---

### 3.4 clear_logs

Clear event log buffer on device.

**Request:**
```json
{
  "cmd": "clear_logs",
  "ack": true
}
```

**Fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `cmd` | string | Yes | Always `"clear_logs"` |
| `ack` | bool | No | If `true`, device sends acknowledgment response |

**Device Behavior:**
1. Resets `logCount` to 0
2. Resets `logWriteIndex` to 0
3. Does NOT clear NVS (logs are RAM-only)
4. If `ack: true`, sends acknowledgment response

**Response:** None by default. If `ack: true`:
```json
{"status": "ok", "cmd": "clear_logs"}
```

**When to Use:**
- After successfully retrieving all log pages
- Prevents duplicate sync on next connection

---

### 3.5 force_reset_today (Debug)

Manually trigger daily reset for all items.

**Request:**
```json
{
  "cmd": "force_reset_today"
}
```

**Device Behavior:**
1. Sets `todaycount` to 0 for all items
2. Updates `lastResetTime` to current UTC timestamp
3. Updates `last_reset_date` in NVS

**Response:** None (silent success)

**Warning:** Debug command only. Use for testing daily reset behavior.

---

### 3.6 Set Items (Bulk Sync)

Send full item list to device. Uses **CHAR_SET_ITEMS** characteristic (not CHAR_WRITE).

**Request:**
```json
[
  {
    "id": 0,
    "name": "Push-ups",
    "category": "Exercise",
    "count": 150,
    "todaycount": 25,
    "increment": 1,
    "reminder": 1,
    "reminder_value": 100,
    "lastResetTime": 1706097600,
    "reset_number": 5
  },
  {
    "id": 1,
    "name": "Water glasses",
    "category": "Health",
    "count": 2847,
    "todaycount": 6,
    "increment": 1,
    "reminder": 2,
    "reminder_value": 8,
    "lastResetTime": 1706097600,
    "reset_number": 42
  }
]
```

**Fields per Item:**

| Field | Type | Required | Range | Description |
|-------|------|----------|-------|-------------|
| `id` | int | Yes | 0-99 | `deviceItemId` |
| `name` | string | Yes | max 30 chars | Item display name |
| `category` | string | Yes | max 30 chars | Category name |
| `count` | int | Yes | 0-9999 | Total count |
| `todaycount` | int | Yes | 0-9999 | Count since daily reset |
| `increment` | int | Yes | 1-1000 | Increment per button press |
| `reminder` | int | Yes | 0-2 | Reminder type |
| `reminder_value` | int | Yes | 0-9999 | Target/interval value |
| `goal` | int | Yes | 0-9999 | Target goal count (0 = no goal) |
| `lastResetTime` | int | Yes | Unix timestamp | Last reset time (UTC) |
| `reset_number` | int | Yes | 0+ | Reset counter |

**Field Validation (Device-side):**

| Field | Validation | Default |
|-------|------------|---------|
| `id` | Clamped to 0-99 | Array index |
| `name` | Truncated to 30 chars | Empty string |
| `category` | Truncated to 30 chars | Empty string |
| `count` | Clamped to 0-9999 | 0 |
| `todaycount` | Clamped to 0-9999 | 0 |
| `increment` | Clamped to 1-1000 | 1 |
| `reminder` | Clamped to 0-2 | 0 |
| `reminder_value` | Clamped to 0-9999 | 0 |
| `goal` | Clamped to 0-9999 | 0 |

**Critical Behavior - Count Preservation:**

```
For each item in received JSON:
  1. Check if deviceItemId exists in current NVS
  2. If EXISTS:
     - PRESERVE count, todaycount, lastResetTime, resetNumber from NVS
     - UPDATE name, category, increment, reminder, reminder_value from JSON
  3. If NEW:
     - USE count, todaycount, lastResetTime, resetNumber from JSON
     - SAVE all fields to NVS
```

**This ensures device counts are never overwritten by potentially stale app data.**

**Post-Sync Behavior:**
1. Items re-indexed (0 to N-1)
2. Current selection re-validated
3. Runtime variables refreshed for selected item
4. Event log buffer CLEARED (prevents duplicate events)

**Response:** `error` notification on failure, silent on success

**Chunking:** Required for payloads > MTU. See [Section 10](#10-chunked-transfer-protocol).

---

### 3.7 delete_item

Delete a single item from the device. More efficient than `set_items` when removing just one item.

**Request:**
```json
{
  "cmd": "delete_item",
  "deviceItemId": 5
}
```

**Fields:**

| Field | Type | Required | Range | Description |
|-------|------|----------|-------|-------------|
| `cmd` | string | Yes | - | Always `"delete_item"` |
| `deviceItemId` | int | Yes | 0-99 | ID of item to delete |

**Success Response:**
```json
{
  "status": "deleted",
  "deviceItemId": 5,
  "item_total": 4
}
```

**Error Responses:**

| Error | error_code | Reason |
|-------|------------|--------|
| Missing field | 301 | `deviceItemId` not provided |
| Not found | 403 | No item with that `deviceItemId` exists |
| NVS timeout | 201 | Failed to acquire NVS mutex |

**Device Behavior:**
1. Finds the slot index where `deviceItemId` matches
2. Shifts all subsequent items down by one (maintains sequential storage)
3. Clears the now-empty last slot
4. Updates `item_total`
5. If deleted item was selected, selects first item (or none if empty)
6. Sends success response with updated `item_total`

**When to Use:**

| Scenario | Use |
|----------|-----|
| Delete 1 item | `delete_item` (~40 bytes) |
| Delete multiple items | `set_items` (send remaining items) |
| Delete all items | `set_items` with empty array |

**Example Flow:**
```
App: {"cmd": "delete_item", "deviceItemId": 5}
Device: Removes item, shifts indices, updates total
Device: {"status": "deleted", "deviceItemId": 5, "item_total": 4}
```

---

### 3.8 unpair

Unpair the device from the current account. Used when user deletes their account while connected.

**Request:**
```json
{
  "cmd": "unpair"
}
```

**Success Response:**
```json
{
  "status": "unpaired"
}
```

**Error Responses:**

| Error | error_code | Reason |
|-------|------------|--------|
| NVS timeout | 201 | Failed to acquire NVS mutex |

**Device Behavior:**
1. Clears `paired_uid` from NVS
2. Resets selection state
4. Sets device to pairing mode (`isPairingMode = true`)
5. Sends success response
6. Display shows "AWAITING SETUP"

**When to Use:**

| Scenario | Action |
|----------|--------|
| User deletes account (connected) | Send `[]` → `set_selected -1` → `clear_logs` → `unpair` |
| User deletes account (disconnected) | Show "factory reset required" message |

**Important:** The app should clear items (`set_items` with `[]`) and logs (`clear_logs`) BEFORE sending `unpair`. The unpair command only clears pairing data, not item data.

**Example Flow:**
```
App: {"cmd": "unpair"}
Device: Clears paired_uid, enters pairing mode
Device: {"status": "unpaired"}
Device: Shows "AWAITING SETUP"
App: Disconnects
```

---

## 4. Multi-Device Sync Protocol

The multi-device sync protocol enables a single user account to sync with multiple physical devices while maintaining data consistency via Firestore. This protocol uses a handshake-first approach with exclusive device leasing (`claimed_by`) to prevent conflicts by design.

> **Implementation note:** All sync protocol commands (`handshake`, `override_start/chunk/end`) are routed to a specific device via `deviceId`, ensuring that concurrent device connections don't interfere with each other. The BLoC passes `deviceId` through the use case and repository layers down to the datasource, which looks up the correct `DeviceConnection` for BLE writes.

### 4.1 Protocol Overview

| Scenario | Source of Truth | Protocol Flow |
|----------|-----------------|---------------|
| Normal sync (in_sync) | Device | handshake → device sends prefs/logs → app syncs to Firestore |
| New device setup | App (empty list) | handshake → override_start (0 items) → override_end (selected_id: -1) |
| Stale claim override | App (Firestore) | handshake → override_start → override_chunk(s) → override_end |
| Wrong account | N/A | handshake → disconnect |

### 4.2 handshake

**Purpose:** Account verification and sync routing. **Must be the first command sent after connection.**

**Request:**
```json
{
  "cmd": "handshake",
  "uid": "firebase_user_id"
}
```

**Fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `cmd` | string | Yes | Always `"handshake"` |
| `uid` | string | Yes | Firebase user ID |

**Response Variants:**

All responses include `protocol_version` (int) and `firmware_version` (string) for version compatibility checking.

| Status | Condition | Response Format |
|--------|-----------|-----------------|
| `in_sync` | Device paired to this UID | `{"status":"in_sync","device_instance_id":"MAC","protocol_version":3,"firmware_version":"2.0.0"}` |
| `wrong_account` | Device paired to different UID | `{"status":"wrong_account","device_instance_id":"MAC","protocol_version":3,"firmware_version":"2.0.0"}` |
| `uninitialized` | Device has no UID (new/reset) | `{"status":"uninitialized","device_instance_id":"MAC","protocol_version":3,"firmware_version":"2.0.0"}` |

**Response Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `status` | string | Handshake result (see table above) |
| `device_instance_id` | string | Device BLE MAC address |
| `protocol_version` | int | BLE protocol version (for compatibility checking) |
| `firmware_version` | string | Device firmware version (semantic versioning) |

**Device Behavior by Status:**

| Status | Device Action | App Action |
|--------|---------------|------------|
| `in_sync` | Automatically sends prefs + logs via NOTIFY | Process prefs, sync to Firestore |
| `wrong_account` | Shows "PAIRED TO OTHER ACCOUNT" | Show error dialog, disconnect |
| `uninitialized` | Shows "AWAITING SETUP" | Show setup dialog, send override on user confirm |

**Example Flow (in_sync):**
```
App: {"cmd": "handshake", "uid": "abc123"}
Device: {"status": "in_sync", "device_instance_id": "AA:BB:CC:DD:EE:FF", "protocol_version": 3, "firmware_version": "2.0.0"}
Device: {"type": "prefs", "data": [...], "selected_id": 0}  (automatic)
Device: {"type": "logs", "page": 0, "hasMore": false, "data": [...]}  (automatic)
```

---

### 4.3 override_start

**Purpose:** Begin chunked data override from app to device. Used when app is source of truth (new device setup or stale claim override).

**Request:**
```json
{
  "cmd": "override_start",
  "uid": "firebase_user_id",
  "total_chunks": 5
}
```

**Fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `cmd` | string | Yes | Always `"override_start"` |
| `uid` | string | Yes | Firebase user ID (stored if device uninitialized) |
| `total_chunks` | int | Yes | Total number of override_chunk commands to expect |

**Device Behavior:**
1. If device uninitialized, stores UID (completes device pairing)
2. Stores override state variables (total_chunks, counters)
3. **Clears all existing item slots in NVS**
4. Ready to receive chunks

**Response:** None (silent success)

---

### 4.4 override_chunk

**Purpose:** Send a batch of items to device during override.

**Request:**
```json
{
  "cmd": "override_chunk",
  "index": 0,
  "items": [
    {
      "device_item_id": 5,
      "name": "Push-ups",
      "category": "Exercise",
      "count": 150,
      "todaycount": 25,
      "increment": 1,
      "reminder": 1,
      "reminder_value": 100,
      "lastResetTime": 1706097600,
      "reset_number": 5
    }
  ]
}
```

**Fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `cmd` | string | Yes | Always `"override_chunk"` |
| `index` | int | Yes | Chunk index (0-based) |
| `items` | array | Yes | Array of item objects (recommended ~10 per chunk) |

**Item Fields:**

| Field | Type | Required | Range | Description |
|-------|------|----------|-------|-------------|
| `device_item_id` | int | Yes | 0-99 | ID that maps back to Firestore document |
| `name` | string | Yes | max 30 chars | Item display name |
| `category` | string | Yes | max 30 chars | Category name |
| `count` | int | Yes | 0-9999 | Total count |
| `todaycount` | int | Yes | 0-9999 | Count since daily reset |
| `increment` | int | Yes | 1-1000 | Increment per button press |
| `reminder` | int | Yes | 0-2 | Reminder type |
| `reminder_value` | int | Yes | 0-9999 | Target/interval value |
| `goal` | int | Yes | 0-9999 | Target goal count (0 = no goal) |
| `lastResetTime` | int | Yes | Unix timestamp | Last reset time (UTC) |
| `reset_number` | int | Yes | 0+ | Reset counter |

**Device Behavior:**
1. Saves items **sequentially** at slot indices (0, 1, 2...) - NOT at device_item_id
2. The `device_item_id` from JSON is stored in `did_X` NVS key for Firestore mapping
3. Increments received chunk counter
4. Enforces 100 item limit (excess items silently dropped)

**Response:** None (validation occurs at override_end)

**Note:** Unlike `set_items`, override_chunk **does NOT preserve existing device counts** - it overwrites with app data.

---

### 4.5 override_end

**Purpose:** Complete the override and validate all chunks received.

**Request:**
```json
{
  "cmd": "override_end",
  "selected_id": 5
}
```

**Fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `cmd` | string | Yes | Always `"override_end"` |
| `selected_id` | int | Yes | Device item ID to select (-1 for no selection) |

**Device Behavior:**
1. Validates all chunks received (received count == expected count)
2. Sets `item_total` in NVS to number of items saved
3. Sets selected item (with fallback to first item if ID not found)
4. Displays "SYNCED" message

**Response (Success):**
```json
{"status":"override_complete"}
```

**Response (Failure):**
```json
{"status":"error","message":"missing_chunks"}
```

---

### 4.6 Comparison: set_items vs override_chunk

| Aspect | set_items (Legacy) | override_chunk |
|--------|-------------------|----------------|
| Characteristic | CHAR_SET_ITEMS (008) | CHAR_WRITE (010) |
| Count preservation | YES - device keeps its counts | NO - app counts override |
| Event log | Cleared after sync | Cleared at override_start |
| Response | Error notification only | override_end response |
| Field name | `id` | `device_item_id` |
| Selection | No change | Set at override_end |
| Use case | Normal sync | New device setup, stale claim override |

---

## 5. Notifications (Device → App)

All notifications are JSON sent via **CHAR_NOTIFY**, terminated with `\n` (newline).

### 5.1 prefs (Item List)

Full item list with current counts and selection state.

**Format:**
```json
{
  "type": "prefs",
  "data": [
    {
      "id": 0,
      "name": "Push-ups",
      "count": 175,
      "todaycount": 50,
      "lastResetTime": 1706097600,
      "resetNumber": 5
    },
    {
      "id": 1,
      "name": "Water glasses",
      "count": 2853,
      "todaycount": 12,
      "lastResetTime": 1706097600,
      "resetNumber": 42
    }
  ],
  "selected_id": 0
}
```

**Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `type` | string | Always `"prefs"` |
| `data` | array | Array of item objects |
| `selected_id` | int | Currently selected `deviceItemId`, -1 if none |

**Item Object Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `id` | int | `deviceItemId` (0-99) |
| `name` | string | Item name |
| `count` | int | Total count |
| `todaycount` | int | Count since daily reset |
| `lastResetTime` | int | Unix timestamp (UTC) of last reset |
| `resetNumber` | int | Number of times item has been reset |

**Note:** Does not include `category`, `increment`, `reminder`, `reminder_value` - these are metadata sent via set_items only.

---

### 5.2 event (Real-time Event)

**Purpose:** Record **what just happened** for history, logging, and analytics.

Sent immediately when user interacts with physical device buttons. This notification captures the **action** that occurred.

> **Relationship to `item_delta`:** On button press, the device sends BOTH `event` AND `item_delta`:
> - `event` = what happened (action type, timestamp, increment value)
> - `item_delta` = current state (todaycount, lastResetTime)
>
> They are **not redundant** - each contains fields the other lacks. The app needs both to update history AND UI state.

**When Sent:**
- After increment button press (paired with `item_delta`)
- After reset button press (paired with `item_delta`)
- After switch button press (**without** `item_delta` - only the action matters)

**Format:**
```json
{
  "type": "event",
  "data": {
    "event": "increment",
    "timestamp": 1706140800,
    "itemId": 0,
    "count": 176,
    "increment": 1,
    "resetNumber": 5
  }
}
```

**Fields:**

| Field | Type | Values/Description |
|-------|------|-------------------|
| `type` | string | Always `"event"` |
| `data.event` | string | `"increment"`, `"reset"`, `"switch"` |
| `data.timestamp` | int | Unix timestamp (UTC) |
| `data.itemId` | int | `deviceItemId` (0-99) - app looks up name |
| `data.count` | int | Count **after** event |
| `data.increment` | int | Amount incremented (for increment events) |
| `data.resetNumber` | int | Reset counter after event |

**Event Types:**

| Event | Trigger | Count Change |
|-------|---------|--------------|
| `increment` | Button press | count += increment |
| `reset` | Reset button | count = 0, resetNumber++ |
| `switch` | Switch button | No count change, selection changes |

---

### 5.3 item_delta (Efficient Count Update)

**Purpose:** Sync the **current state** of an item for UI display.

Smaller payload for single-item updates. This notification captures the **state** of the item.

> **Relationship to `event`:** On button press, the device sends BOTH `item_delta` AND `event`:
> - `item_delta` = current state (todaycount, lastResetTime for UI)
> - `event` = what happened (action type, timestamp for history)
>
> **Key difference:** `item_delta` contains `todaycount` and `lastResetTime` which `event` does not have.

**When Sent:**
- After increment/reset button press (paired with `event`)
- After `set_selected` command (**without** `event` - no action occurred, just state query)

**Format:**
```json
{
  "type": "item_delta",
  "id": 0,
  "count": 176,
  "todaycount": 51,
  "lastResetTime": 1706097600,
  "resetNumber": 5
}
```

**Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `type` | string | Always `"item_delta"` |
| `id` | int | `deviceItemId` (0-99) |
| `count` | int | Current total count |
| `todaycount` | int | Count since daily reset |
| `lastResetTime` | int | Unix timestamp (UTC) |
| `resetNumber` | int | Reset counter |

**Use Cases:**
- More efficient than `prefs` when only one item changed
- Provides `todaycount` and `lastResetTime` that `event` notification lacks
- Enables UI to show daily progress without computing it locally

**Field Comparison: `event` vs `item_delta`**

| Field | `event` | `item_delta` | Purpose |
|-------|:-------:|:------------:|---------|
| count | ✓ | ✓ | Current total |
| resetNumber | ✓ | ✓ | Reset counter |
| itemId/id | ✓ | ✓ | Item identifier |
| **todaycount** | ✗ | ✓ | Daily progress (UI) |
| **lastResetTime** | ✗ | ✓ | When daily reset occurred |
| **timestamp** | ✓ | ✗ | When action happened (history) |
| **event type** | ✓ | ✗ | What action occurred |
| **increment** | ✓ | ✗ | Amount incremented |

---

### 5.4 logs (Event History)

Paginated historical events from RAM buffer.

**Format:**
```json
{
  "type": "logs",
  "page": 0,
  "hasMore": true,
  "data": [
    {
      "timestamp": 1706140800,
      "itemId": 0,
      "event": "increment",
      "increment": 1,
      "count": 176,
      "resetNumber": 5
    },
    {
      "timestamp": 1706140750,
      "itemId": 0,
      "event": "increment",
      "increment": 1,
      "count": 175,
      "resetNumber": 5
    }
  ]
}
```

**Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `type` | string | Always `"logs"` |
| `page` | int | Current page number (0-based) |
| `hasMore` | bool | `true` if more pages available |
| `data` | array | Up to 15 log entries |

**Log Entry Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `timestamp` | int | Unix timestamp (UTC) |
| `itemId` | int | `deviceItemId` - app looks up name |
| `event` | string | `"increment"`, `"reset"`, `"switch"` |
| `increment` | int | Increment value used |
| `count` | int | Count after event |
| `resetNumber` | int | Reset counter after event |

**Pagination:**
- Page size: 15 entries
- Page 0 = most recent
- Continue fetching while `hasMore: true`
- Call `clear_logs` after all pages retrieved

---

### 5.5 sync_response (Sync Protocol Response)

Sent in response to multi-device sync commands (handshake, override_end).

**Format (handshake - in_sync):**
```json
{"status":"in_sync","device_instance_id":"AA:BB:CC:DD:EE:FF"}
```

**Format (handshake - wrong_account):**
```json
{"status":"wrong_account","device_instance_id":"AA:BB:CC:DD:EE:FF"}
```

**Format (handshake - uninitialized):**
```json
{"status":"uninitialized","device_instance_id":"AA:BB:CC:DD:EE:FF"}
```

**Format (override_end - success):**
```json
{"status":"override_complete"}
```

**Format (override_end - failure):**
```json
{"status":"error","message":"missing_chunks"}
```

**Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `status` | string | Response status (varies by command) |
| `device_instance_id` | string | BLE MAC address (handshake responses only) |
| `message` | string | Error details (error status only) |

---

### 5.6 error (Error Notification)

Sent when device encounters an error processing a command.

**Format:**
```json
{
  "type": "error",
  "cmd": "set_items",
  "error_code": 101,
  "reason": "Payload too large"
}
```

**Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `type` | string | Always `"error"` |
| `cmd` | string | Command that failed |
| `error_code` | int | Numeric error code for reliable app-side handling (see table below) |
| `reason` | string | Human-readable error message |

**Error Codes:**

| Code | Constant | Description | Resolution |
|------|----------|-------------|------------|
| **1xx** | **Payload Errors** | | |
| 101 | `ERR_PAYLOAD_TOO_LARGE` | Payload exceeds 32KB limit | Reduce item count |
| 102 | `ERR_INVALID_JSON` | JSON parse error | Validate JSON format |
| 103 | `ERR_BUFFER_OVERFLOW` | Write buffer overflow | Reduce payload size |
| **2xx** | **Storage Errors** | | |
| 201 | `ERR_NVS_MUTEX_TIMEOUT` | NVS mutex acquisition failed | Retry after delay |
| 202 | `ERR_NVS_WRITE_FAILED` | NVS write operation failed | Retry |
| **3xx** | **Protocol Errors** | | |
| 301 | `ERR_MISSING_FIELD` | Required field missing | Check command format |
| 302 | `ERR_UNKNOWN_COMMAND` | Unrecognized command | Check command spelling |
| **4xx** | **State Errors** | | |
| 401 | `ERR_NO_ITEM_SELECTED` | Operation requires selected item | Select an item first |
| 403 | `ERR_ITEM_NOT_FOUND` | Item with deviceItemId not found | Verify item exists |

**App-side Error Handling:**
```dart
void handleError(Map<String, dynamic> error) {
  final code = error['error_code'] as int?;
  final reason = error['reason'] as String;

  // Use code for reliable matching
  switch (code) {
    case 101:
      showDialog("Item list is too large. Remove some items.");
      break;
    case 201:
      // Retry after delay
      Future.delayed(Duration(seconds: 1), () => retryCommand());
      break;
    default:
      // Fallback to reason string
      showDialog(reason);
  }
}
```

---

## 6. Data Structures

### 6.1 Reminder Types

| Value | Constant | Behavior | Example |
|-------|----------|----------|---------|
| 0 | `REMINDER_NONE` (None) | No vibration | - |
| 1 | `REMINDER_TARGET` (At Target Count) | Vibrate when `count == reminder_value` | Vibrate at count 100 |
| 2 | `REMINDER_INTERVAL` (Every X Increments) | Vibrate when `count % reminder_value == 0` | Vibrate every 10 counts |

**Goal Vibration:**

When an item has a goal set (`goal > 0`) and the count crosses the goal, the device plays a **triple vibration** (3× 150ms pulses with 100ms gap). Goal vibration takes priority over reminder vibration — if both trigger on the same press, only the goal pattern plays.

**Vibration Hardware:**
- GPIO Pin: 5
- Single pulse: 300ms (reminders)
- Triple pulse: 3× 150ms with 100ms gap (goal reached)
- Non-blocking (doesn't pause counting)
- Priority: goal > reminder target > reminder interval

### 6.2 Event Types

| Value | Constant | Trigger | Description |
|-------|----------|---------|-------------|
| 0 | `EVENT_INCREMENT` | Button press | Count increased |
| 1 | `EVENT_RESET` | Reset button | Count reset to 0 |
| 2 | `EVENT_SWITCH` | Switch button | Active item changed |

### 6.3 Device Item ID

**Purpose:** Memory-efficient item identifier on ESP32

| Property | Value |
|----------|-------|
| Type | `uint8_t` |
| Range | 0-99 (or -1 for no selection) |
| Assignment | App assigns, device preserves |
| Mapping | App maps to/from Firestore document IDs |

**Why not UUIDs?**
- ESP32 has limited RAM (~320KB)
- UUID strings (36 chars) vs numeric (1 byte)
- 100 items × 36 bytes = 3.6KB just for IDs
- Numeric IDs also faster to compare

---

## 7. Timing & Constants

### 7.1 App-Side Timeouts

| Constant | Value | Purpose |
|----------|-------|---------|
| `scanTimeoutSeconds` | 15s | Maximum scan duration |
| `connectionTimeoutSeconds` | 5s | Connection attempt timeout |
| `operationTimeoutSeconds` | 3s | Per-command timeout |
| `messageAssemblyTimeout` | 5s | Incomplete chunk timeout |

### 7.2 App-Side Delays

| Constant | Value | Purpose |
|----------|-------|---------|
| `scanStopDelayMs` | 2000ms | Wait after stopping scan before connect |
| `connectionStabilizeDelayMs` | 300ms | After connected, before sending commands |
| `commandIntervalDelayMs` | 100ms | Between sequential commands |
| `prepareReadDelayMs` | 500ms | After prepare_read before expecting data |
| `chunkDelayMs` | 20ms | Between chunks when sending large payloads |

### 7.3 App-Side Retry Strategy

| Attempt | Delay Before Retry |
|---------|-------------------|
| 1 | 500ms |
| 2 | 1000ms |
| 3 | 2000ms |

Formula: `100ms × 2^(attempt+2)` (capped at 3 attempts)

### 7.4 Device-Side Timing

| Constant | Value | Purpose |
|----------|-------|---------|
| `CHUNK_TIMEOUT_MS` | 5000ms | Clear incomplete JSON buffer |
| `IDLE_TIMEOUT_MS` | 300000ms (5 min) | Enter low power mode |
| `WDT_TIMEOUT_SEC` | 30s | Watchdog reboot timeout |
| Chunk transmission delay | 20ms | Between chunks during send |
| Periodic NVS flush | 5 minutes | Ensure dirty data persists |
| Daily reset check | 60 seconds | Check for midnight reset |

### 7.5 Device-Side Batching

| Operation | Batch Size | Purpose |
|-----------|------------|---------|
| NVS count writes | Every 10 increments | Reduce flash wear |
| NVS flush triggers | Disconnect, daily reset, low power | Ensure persistence |

---

## 8. Connection Flow

### 8.1 Discovery

```
┌─────────────────────────────────────────────────────────────┐
│  1. Start BLE scan with service UUID filter                 │
│     (withServices: [serviceUUID])                           │
│  2. OS returns only devices advertising Traxelos service    │
│  3. Collect discovered devices                              │
│  4. Stop scan after 15s or user selection                   │
└─────────────────────────────────────────────────────────────┘
```

> **Note:** The scan filters by service UUID at the OS level, not by device name. This is more reliable and eliminates non-Traxelos devices from results.

### 8.2 Connection Sequence

```
┌─────┐                                              ┌────────┐
│ App │                                              │ Device │
└──┬──┘                                              └───┬────┘
   │                                                     │
   │  1. Stop scan (prevents GATT 133)                   │
   │                                                     │
   │  2. Wait 2 seconds                                  │
   │                                                     │
   │  3. Connect (with retry, up to 3 attempts)          │
   │ ───────────────────────────────────────────────────►│
   │                                                     │
   │  4. Connection established                          │
   │ ◄───────────────────────────────────────────────────│
   │                                                     │
   │  5. Request MTU 512                                 │
   │ ───────────────────────────────────────────────────►│
   │                                                     │
   │  6. MTU negotiated (180-517)                        │
   │ ◄───────────────────────────────────────────────────│
   │                                                     │
   │  7. Set HIGH connection priority                    │
   │                                                     │
   │  8. Discover services                               │
   │ ───────────────────────────────────────────────────►│
   │                                                     │
   │  9. Service discovery complete                      │
   │ ◄───────────────────────────────────────────────────│
   │                                                     │
   │  10. Find all 4 characteristics                     │
   │                                                     │
   │  11. Subscribe to NOTIFY characteristic             │
   │ ───────────────────────────────────────────────────►│
   │                                                     │
   │  12. Wait 300ms for stabilization                   │
   │                                                     │
   │  ✓ Ready for commands                               │
   │                                                     │
```

### 8.3 GATT 133 Error Prevention

**Cause:** Android BLE stack race condition when scan overlaps connect

**Prevention:**
1. Always stop scan before connecting
2. Wait 2 seconds after scan stops
3. Use retry with exponential backoff

### 8.4 MTU Negotiation

| Scenario | MTU Value | Chunk Size |
|----------|-----------|------------|
| Negotiation successful | 512 | 509 bytes |
| Fallback | 180 | 177 bytes |
| Formula | MTU | MTU - 3 (ATT overhead) |

---

## 9. Sync Sequences

### 9.1 Initial Sync (Handshake-Based)

Performed after connection established. The sync flow depends on the handshake result.

#### Normal Sync (in_sync)

When the device is paired to this user, device is source of truth for counts:

```
┌─────┐                                              ┌────────┐
│ App │                                              │ Device │
└──┬──┘                                              └───┬────┘
   │                                                     │
   │  1. Send handshake                                  │
   │ ───────────────────────────────────────────────────►│
   │     {"cmd":"handshake","uid":"xxx"}                 │
   │                                                     │
   │  2. Receive handshake response                      │
   │ ◄───────────────────────────────────────────────────│
   │     {"status":"in_sync","device_instance_id":"MAC"} │
   │                                                     │
   │  3. Device automatically sends prefs                │
   │ ◄───────────────────────────────────────────────────│
   │     {"type":"prefs","data":[...],"selected_id":0}   │
   │                                                     │
   │  4. Device automatically sends logs                 │
   │ ◄───────────────────────────────────────────────────│
   │     {"type":"logs","page":0,"hasMore":false,...}    │
   │                                                     │
   │  5. Update app state with device counts             │
   │     (Device counts are source of truth)             │
   │                                                     │
   │  6. Sync counts to Firestore                        │
   │                                                     │
   │  7. Refresh device items (push claim-filtered       │
   │     items from Firestore via set_items)             │
   │                                                     │
```

#### Override Flow (New Device / Stale Claim)

When app needs to push data to device (new device setup or stale claim override):

```
┌─────┐                                              ┌────────┐
│ App │                                              │ Device │
└──┬──┘                                              └───┬────┘
   │                                                     │
   │  1. Send handshake                                  │
   │ ───────────────────────────────────────────────────►│
   │     {"cmd":"handshake","uid":"xxx"}                 │
   │                                                     │
   │  2. Receive handshake response                      │
   │ ◄───────────────────────────────────────────────────│
   │     {"status":"in_sync"/"uninitialized",...}        │
   │                                                     │
   │  3. App determines override is needed               │
   │     (stale claim or new device setup)               │
   │                                                     │
   │  4. Send override_start                             │
   │ ───────────────────────────────────────────────────►│
   │     {"cmd":"override_start","uid":"xxx",            │
   │      "total_chunks":3}                              │
   │                                                     │
   │  5. Send override_chunk(s)                          │
   │ ───────────────────────────────────────────────────►│
   │     {"cmd":"override_chunk","index":0,"items":[...]}│
   │     {"cmd":"override_chunk","index":1,"items":[...]}│
   │     {"cmd":"override_chunk","index":2,"items":[...]}│
   │                                                     │
   │  6. Send override_end                               │
   │ ───────────────────────────────────────────────────►│
   │     {"cmd":"override_end","selected_id":5}          │
   │                                                     │
   │  7. Receive override result                         │
   │ ◄───────────────────────────────────────────────────│
   │     {"status":"override_complete"}                  │
   │                                                     │
   │                    Device shows "SYNCED"            │
   │                                                     │
```

### 9.2 Log Sync (Event History)

Performed after initial sync to retrieve offline events.

```
┌─────┐                                              ┌────────┐
│ App │                                              │ Device │
└──┬──┘                                              └───┬────┘
   │                                                     │
   │  1. Request logs page 0                             │
   │ ───────────────────────────────────────────────────►│
   │     {"cmd":"prepare_read","type":"logs","page":0}   │
   │                                                     │
   │  2. Receive logs notification                       │
   │ ◄───────────────────────────────────────────────────│
   │     {"type":"logs","page":0,"hasMore":true,...}     │
   │                                                     │
   │  3. Process log entries                             │
   │                                                     │
   │  [If hasMore == true]                               │
   │                                                     │
   │  4. Request logs page 1                             │
   │ ───────────────────────────────────────────────────►│
   │     {"cmd":"prepare_read","type":"logs","page":1}   │
   │                                                     │
   │  5. Receive logs notification                       │
   │ ◄───────────────────────────────────────────────────│
   │     {"type":"logs","page":1,"hasMore":false,...}    │
   │                                                     │
   │  [Repeat until hasMore == false]                    │
   │                                                     │
   │  6. Clear logs on device                            │
   │ ───────────────────────────────────────────────────►│
   │     {"cmd":"clear_logs"}                            │
   │                                                     │
```

### 9.3 Real-time Event Handling

While connected, app receives push notifications for device button presses.

```
┌────────┐                                           ┌─────┐
│ Device │                                           │ App │
└───┬────┘                                           └──┬──┘
    │                                                   │
    │  User presses increment button                    │
    │                                                   │
    │  1. Increment count in RAM                        │
    │  2. Check goal/reminder (vibrate if triggered)    │
    │  3. Batch to NVS if >= 10 increments              │
    │  4. Log event to RAM buffer                       │
    │                                                   │
    │  5. Send event notification                       │
    │ ─────────────────────────────────────────────────►│
    │     {"type":"event","data":{...}}                 │
    │                                                   │
    │  6. Send item_delta notification                  │
    │ ─────────────────────────────────────────────────►│
    │     {"type":"item_delta","id":0,"count":177,...}  │
    │                                                   │
    │                      7. Update app state          │
    │                      8. Update UI                 │
    │                      9. Sync to Firestore         │
    │                                                   │
```

### 9.4 Selection Change

When app changes selected item.

```
┌─────┐                                              ┌────────┐
│ App │                                              │ Device │
└──┬──┘                                              └───┬────┘
   │                                                     │
   │  1. User selects different item in app              │
   │                                                     │
   │  2. Send set_selected                               │
   │ ───────────────────────────────────────────────────►│
   │     {"cmd":"set_selected","id":3}                   │
   │                                                     │
   │                    Device flushes previous item     │
   │                    Device loads new item from NVS   │
   │                                                     │
   │  3. Receive item_delta                              │
   │ ◄───────────────────────────────────────────────────│
   │     {"type":"item_delta","id":3,"count":42,...}     │
   │                                                     │
   │  4. Update app state with device values             │
   │                                                     │
```

---

## 10. Chunked Transfer Protocol

### 10.1 Why Chunking?

| Constraint | Value |
|------------|-------|
| BLE MTU | 180-517 bytes |
| ATT overhead | 3 bytes |
| Max payload | MTU - 3 bytes |
| Typical item JSON | ~150 bytes |
| 100 items | ~15KB |

Large payloads must be split into chunks.

### 10.2 App → Device (set_items)

**Sending:**
```
1. Serialize JSON array to string
2. Split into chunks of (MTU - 3) bytes
3. Send each chunk with 20ms delay
4. Device assembles in buffer
5. Device parses when closing ']' received
```

**Chunk Delay:** 20ms between chunks prevents BLE congestion

**Timeout:** Device clears buffer after 5 seconds of inactivity

### 10.3 Device → App (notifications)

**Sending:**
```
1. Device serializes JSON to string
2. Appends '\n' (newline) delimiter
3. Splits into ~180 byte chunks
4. Sends via non-blocking state machine
5. 20ms delay between chunks
```

**Reassembly (App-side):**
```
1. Accumulate received bytes in buffer
2. Check for '\n' delimiter
3. When found, extract complete message
4. Parse JSON
5. Clear buffer for next message
```

### 10.4 Non-blocking Transmission (Device)

Device uses a state machine to prevent blocking the BLE stack:

```cpp
// processBleTransmit() called in main loop
if (bleTransmitActive && millis() >= nextChunkTime) {
    size_t chunkLen = min(180, bleTransmitRemaining);
    pNotifyChar->setValue(currentChunk, chunkLen);
    pNotifyChar->notify();
    bleTransmitIndex += chunkLen;
    bleTransmitRemaining -= chunkLen;
    nextChunkTime = millis() + 20;  // 20ms until next chunk
}
```

---

## 11. Device Storage (NVS)

### 11.1 NVS Namespace

**Namespace:** `"counter"`

### 11.2 Per-Item Keys

Index-based storage where `<i>` = 0 to 99:

| Key | Type | Description |
|-----|------|-------------|
| `did_<i>` | uint8_t | `deviceItemId` (0-99) |
| `n_<i>` | string | Item name (max 30 chars) |
| `cat_<i>` | string | Category (max 30 chars) |
| `c_<i>` | int | Total count |
| `tc_<i>` | int | Today's count |
| `i_<i>` | int | Increment value (1-1000) |
| `r_<i>` | int | Reminder type (0-2) |
| `rv_<i>` | int | Reminder value (0-9999) |
| `g_<i>` | int | Goal count (0 = no goal) |
| `lr_<i>` | ulong | Last reset time (UTC timestamp) |
| `rn_<i>` | int | Reset number |

### 11.3 Global Keys

| Key | Type | Description |
|-----|------|-------------|
| `item_total` | int | Number of items (0-100) |
| `selected_did` | int | Currently selected deviceItemId (-1 if none) |
| `selected_index` | int | Index of currently selected item |
| `tz_offset` | int | Minutes offset from UTC |
| `last_reset_date` | string | "YYYY-MM-DD" of last daily reset |
| `paired_uid` | string | Firebase user ID this device is paired to (empty = unpaired) |

### 11.4 Flash Wear Optimization

**Problem:** NVS uses flash memory with limited write cycles (~100,000)

**Solution:** Batch writes

| Trigger | Action |
|---------|--------|
| Every 10 increments | Write count to NVS |
| Disconnect | Flush all dirty data |
| Daily reset | Write all todaycounts |
| Low power entry | Flush all dirty data |
| Every 5 minutes | Periodic flush |

**RAM Tracking:**
```cpp
bool countsDirty = false;     // Counts modified since last NVS write
int incrementsSinceFlush = 0; // Counter for batching
```

---

## 12. Device States

The device operates in one of several states that affect its behavior and user interface.

### 12.1 State Definitions

| State | Description | Button Behavior | Display |
|-------|-------------|-----------------|---------|
| **Normal** | Device paired and operational | Enabled - increment/reset/switch work | Item name and count |
| **Pairing** | Device unpaired (new or factory reset) | Enabled | "WELCOME TO TRAXELOS" |
| **Offline (fixed-task)** | Device disconnected from app | Increment/reset enabled, **switch disabled** | "SWITCH DISABLED / SYNC TO APP" on switch attempt |

### 12.2 State Transitions

```
                    ┌─────────────┐
                    │  UNPAIRED   │
                    │  (Factory)  │
                    └──────┬──────┘
                           │ First boot / Factory reset
                           ▼
                    ┌─────────────┐
                    │   PAIRING   │◄────────────────────┐
                    │    MODE     │                     │
                    └──────┬──────┘                     │
                           │ override_start with UID   │
                           ▼                           │
                    ┌─────────────┐    ┌───────────┐   │
                    │   NORMAL    │◄───│   IDLE    │   │
                    │    MODE     │    │   (BLE    │   │
                    └──────┬──────┘    │  advert)  │   │
                           │           └───────────┘   │
                           │                           │
                           │ Factory reset             │
                           └───────────────────────────┘

Note: When disconnected (offline), the device enters a "fixed-task"
mode where increment/reset still work but item switching is blocked.
This prevents claim conflicts when multiple devices share items.
See EXCLUSIVE_LEASING_SPEC.md §5.2 for details.
```

### 12.3 Disconnect Behavior

On BLE disconnect, the device:
1. Flushes pending NVS writes (prevents count loss)
2. Clears sync state flags
3. Clears BLE transmit queue
4. Restarts BLE advertising

---

## 13. Power Management

### 13.1 Power States

| State | CPU Speed | BLE Advertising | Entry Condition |
|-------|-----------|-----------------|-----------------|
| Active | 240 MHz | 40ms interval | Any activity |
| Low Power | 80 MHz | 500ms interval | 5 min idle + disconnected |

### 13.2 Low Power Entry

```cpp
if (!deviceConnected && (millis() - lastActivityTime > IDLE_TIMEOUT_MS)) {
    if (!lowPowerMode) {
        flushNvsIfDirty();
        setCpuFrequencyMhz(80);
        // Increase advertising interval
        lowPowerMode = true;
    }
}
```

### 13.3 Activity Triggers

Any of these reset the idle timer:
- Button press
- BLE connection
- BLE command received
- Item switch

---

## 14. Error Handling

### 14.1 Connection Errors

| Error | Cause | App Response |
|-------|-------|--------------|
| GATT 133 | Android race condition | Retry with backoff |
| Connection timeout | Device out of range | Show error, allow retry |
| Disconnected | Device powered off | Reconnect on next scan |
| Missing characteristics | Incompatible firmware | Show firmware update prompt |

### 14.2 Message Errors

| Error | Cause | Response |
|-------|-------|----------|
| Incomplete message | Connection lost mid-transfer | 5s timeout clears buffer |
| JSON parse error | Corrupted data | Log error, skip message |
| Buffer overflow | Message > 64KB | Clear buffer, log error |

### 14.3 Command Errors

| Error | Cause | Response |
|-------|-------|----------|
| Payload too large | set_items > 32KB | Reduce item count |
| NVS timeout | Flash busy | Retry after delay |
| Unknown command | Typo in cmd field | Fix command |

### 14.4 Recovery Strategies

**Connection Lost:**
```
1. Clear characteristic cache
2. Clear message buffer
3. Wait 2 seconds
4. Attempt reconnection (up to 3 retries)
5. If success, perform full sync
```

**Sync Failure:**
```
1. Disconnect
2. Wait 5 seconds
3. Reconnect
4. Retry sync sequence
```

**Count Mismatch:**
```
1. Trust device counts (source of truth)
2. Request prefs from device
3. Update app state with device values
4. Sync to Firestore
```

---

## 15. Edge Cases & Gotchas

### 15.1 Count Preservation During Sync

**Scenario:** App sends set_items while device has newer counts

**Behavior:** Device preserves its counts, ignores app-sent counts for existing items

**Why:** User may have incremented on device while app was disconnected

### 15.2 Event Log Cleared After set_items

**Scenario:** App sends set_items, then requests logs

**Behavior:** Logs are empty (cleared by set_items)

**Solution:** Sync logs BEFORE sending set_items if you need historical events

### 15.3 Daily Reset Timing

**Scenario:** User in different timezone than device

**Behavior:** Device uses stored timezone offset for reset timing

**Solution:** Always send set_time after connecting

### 15.4 Selection State

**Scenario:** App shows item A selected, device has item B selected

**Behavior:** They are independent until explicitly synced

**Solution:** After connect, either:
- Send set_selected to sync app → device
- Read prefs to sync device → app

### 15.5 Chunked JSON Reassembly

**Scenario:** Message split across BLE packets

**Behavior:** Device waits for closing `]` (set_items) or app waits for `\n`

**Gotcha:** 5-second timeout clears incomplete buffers

**Solution:** Ensure all chunks sent within timeout window

### 15.6 Maximum Items

**Limit:** 100 items

**Behavior:** Items beyond 100 are silently dropped

**Solution:** Enforce limit in app before sending

### 15.7 Disconnection During NVS Write

**Scenario:** Device disconnects while writing to NVS

**Behavior:** Up to 10 increments may be lost (batching)

**Mitigation:** Device flushes on disconnect event

---

## 16. Troubleshooting

### 16.1 Quick Diagnostics

| Symptom | Check | Likely Cause |
|---------|-------|--------------|
| Can't find device | Device powered on? Advertising? | Power or BLE issue |
| Can't connect | Scan stopped before connect? | GATT 133 race |
| No notifications | NOTIFY subscribed? | Missing subscription |
| Commands ignored | Correct characteristic UUID? | Wrong characteristic |
| Counts wrong | Device is source of truth | Check sync sequence |
| Items missing | set_items included all items? | Partial sync |
| Garbled messages | Chunk reassembly working? | Buffer issues |

### 16.2 Logging Points

**App-side** (use `AppLogger` from `core/utils/logger.dart`):
```dart
// Log raw bytes
notifyStream.listen((data) {
  AppLogger.debug('BLE RX: ${String.fromCharCodes(data)}');
});

// Log parsed messages
final message = BleMessageModel.fromJson(jsonString);
AppLogger.debug('BLE MSG: ${message.type} - ${message.data}');
```

**Device-side** (requires `#define DEBUG` uncommented in `.ino`):
```cpp
// Uncomment "#define DEBUG" at top of Trackwise_ESP32.ino
// Then connect serial monitor at 115200 baud
// All BLE events logged via DEBUG_LOG/DEBUG_PRINTLN macros
```

### 16.3 Common Fixes

**"Can't connect" / GATT 133:**
```dart
await stopScan();
await Future.delayed(Duration(seconds: 2));
await connect(device);
```

**"Missing characteristics":**
```dart
// Ensure all 4 characteristics found
final required = [CHAR_READ, CHAR_NOTIFY, CHAR_SET_ITEMS, CHAR_WRITE];
for (final uuid in required) {
  if (!found.contains(uuid)) throw StateError('Missing: $uuid');
}
```

**"Counts not syncing":**
```
1. Send set_items with current app items
2. Wait for completion
3. Request prefs
4. Use device counts in response (not app counts)
```

**"Events lost during offline":**
```
1. Request logs immediately after connect
2. Process all pages (follow hasMore)
3. Then call clear_logs
4. Then send set_items
```

### 16.4 Debug Commands

**Force daily reset (testing):**
```json
{"cmd": "force_reset_today"}
```

**Check device state:**
```json
{"cmd": "prepare_read", "type": "prefs", "page": 0}
```

---

## Appendices

### Appendix A: File Locations

#### App Code

| Component | Path |
|-----------|------|
| BLE Constants | `lib/core/utils/bluetooth_constants.dart` |
| Datasource Interface | `lib/features/bluetooth/data/datasources/bluetooth_datasource.dart` |
| Datasource Implementation | `lib/features/bluetooth/data/datasources/bluetooth_datasource_impl.dart` |
| Message Model | `lib/features/bluetooth/data/models/ble_message_model.dart` |
| Device Model | `lib/features/bluetooth/data/models/ble_device_model.dart` |
| Repository | `lib/features/bluetooth/data/repositories/bluetooth_repository_impl.dart` |
| Entities | `lib/features/bluetooth/domain/entities/` |
| Use Cases | `lib/features/bluetooth/domain/usecases/` |
| BLoC | `lib/features/bluetooth/presentation/bloc/bluetooth_bloc.dart` |

#### Firmware Code

| Component | Location in `Trackwise_ESP32.ino` |
|-----------|-----------------------------------|
| BLE UUIDs | Lines ~29-35 |
| Multi-device NVS keys | Lines ~47-51 |
| Handshake handler | `handleHandshake()` |
| Override handlers | `handleOverrideStart/Chunk/End()` |
| SetItemsCallback | `class SetItemsCallback` |
| WriteCallback | `class WriteCallback` |
| ServerCallbacks | `class ServerCallbacks` |
| Non-blocking transmit | `processBleTransmit()` |
| Daily reset check | `checkDailyReset()` |
| NVS operations | Various helper functions |

---

### Appendix B: Device Limits

| Limit | Value | Enforced By |
|-------|-------|-------------|
| Max items | 100 | `maxPrefsSlots` constant |
| Max item name | 30 characters | Truncation |
| Max category | 30 characters | Truncation |
| Max increment | 1000 | Clamping |
| Min increment | 1 | Clamping |
| Max reminder value | 9999 | Clamping |
| Max count/todaycount | 9999 | Clamping |
| Max goal | 9999 | Clamping |
| Max log entries | 1000 | Circular buffer |
| Max set_items payload | 32KB | CHAR_SET_ITEMS buffer |
| Max WRITE command payload | 8KB | CHAR_WRITE buffer |
| Max message size | 64KB | App buffer limit |
| Max BLE MTU | 517 bytes | BLE spec |
| Max simultaneous connections | 5 | `BluetoothState.maxConnectedDevices` |

**Important:** Commands sent via CHAR_WRITE **must** end with `\n` (newline). The firmware accumulates chunks and processes complete messages on newline detection.

---

### Appendix C: Complete UUID Reference

```
Service:       12345678-1234-1234-1234-123456789000
CHAR_READ:     12345678-1234-1234-1234-123456789001
CHAR_NOTIFY:   12345678-1234-1234-1234-123456789002
CHAR_SET_ITEMS:12345678-1234-1234-1234-123456789008
CHAR_WRITE:    12345678-1234-1234-1234-123456789010
```

---

### Appendix D: JSON Message Examples

#### Complete set_items Example
```json
[
  {
    "id": 0,
    "name": "Push-ups",
    "category": "Exercise",
    "count": 1523,
    "todaycount": 75,
    "increment": 1,
    "reminder": 1,
    "reminder_value": 100,
    "lastResetTime": 1706097600,
    "reset_number": 15
  },
  {
    "id": 1,
    "name": "Water (glasses)",
    "category": "Health",
    "count": 2847,
    "todaycount": 6,
    "increment": 1,
    "reminder": 2,
    "reminder_value": 8,
    "lastResetTime": 1706097600,
    "reset_number": 42
  },
  {
    "id": 2,
    "name": "Meditation (minutes)",
    "category": "Wellness",
    "count": 3650,
    "todaycount": 20,
    "increment": 5,
    "reminder": 1,
    "reminder_value": 30,
    "lastResetTime": 1706097600,
    "reset_number": 120
  }
]
```

#### Complete prefs Response Example
```json
{
  "type": "prefs",
  "data": [
    {
      "id": 0,
      "name": "Push-ups",
      "count": 1598,
      "todaycount": 150,
      "lastResetTime": 1706140800,
      "resetNumber": 16
    },
    {
      "id": 1,
      "name": "Water (glasses)",
      "count": 2855,
      "todaycount": 14,
      "lastResetTime": 1706140800,
      "resetNumber": 43
    }
  ],
  "selected_id": 0
}
```

#### Complete Event Example
```json
{
  "type": "event",
  "data": {
    "event": "increment",
    "timestamp": 1706184532,
    "itemId": 0,
    "count": 1599,
    "increment": 1,
    "resetNumber": 16
  }
}
```

---

### Appendix E: Device Instance ID

The device instance ID uniquely identifies each physical device. It is returned in handshake responses.

| Property | Value |
|----------|-------|
| **Source** | BLE MAC address |
| **Format** | MAC address string (e.g., "AA:BB:CC:DD:EE:FF") |
| **Persistence** | Hardware-fixed (survives factory reset) |
| **NVS Storage** | None (read directly from BLE stack) |

**Note:** In v1.0, the device instance ID was a generated UUID stored in NVS. In v2.0, it uses the BLE MAC address which is hardware-fixed and does not require NVS storage.

---

### Appendix F: Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-01-24 | Generated from codebase | Initial specification |
| 2.0 | 2026-01-27 | Multi-device update | Added handshake, override, sync_complete commands; device states; updated sync flows |
| 3.0 | 2026-03-01 | sync_seq removal | Removed sync_seq from handshake/override, removed sync_complete command, removed conflict state |

---

## Quick Reference Card

```
┌─────────────────────────────────────────────────────────────┐
│                  TRAXELOS BLE QUICK REFERENCE               │
├─────────────────────────────────────────────────────────────┤
│ Device Name: Traxelos_One                                   │
│ Service: 12345678-1234-1234-1234-123456789000               │
├─────────────────────────────────────────────────────────────┤
│ CHARACTERISTICS:                                            │
│   NOTIFY  ...002  ← Device notifications (subscribe!)      │
│   WRITE   ...010  → Commands (handshake, set_selected...)  │
│   SET_ITEMS ...008 → Legacy item list (JSON array)         │
├─────────────────────────────────────────────────────────────┤
│ MULTI-DEVICE SYNC (v3.0):                                   │
│   {"cmd":"handshake","uid":"..."}                          │
│     → FIRST command after connect!                         │
│   {"cmd":"override_start","uid":"...","total_chunks":M}    │
│   {"cmd":"override_chunk","index":I,"items":[...]}         │
│   {"cmd":"override_end","selected_id":X}                   │
├─────────────────────────────────────────────────────────────┤
│ LEGACY COMMANDS:                                            │
│   {"cmd":"set_selected","id":N}      Select item 0-99      │
│   {"cmd":"set_time","utc_time":"...","offset":N}           │
│   {"cmd":"prepare_read","type":"prefs|logs","page":N}      │
│   {"cmd":"clear_logs"}               After syncing logs    │
├─────────────────────────────────────────────────────────────┤
│ NOTIFICATIONS (Device → App):                               │
│   {"status":"in_sync|wrong_account|uninitialized"}         │
│   {"type":"prefs",...}     Full item list + selected_id    │
│   {"type":"event",...}     Button press (increment/reset)  │
│   {"type":"item_delta",...} Single item count update       │
│   {"type":"logs",...}      Historical events (paginated)   │
│   {"type":"error",...}     Error message                   │
├─────────────────────────────────────────────────────────────┤
│ SYNC FLOW:                                                  │
│   1. Connect → handshake                                   │
│   2a. in_sync → device sends prefs/logs → app syncs        │
│   2b. uninitialized → override (includes UID pairing)      │
├─────────────────────────────────────────────────────────────┤
│ GOLDEN RULES:                                               │
│   - ALWAYS send handshake first after connect              │
│   - in_sync: Device is source of truth for counts          │
│   - Stale claims: App (Firestore) overrides device         │
│   - set_items preserves device counts                      │
│   - override_chunk overwrites with app counts              │
└─────────────────────────────────────────────────────────────┘
```
