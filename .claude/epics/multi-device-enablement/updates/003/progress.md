# Task 003 Progress: Handshake Protocol and Conflict State Handling

## Status: Complete

## Started: 2026-01-25
## Completed: 2026-01-25

## Implementation Summary

### Changes Made to `firmware/Trackwise_ESP32/Trackwise_ESP32.ino`

#### 1. Added Global Conflict State Flag (line 55)
```cpp
bool inConflictState = false;  // True when sync_seq mismatch detected, waiting for app override
```

#### 2. Added Conflict State Functions (lines 316-420)

**`enterConflictState()`**
- Sets `inConflictState = true`
- Displays "SEE APP" message on device
- Logs state change for debugging

**`exitConflictState()`**
- Sets `inConflictState = false`
- Clears the display message
- Only runs if actually in conflict state (guard check)

**`sendJsonResponse(String jsonStr)`**
- Helper function to send JSON responses via BLE notification
- Adds newline for Flutter end-of-message detection
- Uses non-blocking transmission for larger responses

**`handleHandshake(String uid, int appSyncSeq)`**
- Implements the full handshake protocol from the implementation plan
- Step 1: Account lock check
  - If device has `paired_uid` and it doesn't match incoming `uid`: responds `wrong_account`
  - Displays "PAIRED TO" / "OTHER ACCOUNT" messages
- Step 2: First pairing
  - If `paired_uid` is empty, stores the uid and exits pairing mode
- Step 3: Sync sequence comparison
  - If `app_sync_seq == device_sync_seq`: responds `in_sync`
  - Otherwise: responds `conflict` with `device_seq` and enters conflict state

#### 3. Updated `ServerCallbacks::onDisconnect()` (lines 1335-1339)
- Added check for conflict state
- Calls `exitConflictState()` if device was in conflict
- This allows user to reconnect and retry sync

#### 4. Added Handshake Command to `WriteCallback` (lines 1142-1152)
- Parses `handshake` command with `uid` and `sync_seq` parameters
- Validates that `uid` is not empty
- Calls `handleHandshake()` to process

#### 5. Updated `handleCommand()` with Conflict State Check (lines 1499-1505)
- Added guard at the beginning of button handler
- If `inConflictState` is true:
  - Displays "SEE APP" reminder
  - Logs the ignored button press
  - Returns immediately (buttons disabled)

## Protocol Details

### Handshake Request (from app)
```json
{ "cmd": "handshake", "uid": "firebase_uid_here", "sync_seq": 42 }
```

### Handshake Responses (from device)

**In Sync (device is Source of Truth):**
```json
{ "status": "in_sync", "device_instance_id": "uuid-here" }
```

**Conflict (app is Source of Truth):**
```json
{ "status": "conflict", "device_seq": 40, "device_instance_id": "uuid-here" }
```

**Wrong Account (device paired to different account):**
```json
{ "status": "wrong_account", "device_instance_id": "uuid-here" }
```

## Acceptance Criteria Verification

- [x] Handshake command handler implemented
- [x] Account lock check: reject if paired_uid doesn't match
- [x] First pairing: store uid if paired_uid is empty
- [x] Sync sequence comparison: return in_sync or conflict
- [x] Three response types: in_sync, conflict, wrong_account
- [x] Display "PAIRED TO OTHER ACCOUNT" on wrong_account response
- [x] Conflict state: display "SEE APP", disable increment/decrement
- [x] Exit conflict state on BLE disconnect
- [x] Button press in conflict state shows "SEE APP" reminder

## Testing Notes

To test the handshake protocol:
1. Use a BLE terminal app (e.g., nRF Connect)
2. Connect to "Traxogic_device"
3. Write to CHAR_WRITE_UUID: `{"cmd":"handshake","uid":"test_user_123","sync_seq":0}`
4. Read response from notifications

Expected behaviors:
- Fresh device: `in_sync` (both sync_seq = 0)
- After sync: `in_sync` if sync_seq matches
- Different sync_seq: `conflict`, device shows "SEE APP"
- Different uid: `wrong_account`, device shows "PAIRED TO" / "OTHER ACCOUNT"
- Button press in conflict: ignored, shows "SEE APP"
- Disconnect: exits conflict state
