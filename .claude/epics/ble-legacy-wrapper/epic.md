---
name: ble-legacy-wrapper
status: in-progress
created: 2026-01-16T03:26:55Z
progress: 66%
prd: .claude/prds/ble-legacy-wrapper.md
github: https://github.com/roger6272/trackwise/issues/15
---

# Epic: BLE Legacy Wrapper

## Overview

Extract working BLE communication code from `lib/custom_code/actions/` into `lib/core/utils/ble_legacy.dart`, removing FlutterFlow dependencies while preserving identical functionality. This unblocks Phase 3c cleanup of the Trackwise migration.

## Architecture Decisions

1. **Singleton State Pattern** - Replace `FFAppState` with a simple singleton `BleLegacyState` class
   - Rationale: Minimal change, matches existing behavior, no dependency injection needed

2. **Single File Extraction** - All 4 BLE functions in one file (`ble_legacy.dart`)
   - Rationale: Functions are tightly coupled, keeping together preserves the working call chain

3. **Preserve Exact Behavior** - No refactoring, just relocate and remove FF imports
   - Rationale: Code is hardware-tested, any changes risk breaking BLE communication

## Technical Approach

### Files to Create

```
lib/core/utils/
├── ble_legacy_state.dart    # FFAppState replacement (singleton)
└── ble_legacy.dart          # Extracted BLE functions
```

### State Replacement

| FFAppState Field | BleLegacyState Field |
|------------------|---------------------|
| `currentLogPage` | `currentLogPage` |
| `isactivated` | `isactivated` |
| `update(() => ...)` | Direct assignment |

### Functions to Extract

1. `prepareBLERead(deviceId, type, page)` - from `prepare_b_l_e_read.dart`
2. `readBLEDataAndHandle(deviceId)` - from `read_b_l_e_data_and_handle.dart`
3. `decodeInsertLogs(message, deviceId)` - from `decode_insert_logs.dart`
4. `decodeUpdateItemStatus(message)` - from `decode_update_item_status.dart`

### Imports to Remove

- `/flutter_flow/flutter_flow_util.dart`
- `/flutter_flow/flutter_flow_theme.dart`
- `/flutter_flow/custom_functions.dart`
- `index.dart` (custom actions index)

### Imports to Keep

- `/backend/backend.dart` (Firebase)
- `package:flutter_blue_plus/flutter_blue_plus.dart`
- `package:cloud_firestore/cloud_firestore.dart`
- `package:firebase_auth/firebase_auth.dart`

## Implementation Strategy

**Phase 1: Extract** - Create new files with extracted code
**Phase 2: Wire** - Update imports in repository and test page
**Phase 3: Verify** - Test with real device
**Phase 4: Cleanup** - Delete `custom_code/actions/`

## Task Breakdown Preview

- [ ] Task 1: Create BLE legacy wrapper files
- [ ] Task 2: Update imports and verify build
- [ ] Task 3: Test with device and delete old files

## Dependencies

- None - this is a code extraction with no external dependencies
- Hardware testing requires ESP32 device

## Success Criteria (Technical)

- [ ] App builds successfully (`flutter build apk --debug`)
- [ ] All tests pass (`flutter test`)
- [ ] BLE prefs sync works with device
- [ ] BLE logs sync works with device (including pagination)
- [ ] `clear_logs` command sent after log sync
- [ ] `lib/custom_code/actions/` directory deleted

## Estimated Effort

- **Total**: ~2 hours
- **Task 1**: 45 minutes (extraction)
- **Task 2**: 15 minutes (imports + build)
- **Task 3**: 60 minutes (device testing + cleanup)

## Risk Mitigation

- Keep `custom_code/actions/` until device testing passes
- Test pagination (multiple log pages) before deleting
- Verify `clear_logs` command is sent to device
