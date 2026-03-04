---
name: multi-device-enablement
description: Enable users to pair multiple physical Trackwise devices to a single account with sync and conflict resolution
status: backlog
created: 2026-01-25T22:41:31Z
---

# PRD: Multi-Device Enablement

## Executive Summary

Enable users to pair multiple physical Trackwise devices to a single account, with proper synchronization and conflict resolution when switching between devices. This requires firmware updates, Firestore schema changes, and app implementation.

## Problem Statement

### What Problem Are We Solving?

Currently, users can only use one Trackwise device per account. If they want to use multiple devices (e.g., one at home, one at office), there's no way to keep them synchronized.

### Why Is This Important Now?

- Users have requested multi-device support
- Physical devices may be lost/replaced and users need to pair new ones
- Business opportunity to sell additional devices per user

## User Stories

### Primary User

- As a user, I want to pair multiple devices to my account so I can use Trackwise in different locations
- As a user, I want my items and counts to sync across all my devices so my data is consistent
- As a user, I want to see which devices are paired to my account so I can manage them
- As a user, I want to rename my devices so I can identify them easily

### Edge Cases

- As a user, if I use Device A then switch to Device B, I expect B to be updated with my latest data
- As a user, if I find a device paired to someone else's account, I should not be able to use it
- As a user, I should be able to factory reset a device to unpair it from any account

## Requirements

### Functional Requirements

#### Firmware Changes

1. **Device Instance ID**: Generate and store unique device identifier (UUID)
2. **Account Lock**: Store Firebase UID to lock device to one account
3. **Sync Sequence**: Track sync_seq_no for conflict detection
4. **Handshake Protocol**: New BLE command for account lock + sync check
5. **Conflict State**: Display "SEE APP" and disable buttons when out of sync
6. **Override Protocol**: Receive chunked item data from app
7. **Factory Reset**: Clear pairing, regenerate device ID, clear items

#### App Changes

1. **Firestore Schema**: Add sync_sequence_no, paired_devices array, last_selected_device_item_id
2. **Handshake Flow**: Send handshake before sync, handle in_sync/conflict/wrong_account
3. **Normal Sync**: Device → App data transfer with sync_complete acknowledgment
4. **Override Sync**: App → Device data transfer (chunked) when conflict detected
5. **Conflict Dialog**: UI for user to confirm override
6. **Paired Devices Page**: List/rename/unpair devices
7. **Internet Check**: Require connectivity for Firestore access
8. **Retry Logic**: Retry Firestore updates on failure

### Non-Functional Requirements

- **BLE Reliability**: 10-second timeout on all BLE commands
- **Data Integrity**: Firestore only updated after device acknowledgment
- **Scalability**: Maximum 10 paired devices per account
- **Compatibility**: Maximum 100 items per account (device slot limit)

## Success Criteria

1. User can pair up to 10 devices to one account
2. Switching between devices correctly syncs data
3. Conflict resolution dialog appears when needed
4. Factory reset properly unpairs device
5. All 18 test scenarios pass

## Constraints & Assumptions

### Constraints

| Constraint | Reason |
|------------|--------|
| Item creation requires BLE connection | Items need device_item_id assigned by device |
| Maximum 100 items per account | Device has 100 item slots (0-99) |
| Maximum 10 paired devices | Prevents excessive device registry growth |
| Up to 5 simultaneous BLE connections | BLE reliability degrades beyond 5-6 concurrent connections on most phones |
| Sync requires internet connection | App must fetch fresh sync_seq from Firestore |

### Assumptions

- Users understand they need to confirm override when switching devices
- Factory reset is acceptable way to unpair from device side
- 10-second BLE timeout is sufficient for all operations

## Out of Scope

- Automatic background sync when not connected
- Device-to-device direct sync (without app)
- Cloud-based device management (all via app)

## Dependencies

- ESP32 firmware development environment
- Firestore backend (already in use)
- BLE protocol (existing, to be extended)

## Implementation Reference

Full technical implementation details are in: `docs/MULTI_DEVICE_IMPLEMENTATION_PLAN.md`

### Sprint Overview

| Sprint | Focus | Tasks |
|--------|-------|-------|
| Sprint 1 | Firmware Prep | Rename device_id → device_item_id |
| Sprint 2 | Firmware Core | NVS storage, device ID, pairing mode, factory reset |
| Sprint 3 | Firmware Protocol | Handshake, conflict state, override, sync_complete |
| Sprint 4 | App Core | Firestore schema, BLE commands, sync flows, retry logic |
| Sprint 5 | App UI | Conflict dialog, paired devices page, device management |

### Test Scenarios

18 manual test scenarios defined covering:
- Fresh device pairing
- Same/different device reconnection
- Conflict detection and resolution
- Factory reset
- Device limits
- BLE disconnection recovery
- Internet connectivity
- Firestore failure recovery
