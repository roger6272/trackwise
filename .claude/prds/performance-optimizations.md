---
name: performance-optimizations
description: Cross-codebase performance and reliability optimizations for Flutter app and ESP32 firmware
status: backlog
created: 2026-01-22T18:58:39Z
---

# PRD: Performance Optimizations

## Executive Summary

Implement targeted performance and reliability optimizations across both the Flutter app and ESP32 firmware. The optimizations are organized into 4 phases based on risk level and impact, starting with safe Flutter refactors and progressing to timing-sensitive firmware changes.

## Problem Statement

### What Problem Are We Solving?

Analysis of the Trackwise codebase identified several optimization opportunities:

1. **Device Longevity**: ESP32 writes to NVS flash on every button press, causing premature flash wear (100k write limit)
2. **Performance**: O(n²) algorithm in item reordering causes lag with large item lists
3. **Reliability**: BLE chunk timing mismatch between app (30ms) and firmware (10-20ms) causes intermittent sync failures
4. **Code Quality**: 137 debug print statements in production, duplicate utility functions

### Why Is This Important Now?

- Heavy users may experience device failures within months due to NVS wear
- Users with 50+ items report noticeable lag during category reordering
- Intermittent BLE sync failures degrade user experience
- Technical debt slows development velocity

## User Stories

### End User

- As a user, I want my Trackwise device to last for years, not months
- As a user, I want smooth performance even with many items
- As a user, I want reliable BLE sync without failures

### Developer

- As a developer, I want clean production logs without debug noise
- As a developer, I want a single source of truth for utility functions
- As a developer, I want consistent timing constants across codebases

## Requirements

### Functional Requirements

All optimizations must maintain **exact behavioral parity** with current implementation. No user-facing changes except improved performance and reliability.

### Phase 1: Safe Flutter Optimizations (No device testing needed)

| ID | Requirement | File | Lines | Risk |
|----|-------------|------|-------|------|
| P1-1 | Fix O(n²) item reordering to O(n) using Map lookup | `items_bloc.dart` | 471-476 | Low |
| P1-2 | Remove duplicate `castToType()` function | `serialization_util.dart` | 87-106 | Low |
| P1-3 | Wrap 137 debug prints in `kDebugMode` conditionals | 29 files | Various | Low |
| P1-4 | Cache category names map instead of rebuilding every frame | `items_list_page.dart` | 102-111 | Low |

**Acceptance Criteria:**
- All existing tests pass
- `flutter build apk --debug` succeeds
- No functional changes to app behavior

### Phase 2: Safe Firmware Optimizations (Need device testing)

| ID | Requirement | File | Lines | Risk |
|----|-------------|------|-------|------|
| P2-1 | Use `snprintf()` for preference key generation | `Trackwise_ESP32.ino` | 332-341 | Low |
| P2-2 | Convert blocking vibration to non-blocking timer | `Trackwise_ESP32.ino` | 790-795 | Medium |

**Acceptance Criteria:**
- Device compiles and uploads successfully
- Button presses, vibration, and item selection work correctly
- No BLE interference during vibration

### Phase 3: Timing-Sensitive Changes (Need thorough testing)

| ID | Requirement | File | Lines | Risk |
|----|-------------|------|-------|------|
| P3-1 | Unify chunk delay to 20ms (app + firmware) | Both codebases | Various | Medium |
| P3-2 | Implement NVS write batching (batch every 10 increments) | `Trackwise_ESP32.ino` | 797-829 | Medium |
| P3-3 | Add flush-on-disconnect safety for write batching | `Trackwise_ESP32.ino` | New | Medium |

**Acceptance Criteria:**
- BLE sync completes reliably (test 20+ sync cycles)
- Item counts persist correctly after power cycle
- No data loss on unexpected disconnect
- Device lifespan extended (write frequency reduced by 10x)

### Phase 4: Architectural Improvements (Long-term)

| ID | Requirement | File | Lines | Risk |
|----|-------------|------|-------|------|
| P4-1 | Use `BlocSelector` instead of `BlocBuilder` for flags | `items_list_page.dart` | Various | Medium |
| P4-2 | Cache BLE service discovery results | `bluetooth_datasource_impl.dart` | Various | Medium |
| P4-3 | Add firmware error responses via NOTIFY | `Trackwise_ESP32.ino` | WriteCallback | Medium |

**Acceptance Criteria:**
- Reduced widget rebuilds (measurable via DevTools)
- Faster BLE reconnection (400-1000ms improvement)
- Better debugging with explicit error messages

### Non-Functional Requirements

- **Backwards Compatibility**: All changes must work with existing device firmware during rollout
- **Rollback Strategy**: Each phase should be independently revertable
- **Testing**: Phase 2+ requires physical device testing

## Success Criteria

| Metric | Current | Target |
|--------|---------|--------|
| NVS writes per increment | 2 | 0.2 (10x reduction) |
| Category reorder time (100 items) | O(n²) | O(n) |
| BLE sync success rate | ~95% | 99%+ |
| Debug print statements in prod | 137 | 0 |

## Constraints & Assumptions

### Constraints

- Firmware changes require physical ESP32 device for testing
- Cannot break existing app-firmware communication protocol
- Must maintain feature parity throughout

### Assumptions

- ESP32 device is available for Phase 2+ testing
- NVS has approximately 100k write cycles before wear
- Current users have not hit NVS wear limit yet

## Out of Scope

- Major architectural refactoring (splitting monolithic files)
- Adding new features or capabilities
- Changing BLE protocol format (only timing)
- UI/UX changes

## Dependencies

### Internal

- Flutter test suite must pass before each phase
- ESP32 toolchain (Arduino IDE or PlatformIO) for firmware changes

### External

- None

## Implementation Phases

### Phase 1 (Est. 1-2 hours)
Safe Flutter-only changes. Can be deployed immediately.

### Phase 2 (Est. 2-3 hours)
Safe firmware changes. Requires device testing before deployment.

### Phase 3 (Est. 4-6 hours)
Timing-sensitive changes. Requires thorough testing with multiple sync cycles.

### Phase 4 (Est. 1-2 days)
Architectural improvements. Can be done incrementally.

## Rollback Plan

Each phase is independent:
- **Phase 1**: Git revert Flutter changes
- **Phase 2-3**: Flash previous firmware version via USB
- **Phase 4**: Git revert, no firmware impact

## Test Plan

### Phase 1 Testing
- Run `flutter test`
- Run `flutter build apk --debug`
- Manual smoke test of items list

### Phase 2-3 Testing
- Flash firmware to device
- Test button press increment (10+ presses)
- Test reset functionality
- Test BLE sync (connect, sync items, disconnect, reconnect)
- Test power cycle (verify data persistence)
- Test vibration during BLE activity

### Phase 4 Testing
- Profile with Flutter DevTools (widget rebuild count)
- Measure BLE reconnection time
- Verify error messages appear in app on firmware errors
