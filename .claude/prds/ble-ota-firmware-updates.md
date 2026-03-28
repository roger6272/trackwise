---
name: ble-ota-firmware-updates
description: Over-the-air firmware updates for ESP32 device delivered via BLE from the Flutter app
status: backlog
created: 2026-03-28T05:52:44Z
---

# PRD: BLE OTA Firmware Updates

## Executive Summary

Add over-the-air firmware update capability to the Traxelos app, allowing users to update their ESP32 device firmware directly from the app over BLE. This is a prerequisite for shipping a commercial product — users cannot be expected to USB-flash firmware. The feature spans firmware, app, and Firebase infrastructure.

**Target:** Complete within 1 week (by 2026-04-04).

**MVP priority if time-constrained:** Phases 1-4 (firmware + Firebase + app data + app UI) are essential. Phase 5 tests and Phase 6 docs can follow immediately after. The publish script (Req 15) is developer tooling that can be deferred without blocking the core OTA feature.

## Problem Statement

### What Problem Are We Solving?

Currently, firmware updates require a USB connection and PlatformIO/Arduino IDE knowledge. This is acceptable during development but completely blocks commercial distribution. Every post-ship bug fix or feature addition requires physical access to every device.

### Why Is This Important Now?

- **Blocks commercial viability** — no consumer product can ship without remote update capability
- **Protocol evolution** — BLE protocol will continue to change (v2→v3, etc.); forced updates ensure all devices stay compatible
- **Safety net** — bugs discovered post-manufacturing need a fix path that doesn't require device recall
- **Battery hardware** — MAX17048 fuel gauge integration (required for OTA battery check) also enables battery level display in-app, a commonly expected feature

## User Stories

### US-1: Optional Firmware Update

**As a** Traxelos user,
**I want to** see when a firmware update is available and choose to install it,
**so that** I get new features and bug fixes without any special tools.

**Acceptance Criteria:**
- Dismissable banner appears on device detail page when newer firmware exists
- Tapping banner shows changelog, version info, and "Update Now" button
- Progress UI shows download and transfer progress sequentially
- Device reboots automatically after successful transfer
- App confirms new version after reconnect with success message
- User can cancel mid-transfer with confirmation dialog

### US-2: Required Firmware Update

**As a** product operator,
**I want to** force devices below a minimum firmware version to update,
**so that** protocol-breaking changes don't leave devices in a broken state.

**Acceptance Criteria:**
- Non-dismissable banner when device version < `min_firmware_version` (from Remote Config)
- Device functions normally until user starts the update — banner is persistent but doesn't block usage
- `min_firmware_version` is updatable server-side without an app release
- App falls back to hardcoded minimum when Remote Config is unreachable

### US-3: Safe Update Experience

**As a** user,
**I want** firmware updates to never brick my device,
**so that** I can update with confidence.

**Acceptance Criteria:**
- Full device sync completes before OTA transfer begins (prevents loss of RAM-based count logs on reboot)
- Update blocked when battery < 20% with clear message
- Failed transfer (timeout, disconnect) leaves device on working firmware
- SHA256 hash mismatch rejects the update before switching partitions
- If new firmware crashes on first boot, device automatically rolls back to previous version
- Cancel mid-transfer is safe — device returns to normal operation

### US-4: App Version Gate

**As a** product operator,
**I want** old app versions to be told to update the app instead of attempting incompatible firmware,
**so that** firmware/app version mismatches don't cause failures.

**Acceptance Criteria:**
- If app version < `min_app_version` (from `latest.json`), show "Update the Traxelos app" instead of firmware update banner
- No firmware download or transfer is attempted

### US-5: Battery Level Display

**As a** Traxelos user,
**I want to** see my device's battery level in the app,
**so that** I know when to charge it.

**Acceptance Criteria:**
- Battery percentage displayed on device card (replacing existing `battery_unknown` / `--%` placeholder in `bluetooth_page.dart`)
- Updates on connect and periodically while connected (via BLE Battery Level notify)
- Appropriate battery icon based on level (full, half, low, critical)

### US-6: Firmware Publishing

**As a** developer,
**I want** a simple, error-proof way to publish new firmware,
**so that** I don't accidentally upload the wrong binary or SHA256 hash.

**Acceptance Criteria:**
- Script generates `latest.json` with correct SHA256 hash automatically
- Clear manual steps for uploading to Firebase Storage
- Optional: update Remote Config `min_firmware_version` for forced updates

## Requirements

### Functional Requirements

#### Firmware (ESP32)

1. **Dual-OTA partition table** — device must be flashed with dual-OTA partition layout (one-time USB prerequisite)
2. **Battery reading** — read SOC% from MAX17048 over I2C (address `0x36`)
3. **BLE Battery Service** — standard Battery Service (0x180F) with Battery Level characteristic (0x2A19)
4. **OTA Data characteristic** — new write-with-response characteristic (UUID `12345678-1234-1234-1234-123456789011`) for receiving binary chunks. **Note:** Design doc originally specified `...9001` which collides with existing `CHAR_READ` — corrected here.
5. **OTA commands** — `ota_start`, `ota_end`, `reboot` on existing command characteristic
6. **OTA state machine** — IDLE → RECEIVING → VERIFYING → VERIFIED → REBOOTING
7. **Timeouts** — 30s inactivity timeout in RECEIVING, 10s auto-reboot timeout in VERIFIED
8. **Operation pause** — ignore button presses and show "updating" on display during OTA
9. **Rollback protection** — call `esp_ota_mark_app_valid_cancel_rollback()` at end of `setup()` after all peripherals confirmed working
10. **Incremental SHA256** — compute hash using `mbedtls_sha256` as chunks arrive, no RAM buffering

#### Firebase Infrastructure

11. **Storage structure** — `firmware/latest.json` + `firmware/bins/<binary files>`
12. **Metadata file** — `latest.json` with version, file path, SHA256, min_app_version, changelog, released_at
13. **Remote Config** — `min_firmware_version` parameter, updatable server-side
14. **Security Rules** — authenticated read-only for firmware files, admin-only upload
15. **Publish script** — `publish_firmware.sh` that auto-generates `latest.json` with correct SHA256

#### App (Flutter)

16. **Read battery level** — discover Battery Service (0x180F) and Battery Level characteristic (0x2A19) during `discoverServices()`. Read on connect, subscribe to notify for updates. Display in existing battery placeholder UI (`bluetooth_page.dart:714`). Requires new fields on `DeviceConnection` (e.g., `batteryLevelChar`).
17. **Sync before OTA** — perform a full device sync (read logs, update counts) before starting OTA transfer. Device count logs are RAM-only (`CountLog` array) and lost on reboot — skipping sync means silent data loss.
18. **Update check on connect** — compare device firmware version against latest available and minimum required
19. **Update banner** — dismissable (optional) or non-dismissable (required) on device detail page
20. **Download** — fetch `.bin` from Firebase Storage on demand
21. **Discover OTA Data characteristic** — add OTA Data (`...9011`) to `discoverServices()` and `DeviceConnection` (new `otaDataChar` field). Unlike existing required characteristics, OTA Data is optional — don't fail connection if absent (older firmware won't have it).
22. **BLE OTA chunk sizing** — reuse existing negotiated MTU from `DeviceConnection.negotiatedMtu` (already negotiated on connect in `bluetooth_datasource_impl.dart`). No new MTU negotiation code needed.
23. **BLE transfer** — chunk binary using negotiated MTU size, write-with-response to OTA Data characteristic
24. **Progress UI** — bottom sheet showing download → transfer progress, with cancel + confirmation
25. **Post-reboot handling** — suppress disconnect error, auto-reconnect within 30-second timeout, verify new version via handshake. Must integrate with existing `BluetoothBloc` auto-reconnect infrastructure (`_devicesToReconnect`, exponential backoff) — mark OTA reboot as expected disconnect to suppress error UI. If device doesn't reconnect within 30s, show error: "Device didn't respond after update. Try turning it off and on again."
26. **App version gate** — show "Update the Traxelos app" when `min_app_version` > current app version. Use existing `package_info_plus` dependency for app version.
27. **Offline handling** — show error if user taps "Update Now" without internet
28. **Version comparison** — implement semver comparison (split on `.`, compare integers) in `CheckForUpdate` use case. No `pub_semver` dependency exists — hand-roll for strict `major.minor.patch` format. Must handle edge cases like `1.9.0` vs `1.10.0` correctly. Needs unit tests.

#### Analytics

29. **OTA telemetry events** — add to existing `AnalyticsService` (`lib/core/services/analytics_service.dart`): `ota_started`, `ota_completed`, `ota_failed(reason)`, `ota_cancelled`. Firebase Analytics is already a dependency.
30. **Version tracking** — add `setUserProperty(name: 'firmware_version', value: ...)` to existing `AnalyticsService`, called on each device connect, enabling fleet-wide version distribution queries

### Non-Functional Requirements

1. **Transfer speed** — full update (100KB binary) completes in under 30 seconds on typical BLE connection
2. **Reliability** — no update path leads to a bricked device; every failure mode has a recovery path
3. **RAM usage** — firmware OTA uses minimal RAM (incremental SHA256 + direct flash writes, no buffering)
4. **Offline resilience** — Remote Config fallback to hardcoded value; update check doesn't crash when offline
5. **Battery safety** — update blocked below 20% SOC to prevent mid-update power loss

## Success Criteria

| Metric | Target |
|--------|--------|
| OTA transfer completes successfully | ≥ 95% of attempts (on good BLE connection) |
| Transfer time for 100KB binary | < 30 seconds |
| Zero bricked devices from OTA | 100% — every failure path recovers |
| Rollback on crash works | Verified with deliberately broken firmware |
| Forced update enforcement | 100% of devices below min_version see required banner |
| Battery gate works | 100% rejection when SOC < 20% |
| Battery level displayed | Replaces placeholder with live % on connected devices |

## Constraints & Assumptions

### Constraints

- **One-time USB flash required** — existing devices must be manually flashed with dual-OTA partition table before they can receive OTA updates. This is a hardware prerequisite, not solvable in software.
- **BLE throughput** — limited by BLE MTU negotiation. Worst case (default MTU 23) is ~20 bytes/chunk, making transfers slower but still functional.
- **No signing in v1** — SHA256 integrity only. Cryptographic signing deferred until proper key management infrastructure exists.

### Assumptions

- MAX17048 fuel gauge IC is present on the PCB and wired to I2C bus (hardware dependency — firmware driver is new work, see Req 2-3)
- Firebase project already set up with core services (Storage and Remote Config are **new dependencies** to add — see below)
- Device firmware version is already parsed from BLE handshake response (`HandshakeResult.firmwareVersion` in `sync_state.dart`) — no new handshake work needed
- App already uses `package_info_plus` for reading app version (for `min_app_version` comparison)
- Version comparison logic (firmware semver + app version gate) belongs in `CheckForUpdate` use case for testability
- If the app is killed mid-OTA transfer and reopened, the device will have timed out (30s) and returned to IDLE — the app simply shows the update banner again (no partial-state recovery needed)

## Out of Scope

- **Firmware downgrade** — only forward updates; rollback is automatic on crash, not user-initiated
- **Beta/staged firmware channels** — all users get the same firmware; no percentage-based rollout
- **Multi-device batch updates** — one device at a time
- **Cryptographic firmware signing** — deferred to future version with proper key management
- **Delta/differential updates** — full binary only (~100KB, so minimal benefit from delta)
- **Background/silent updates** — user must initiate and keep app open during transfer
- **Update scheduling** — no "update tonight" or deferred update mechanism

## Dependencies

### External

- **MAX17048 hardware** — fuel gauge IC must be on the PCB and connected via I2C
- **Dual-OTA partition table** — requires one-time USB flash of new partition layout
- **Firebase Storage** — for hosting firmware binaries (**new Flutter dependency**: `firebase_storage` package must be added to `pubspec.yaml`)
- **Firebase Remote Config** — for `min_firmware_version` server-side control (**new Flutter dependency**: `firebase_remote_config` package must be added to `pubspec.yaml`)

### Internal

- **BLE handshake** — already returns `firmware_version` (parsed in `HandshakeResult` in `sync_state.dart` — no changes needed)
- **Existing BLE service** — OTA commands use existing command/notify characteristics
- **Clean architecture patterns** — new `lib/features/ota/` follows established project structure

## Design Reference

Detailed technical design including BLE protocol changes, state machines, transfer flow, and implementation phases: `docs/plans/2026-03-27-ble-ota-firmware-updates-design.md`
