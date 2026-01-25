---
name: multi-device-enablement
status: backlog
created: 2026-01-25T22:43:11Z
progress: 0%
prd: .claude/prds/multi-device-enablement.md
github: [Will be updated when synced to GitHub]
---

# Epic: multi-device-enablement

## Overview

Implement multi-device support for Trackwise, allowing users to pair multiple physical ESP32 devices to a single account. Uses sync_seq comparison for conflict detection - matching sync_seq means device is in sync (device is source of truth), mismatch means conflict (app overrides device).

## Architecture Decisions

1. **sync_seq for conflict detection**: Simple integer comparison determines sync state - no need to track which device was last used
2. **Device is SOT for normal sync**: When sync_seq matches, device data flows to app
3. **App is SOT for override**: When sync_seq mismatches, app data flows to device (chunked for BLE MTU)
4. **Account lock on device**: Device stores Firebase UID to prevent unauthorized access
5. **Fresh Firestore fetch**: Always fetch sync_seq from server (not cached) to support multiple app instances

## Technical Approach

### Firmware (ESP32)
- NVS storage for: paired_uid, device_instance_id, sync_seq_no
- Handshake protocol combining account lock check + sync sequence check
- Conflict state: "SEE APP" display, disable buttons, exit on disconnect
- Override chunking: receive items in chunks, validate at end
- Factory reset: clear pairing, regenerate device ID, clear items

### App (Flutter)
- Firestore schema: sync_sequence_no, last_selected_device_item_id, paired_devices[]
- BLE commands: handshake, override_start/chunk/end, sync_complete
- Sync flows with internet check and Firestore retry logic
- Conflict dialog and paired devices management UI

### Data Flow
```
Normal Sync (sync_seq match):
  App → handshake → Device (in_sync)
  App ← prefs ← Device
  App → sync_complete → Device (seq_updated)
  App → Firestore

Override (sync_seq mismatch):
  App → handshake → Device (conflict)
  User confirms in app
  App → override_start/chunks/end → Device (override_complete)
  App → Firestore
```

## Implementation Strategy

Sequential phases - firmware must be complete before app can use new protocol:

1. **Phase 1 - Firmware Foundation**: Rename device_id, add NVS storage, device instance ID
2. **Phase 2 - Firmware Protocol**: Handshake, conflict state, override handling
3. **Phase 3 - App Backend**: Firestore schema, BLE commands, sync flows
4. **Phase 4 - App UI**: Conflict dialog, paired devices page

## Task Breakdown

- [ ] Task 1: Firmware - Rename device_id to device_item_id throughout codebase
- [ ] Task 2: Firmware - Implement NVS storage, device instance ID, and pairing mode
- [ ] Task 3: Firmware - Implement handshake protocol and conflict state handling
- [ ] Task 4: Firmware - Implement override chunking and sync_complete
- [ ] Task 5: App - Update Firestore schema and user repository
- [ ] Task 6: App - Implement BLE commands (handshake, override, sync_complete)
- [ ] Task 7: App - Implement sync flows with internet check and retry logic
- [ ] Task 8: App - Implement conflict dialog and paired devices page

## Dependencies

| Dependency | Type | Status |
|------------|------|--------|
| ESP32 development environment | External | Available |
| Firestore backend | Internal | In use |
| Existing BLE protocol | Internal | To be extended |
| Tasks 1-4 (Firmware) | Internal | Blocks Tasks 5-8 (App) |

## Success Criteria (Technical)

1. All 13 BLE protocol messages implemented and tested
2. Handshake correctly returns in_sync/conflict/wrong_account
3. Override chunking works for 0-100 items
4. Firestore retry logic handles network failures
5. All 18 manual test scenarios pass

## Estimated Effort

| Phase | Effort |
|-------|--------|
| Firmware (Tasks 1-4) | ~3-4 days |
| App Backend (Tasks 5-7) | ~2-3 days |
| App UI (Task 8) | ~1-2 days |
| Integration Testing | ~1 day |
| **Total** | **~7-10 days** |

## Reference

Full technical implementation details: `docs/MULTI_DEVICE_IMPLEMENTATION_PLAN.md`

## Tasks Created

- [ ] 001.md - Firmware - Rename device_id to device_item_id (parallel: true)
- [ ] 002.md - Firmware - NVS storage, device instance ID, and pairing mode (parallel: false, depends: 001)
- [ ] 003.md - Firmware - Handshake protocol and conflict state handling (parallel: false, depends: 001, 002)
- [ ] 004.md - Firmware - Override chunking and sync_complete (parallel: false, depends: 001, 002, 003)
- [ ] 005.md - App - Update Firestore schema and user repository (parallel: true)
- [ ] 006.md - App - Implement BLE commands (parallel: false, depends: 005)
- [ ] 007.md - App - Implement sync flows with internet check and retry (parallel: false, depends: 005, 006)
- [ ] 008.md - App - Implement conflict dialog and paired devices page (parallel: false, depends: 005, 006, 007)

**Summary:**
- Total tasks: 8
- Parallel tasks: 2 (001, 005 can start immediately)
- Sequential tasks: 6
- Estimated total effort: 52-68 hours (~7-10 days)
