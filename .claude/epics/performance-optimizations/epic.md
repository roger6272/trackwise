---
name: performance-optimizations
status: completed
created: 2026-01-22T19:00:07Z
progress: 100%
prd: .claude/prds/performance-optimizations.md
github: https://github.com/roger6272/trackwise/issues/19
updated: 2026-01-22T19:24:30Z
---

# Epic: Performance Optimizations

## Overview

Cross-codebase optimization effort targeting Flutter app performance and ESP32 firmware reliability. The work is structured into 4 phases ordered by risk level, allowing safe Flutter-only changes to be deployed immediately while firmware changes require device testing.

## Architecture Decisions

1. **Map-based lookup for O(n) reordering**: Replace `firstWhere()` inside `map()` with pre-built Map for O(1) item lookup
2. **Consolidated utility functions**: Single source of truth in `app_util.dart`, remove duplicates
3. **Conditional debug logging**: Use `kDebugMode` guards to eliminate production log noise
4. **Non-blocking firmware patterns**: Timer-based vibration instead of blocking `delay()`
5. **Write batching with safety flush**: Batch NVS writes every 10 increments, flush on disconnect

## Technical Approach

### Flutter App Changes

- **items_bloc.dart**: Refactor `_onReorderItemsInCategory` to use `Map.fromIterable()` for O(1) lookups
- **serialization_util.dart**: Remove `castToType()` duplicate, import from `app_util.dart`
- **29 files with debug prints**: Wrap in `if (kDebugMode)` or use `debugPrint()` which is no-op in release
- **items_list_page.dart**: Cache category names map in state, rebuild only when categories change

### Firmware Changes

- **Preference keys**: Use `snprintf(key, sizeof(key), "id_%d", i)` instead of String concatenation
- **Vibration**: Implement timer-based non-blocking vibration with `millis()` check in loop
- **Chunk delays**: Standardize to 20ms across all notification functions
- **NVS batching**: Track dirty state, write every 10 increments or on disconnect/power-off

### BLE Protocol

- **App constant**: Change `chunkDelayMs` from 30 to 20 in `bluetooth_constants.dart`
- **Firmware delays**: Update `delay(10)` to `delay(20)` at lines 115, 730

## Implementation Strategy

### Development Phases

1. **Phase 1** (Flutter-only): Can be merged and deployed immediately
2. **Phase 2** (Safe firmware): Merge after device smoke test
3. **Phase 3** (Timing changes): Requires 20+ BLE sync cycle testing
4. **Phase 4** (Architectural): Incremental, can be done over time

### Risk Mitigation

- Each phase is independently revertable
- Firmware changes tested on physical device before merge
- Write batching includes flush-on-disconnect safety

### Testing Approach

- Flutter: Existing test suite + debug build verification
- Firmware: Manual device testing per phase acceptance criteria

## Tasks Created

### Phase 1: Safe Flutter Optimizations (parallel: true)
- [ ] #23 - Fix O(n²) reorder and remove duplicate utility (0.5h)
- [ ] #26 - Wrap debug prints in kDebugMode (1h)
- [ ] #28 - Cache category names map (0.5h)

### Phase 2: Safe Firmware Optimizations
- [ ] #22 - Firmware snprintf and non-blocking vibration (2h, parallel: true)

### Phase 3: Timing-Sensitive Changes (sequential)
- [ ] #25 - Unify BLE chunk delays to 20ms (0.5h, depends: #22)
- [ ] #27 - NVS write batching with flush safety (4h, depends: #22, #25)

### Phase 4: Architectural Improvements
- [ ] #20 - BlocSelector refactor for items list (2h, depends: #23, #28)
- [ ] #21 - BLE service discovery caching (3h, depends: #25)
- [ ] #24 - Firmware error responses via NOTIFY (2h, depends: #25, #27)

**Total tasks:** 9
**Parallel tasks:** 5 (#23, #26, #28, #22, #20)
**Sequential tasks:** 4 (#25, #27, #21, #24)
**Estimated total effort:** 15.5 hours

## Dependencies

### Internal
- Flutter test suite passing
- ESP32 device available for Phase 2+
- Arduino IDE or PlatformIO for firmware compilation

### External
- None

## Success Criteria (Technical)

| Metric | Verification Method |
|--------|---------------------|
| O(n) reorder | Code review confirms Map usage |
| Zero duplicate utils | Grep confirms single `castToType` |
| Zero prod debug prints | Release build log analysis |
| 10x NVS write reduction | Firmware serial log count |
| 99%+ BLE sync success | 20+ sync cycle test |

## Estimated Effort

| Phase | Effort | Critical Path |
|-------|--------|---------------|
| Phase 1 | 1-2 hours | No |
| Phase 2 | 2-3 hours | Device testing |
| Phase 3 | 4-6 hours | BLE sync testing |
| Phase 4 | 1-2 days | None |

**Total**: ~2-3 days including testing

**Critical path**: Device availability for Phase 2+ testing
