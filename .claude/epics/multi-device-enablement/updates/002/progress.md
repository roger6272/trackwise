# Task 002: Firmware - NVS storage, device instance ID, and pairing mode

## Status: Complete
## Started: 2026-01-25
## Completed: 2026-01-25

## Summary
Implemented core multi-device firmware infrastructure:
- NVS storage schema for pairing data
- Device instance ID generation
- Pairing mode detection
- Updated factory reset functionality

## Implementation Complete

### Changes Made to `firmware/Trackwise_ESP32/Trackwise_ESP32.ino`

#### 1. Added include for BLE bonding
```cpp
#include <esp_bt.h>  // For BLE bonding table access
```

#### 2. Added NVS key definitions
```cpp
#define NVS_KEY_PAIRED_UID "paired_uid"           // String: Firebase uid (empty = unpaired)
#define NVS_KEY_DEVICE_INSTANCE_ID "dev_inst_id"  // String: Unique device identifier (UUID)
#define NVS_KEY_SYNC_SEQ_NO "sync_seq_no"         // int32: Last sync sequence number (default: 0)
```

Note: Used "dev_inst_id" instead of "device_instance_id" to stay within NVS 15-char key limit.

#### 3. Added multi-device state variable
```cpp
bool isPairingMode = false;  // True when device is unpaired and waiting for pairing
```

#### 4. Added multi-device helper functions
- `generateUUID()` - Generates UUID format string using esp_random()
- `generateDeviceInstanceId()` - Generates and stores UUID in NVS
- `getDeviceInstanceId()` - Retrieves device instance ID from NVS
- `getPairedUid()` / `setPairedUid()` - NVS helpers for paired_uid
- `getSyncSeqNo()` / `setSyncSeqNo()` - NVS helpers for sync_seq_no
- `isDevicePaired()` - Checks if paired_uid is set
- `enterPairingMode()` / `enterNormalMode()` - Mode switching
- `displayWelcomeScreen()` - Shows welcome message (Serial output placeholder)
- `displayMessage()` - Display helper (Serial output placeholder)
- `clearItemSlot()` - Clears single item slot from NVS
- `clearAllItemSlots()` - Clears all 100 item slots
- `clearBleBonding()` - Clears BLE bonding table using ESP32 API
- `waitForConfirmation()` - Waits for key confirmation with timeout
- `handleFactoryReset()` - Full factory reset with confirmation

#### 5. Updated setup() function
- Checks/generates device instance ID on first boot
- Logs paired_uid and sync_seq_no on startup
- Enters pairing mode or normal mode based on paired_uid

#### 6. Updated loop() function
- Added 'f'/'F' command to trigger factory reset

## Acceptance Criteria Status

- [x] NVS storage schema implemented (paired_uid, device_instance_id, sync_seq_no)
- [x] Device instance ID generated on first boot (UUID format)
- [x] Pairing mode detection on startup (check if paired_uid is empty)
- [x] Welcome screen displayed when unpaired
- [x] Factory reset clears pairing, regenerates device_instance_id, clears items
- [x] Factory reset clears BLE bonding table

## Testing Notes

To test the implementation:

1. **First boot test**: Flash firmware, device should generate device_instance_id and enter pairing mode
2. **Factory reset test**: Press 'f' then 'F' within 10 seconds to confirm reset
3. **Device instance ID persistence**: Reboot device, ID should persist
4. **Pairing mode**: Serial output shows welcome screen when unpaired

## Dependencies on Future Tasks

This task provides the foundation for:
- Task 003: Handshake protocol (uses getPairedUid, getDeviceInstanceId, getSyncSeqNo)
- Task 004: Override handling (uses clearAllItemSlots, setSyncSeqNo)
- Task 005: App pairing flow (calls setPairedUid)

