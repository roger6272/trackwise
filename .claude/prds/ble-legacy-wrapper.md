---
name: ble-legacy-wrapper
description: Extract BLE code from FlutterFlow custom_code to unblock Phase 3c cleanup
status: in-progress
created: 2026-01-15T12:00:00Z
parent: trackwise-app-migration
---

# PRD: BLE Legacy Wrapper

## Executive Summary

Extract the working BLE communication code from `lib/custom_code/actions/` into a clean wrapper at `lib/core/utils/ble_legacy.dart`, removing FlutterFlow dependencies while preserving functionality. This unblocks Phase 3c of the Trackwise migration by allowing deletion of the `custom_code/actions/` directory.

## Problem Statement

### What Problem Are We Solving?

Phase 3c cleanup is blocked because:
- `bluetooth_repository_impl.dart` imports `prepare_b_l_e_read.dart` from `custom_code/actions/`
- `bluetooth_test_page.dart` imports the same file for comparison testing
- The old code works but has FlutterFlow dependencies (`FFAppState`, `flutter_flow_util`)
- We cannot delete `custom_code/actions/` until these imports are removed

### Why Is This Important Now?

- Phase 3c has been blocked since discovering this dependency
- The old BLE code is battle-tested and works with real hardware
- Full reimplementation is risky and time-consuming (6-8 hours)
- A wrapper approach preserves working code while removing FF dependencies (~2 hours)

## Requirements

### Functional Requirements

1. **Extract 4 functions** from `custom_code/actions/` to `lib/core/utils/ble_legacy.dart`:
   - `prepareBLERead(deviceId, type, page)` - sends prepare_read command
   - `readBLEDataAndHandle(deviceId)` - reads and dispatches response
   - `decodeInsertLogs(message, deviceId)` - writes logs to Firebase
   - `decodeUpdateItemStatus(message)` - updates item counts in Firebase

2. **Remove FlutterFlow imports**:
   - Remove `flutter_flow_util.dart` import
   - Remove `flutter_flow_theme.dart` import
   - Remove `index.dart` (custom actions index)
   - Remove `custom_functions.dart` import

3. **Replace FFAppState dependencies**:
   - `FFAppState().currentLogPage` → injectable state or simple class
   - `FFAppState().isactivated` → injectable state or callback
   - `FFAppState().update()` → direct state mutation or callback

4. **Update clean architecture imports**:
   - `bluetooth_repository_impl.dart` → import from `core/utils/ble_legacy.dart`
   - `bluetooth_test_page.dart` → import from `core/utils/ble_legacy.dart`

5. **Delete old files** after migration:
   - Delete `lib/custom_code/actions/` directory (all 23 files)

### Non-Functional Requirements

1. **Zero behavior change** - BLE communication must work identically
2. **Preserve timing** - Keep the double `discoverServices()` pattern
3. **Maintain pagination** - Log pagination must continue to work
4. **Keep clear_logs** - Device log clearing must still function

## Technical Approach

### New File Structure

```
lib/core/utils/
├── ble_legacy.dart           # Extracted BLE functions
└── ble_legacy_state.dart     # State management replacement for FFAppState
```

### State Replacement Strategy

Create a simple singleton to replace `FFAppState` BLE-related fields:

```dart
// lib/core/utils/ble_legacy_state.dart
class BleLegacyState {
  static final BleLegacyState _instance = BleLegacyState._();
  factory BleLegacyState() => _instance;
  BleLegacyState._();

  int currentLogPage = 0;
  String? isactivated;

  void resetLogPage() => currentLogPage = 0;
  void incrementLogPage() => currentLogPage++;
}
```

### Import Mapping

| Old Import | New Import |
|------------|------------|
| `/flutter_flow/flutter_flow_util.dart` | Remove (not needed) |
| `/flutter_flow/flutter_flow_theme.dart` | Remove (not needed) |
| `/flutter_flow/custom_functions.dart` | Remove (not needed) |
| `index.dart` | Direct function calls |
| `/backend/backend.dart` | Keep (Firebase) |
| `/backend/schema/structs/index.dart` | Keep (if needed) |

### Migration Steps

1. Create `lib/core/utils/ble_legacy_state.dart` with state class
2. Create `lib/core/utils/ble_legacy.dart` with extracted functions
3. Update `bluetooth_repository_impl.dart` import
4. Update `bluetooth_test_page.dart` import
5. Test BLE functionality with real device
6. Delete `lib/custom_code/actions/` directory

## Success Criteria

| Metric | Target |
|--------|--------|
| `custom_code/actions/` deleted | Yes |
| BLE prefs sync works | Verified with device |
| BLE logs sync works | Verified with device |
| Pagination works | Multiple log pages fetched |
| `clear_logs` command sent | Verified in device logs |
| App builds successfully | `flutter build apk --debug` |
| All tests pass | `flutter test` |

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Missing import causes runtime error | Test with real device before deleting old files |
| State singleton causes issues | Keep interface simple, match FFAppState behavior |
| Timing changes break BLE | Preserve exact function structure and delays |

## Out of Scope

- Refactoring to clean architecture patterns (future task)
- Adding proper error handling beyond existing code
- Changing BLE protocol or command structure
- Unit tests for legacy wrapper (existing integration tests suffice)

## Tasks

### Task 1: Create BLE Legacy State
Create `lib/core/utils/ble_legacy_state.dart` with singleton class to replace FFAppState BLE fields.

**Acceptance Criteria:**
- File created with `BleLegacyState` singleton class
- Has `currentLogPage` int field
- Has `isactivated` String? field
- Has `resetLogPage()` and `incrementLogPage()` methods

### Task 2: Extract BLE Functions
Create `lib/core/utils/ble_legacy.dart` by copying and modifying 4 functions from `custom_code/actions/`.

**Acceptance Criteria:**
- `prepareBLERead` extracted and working
- `readBLEDataAndHandle` extracted and working
- `decodeInsertLogs` extracted, uses `BleLegacyState` instead of FFAppState
- `decodeUpdateItemStatus` extracted, uses `BleLegacyState` instead of FFAppState
- All FlutterFlow imports removed
- All functions compile without errors

### Task 3: Update Repository Import
Update `bluetooth_repository_impl.dart` to import from new location.

**Acceptance Criteria:**
- Import changed from `custom_code/actions/prepare_b_l_e_read.dart` to `core/utils/ble_legacy.dart`
- File compiles without errors
- `requestData()` method still calls `prepareBLERead`

### Task 4: Update Test Page Import
Update `bluetooth_test_page.dart` to import from new location.

**Acceptance Criteria:**
- Import changed to `core/utils/ble_legacy.dart`
- File compiles without errors
- Test page functions work

### Task 5: Verify BLE Functionality
Test all BLE operations with real ESP32 device.

**Acceptance Criteria:**
- Device scan works
- Device connection works
- Time sync works
- Send items works
- Request prefs works (data updates in Firebase)
- Request logs works (pagination and clear_logs)

### Task 6: Delete Old Files
Delete `lib/custom_code/actions/` directory and update index.dart.

**Acceptance Criteria:**
- `lib/custom_code/actions/` directory deleted
- `lib/custom_code/index.dart` updated or deleted
- App builds successfully
- All imports resolved
