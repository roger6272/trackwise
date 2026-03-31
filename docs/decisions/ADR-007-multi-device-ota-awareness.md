# ADR-007: Multi-Device OTA — Two-Dimensional State with Sequential Transfers

**Status:** Accepted
**Date:** 2026-03-30
**Context:** OTA firmware updates, multi-device BLE architecture

## Problem

The original OTA system used a single flat state (`OtaInitial`, `OtaUpdateAvailable`, `OtaBlocTransferring`, etc.) in a singleton `OtaBloc`. With multiple devices connected simultaneously, the system could only track one device's update status. The first connected device was checked; others were ignored.

## Decision

Split `OtaBlocState` into two independent dimensions:

1. **Per-device awareness** (`Map<String, OtaDeviceStatus>`): Each connected device has its own update status (up-to-date, update available, dismissed, app update required). Keyed by `deviceInstanceId`.

2. **Active transfer** (`OtaTransferState?`): At most one firmware transfer at a time. The `isTransferActive` guard prevents starting a second transfer while one is in progress.

The `OtaBloc` remains a singleton (`@lazySingleton`). Events carry `deviceInstanceId` for routing.

## Rationale

**Why not per-device OtaBloc instances?**
- Managing bloc lifecycle tied to device connection/disconnection adds complexity
- BLE bandwidth only supports one OTA transfer at a time anyway
- The singleton + map approach gives multi-device awareness without lifecycle management

**Why not sequential checking (Option A — check one device at a time)?**
- Users don't see the full picture upfront
- After updating one device, they'd have to wait for the next check to discover another device needs updating

**Why two dimensions instead of many flat states?**
- N devices × M transfer stages would create a combinatorial explosion of state classes
- The two dimensions are independent: device A can be "update available" while device B is mid-transfer
- `activeTransfer` being nullable naturally enforces the one-at-a-time constraint

## Consequences

### Positive
- Users see all devices needing updates at once, with device names in banners
- Can dismiss banners per-device independently
- Sequential transfer prevents BLE bandwidth conflicts
- Disconnect during transfer is handled correctly (except during reboot, which is expected)

### Negative
- State is more complex than the original flat model — `OtaBlocState` with two fields vs simple subclasses
- Consumers must check both `deviceStatuses` and `activeTransfer` when building UI
- `DismissTransferResult` event needed to clear terminal states (complete/error)

### Neutral
- The `OtaBloc` singleton pattern is preserved — no DI changes needed
- BLE protocol unchanged — multi-device awareness is entirely app-side
- Transfer error/complete banners are handled by the progress sheet only (not duplicated in the banner widget)

## References

- Implementation plan: `docs/plans/2026-03-30-multi-device-ota-awareness.md`
- State model: `lib/features/ota/presentation/bloc/ota_state.dart`
- Device status: `lib/features/ota/presentation/bloc/ota_device_status.dart`
