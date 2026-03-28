---
name: ble-ota-firmware-updates
status: completed
created: 2026-03-28T06:33:51Z
progress: 100%
prd: .claude/prds/ble-ota-firmware-updates.md
github: https://github.com/roger6272/trackwise/issues/35
---

# Epic: BLE OTA Firmware Updates

## Overview

Add over-the-air firmware update capability spanning three layers: ESP32 firmware (OTA state machine, battery reading, new BLE characteristics), Firebase infrastructure (Storage for binaries, Remote Config for min version), and Flutter app (OTA feature with clean architecture, progress UI, update banners). The firmware work is the foundation — app and Firebase layers depend on it.

## Architecture Decisions

1. **OTA Data on separate characteristic, not command channel** — Raw binary chunks go to a dedicated write-with-response characteristic (`...9011`), keeping the existing JSON command channel for `ota_start`/`ota_end`/`reboot` commands and notifications for responses. This avoids mixing binary and JSON on the same pipe.

2. **Standard Battery Service (0x180F)** — Use the Bluetooth SIG standard service rather than a custom characteristic. This means the app discovers two services (custom + battery), but standard services are auto-handled by many BLE tools and debuggers.

3. **New `lib/features/ota/` feature** — Clean architecture with its own data/domain/presentation layers, following existing patterns. OTA BLE writes reuse the existing `DeviceConnection` (adding `otaDataChar` and `batteryLevelChar` fields) rather than creating a parallel connection.

4. **Hand-rolled semver comparison** — No `pub_semver` dependency. Strict `major.minor.patch` integer format means comparison is trivial: split on `.`, compare integers. Keeps dependencies minimal.

5. **OTA Data and Battery Level characteristics are optional** — Unlike existing required characteristics, these don't fail `discoverServices()` if absent. Devices on older firmware (pre-OTA) still connect normally — the app just hides the update UI.

6. **Sync before OTA, not after** — Device count logs are RAM-only (`CountLog` array). A reboot wipes them. Syncing before OTA transfer prevents silent data loss.

## Technical Approach

### Firmware (ESP32)

**Partition table:** Switch from single-app to dual-OTA partition layout. One-time USB flash prerequisite.

**New hardware driver:** MAX17048 fuel gauge over I2C (address `0x36`, SOC register `0x04`). Expose as standard Battery Service (0x180F) with Battery Level characteristic (0x2A19) — read + notify.

**OTA state machine:** IDLE → RECEIVING → VERIFYING → VERIFIED → REBOOTING. Added to existing `.ino` file. 30s inactivity timeout in RECEIVING, 10s auto-reboot in VERIFIED. Pauses normal operation (ignores button, shows "updating" on display).

**New characteristic:** OTA Data (`12345678-1234-1234-1234-123456789011`) on existing custom service — write-with-response for binary chunks. Note: `createService(SERVICE_UUID)` defaults to 15 handles; currently using ~10, OTA Data adds 2 = 12 total (fits).

**Rollback:** `esp_ota_mark_app_valid_cancel_rollback()` at end of `setup()` after BLE, display, and peripherals confirmed working.

### Firebase Infrastructure

**Storage:** `firmware/latest.json` + `firmware/bins/trackwise_X.Y.Z.bin`. Security rules: authenticated read-only, admin upload.

**Remote Config:** `min_firmware_version` parameter. App fetches once per launch, falls back to hardcoded value.

**Publish script:** `publish_firmware.sh` — computes SHA256, generates `latest.json`. Developer tool, lives in repo `scripts/` directory.

### App — Data Layer (`lib/features/ota/`)

```
lib/features/ota/
├── data/
│   ├── datasources/
│   │   ├── ota_remote_datasource.dart      # Firebase Storage + Remote Config
│   │   └── ota_ble_datasource.dart         # BLE OTA writes (uses DeviceConnection)
│   ├── models/
│   │   └── firmware_info_model.dart        # latest.json deserialization
│   └── repositories/
│       └── ota_repository_impl.dart
├── domain/
│   ├── entities/
│   │   ├── firmware_info.dart              # version, sha256, changelog, min_app_version
│   │   └── ota_state.dart                  # OTA progress states
│   ├── repositories/
│   │   └── ota_repository.dart
│   └── usecases/
│       ├── check_for_update.dart           # Version comparison + update check logic
│       └── perform_ota_update.dart         # Download + transfer + verify orchestration
└── presentation/
    ├── bloc/
    │   └── ota_bloc.dart                   # States: Idle, Available, Required, Downloading,
    │                                       #   Transferring, Verifying, Rebooting, Complete, Error
    └── widgets/
        ├── update_banner.dart              # Dismissable / non-dismissable
        └── ota_progress_sheet.dart         # Bottom sheet with progress + cancel
```

**Key integration points:**
- `DeviceConnection` — add `otaDataChar` and `batteryLevelChar` fields
- `discoverServices()` in `bluetooth_datasource_impl.dart` — discover new characteristics (optional, don't fail if absent)
- `BluetoothBloc` auto-reconnect — mark OTA reboot as expected disconnect to suppress error UI
- `AnalyticsService` — add OTA events and firmware version user property
- `BluetoothConstants` — add OTA Data UUID (`...9011`)

**New dependencies (pubspec.yaml):**
- `firebase_storage`
- `firebase_remote_config`

**Existing infrastructure reused:**
- `DeviceConnection.negotiatedMtu` for OTA chunk sizing
- `HandshakeResult.firmwareVersion` for version reading
- `package_info_plus` for app version comparison
- `AnalyticsService` for telemetry
- `firebase_analytics` (already a dependency)

### App — Presentation Layer

**Update banner:** Shown on `BluetoothPage` device card area. Dismissable for optional, non-dismissable for required. Tap opens bottom sheet.

**Progress bottom sheet:** Download progress → transfer progress (sequential). Cancel button with confirmation dialog. "Don't turn off your device" message.

**Battery display:** Replace existing `battery_unknown` / `--%` placeholder in `bluetooth_page.dart:714` with live battery level from Battery Level characteristic.

**Post-reboot:** Set `awaitingOtaReboot` flag → suppress disconnect error → auto-reconnect (30s timeout) → full handshake → verify `firmwareVersion` → success message.

## Task Breakdown Preview

- [ ] Task 1: Firmware — dual-OTA partition table + MAX17048 battery + Battery Service (Reqs 1-3)
- [ ] Task 2: Firmware — OTA Data characteristic + commands + state machine + rollback (Reqs 4-10)
- [ ] Task 3: Firebase — Storage structure, Remote Config, security rules, publish script (Reqs 11-15)
- [ ] Task 4: App — BLE integration: discover new characteristics (battery + OTA Data), battery display, DeviceConnection changes (Reqs 16, 21-22, US-5). Both battery and OTA Data modify `discoverServices()` and `DeviceConnection` — grouped to avoid merge conflicts.
- [ ] Task 5: App — OTA data layer: Firebase datasource, version comparison, update check, download, BLE transfer logic (Reqs 17-18, 20, 23, 28). Sync-before-OTA (Req 17) is orchestration in `PerformOtaUpdate` use case — calls existing sync infrastructure, waits for completion, then proceeds.
- [ ] Task 6: App — OTA presentation: bloc, update banner, progress sheet, post-reboot handling, app version gate, offline handling (Reqs 19, 24-27, US-1/2/3/4)
- [ ] Task 7: App — Analytics: OTA telemetry events + firmware version user property (Reqs 29-30)
- [ ] Task 8: Testing — unit tests only: version comparison edge cases, OtaBloc state transitions, CheckForUpdate use case (newer/forced/up-to-date/offline). Integration tests (rollback, timeout, hash mismatch) require physical hardware — tracked separately.
- [ ] Task 9: Documentation — update BLE_PROTOCOL.md, DATA_FLOW.md, USER_GUIDE.md, TROUBLESHOOTING.md

## Dependencies

### Blocking (must complete first)
- **Task 1 before Task 2** — partition table + battery must exist before OTA state machine
- **Task 1 before Task 4** — Battery Service must exist on firmware before app can discover it
- **Task 2 before Task 5** — firmware OTA must work before app BLE transfer can be tested
- **Task 3 before Task 5** — Firebase must be set up before app can download firmware binaries
- **Task 5 before Task 6** — data layer (use cases, repo) must exist before presentation layer (bloc, UI)

### Parallel opportunities
- **Tasks 1+3** — firmware partition/battery and Firebase setup are independent
- **Task 4** — BLE integration (discovery + battery UI) can start after Task 1, independent of OTA
- **Task 5 (partial)** — Firebase datasource + version comparison can start after Task 3, before Task 2 finishes (BLE transfer logic waits for Task 2)
- **Task 7** — analytics can be added at any point after Task 6
- **Tasks 8+9** — testing and docs can run in parallel after Tasks 5+6

### External
- MAX17048 IC must be on PCB and wired to I2C
- Firebase project access for Storage + Remote Config setup

## Success Criteria (Technical)

| Criteria | Validation |
|----------|-----------|
| OTA transfer completes end-to-end | Upload test binary, transfer via BLE, verify device reboots to new version |
| Rollback works | Upload deliberately broken firmware, confirm device reverts to previous |
| Battery gate enforced | Set SOC < 20%, confirm `ota_start` returns `low_battery` error |
| Hash mismatch rejected | Send binary with wrong SHA256, confirm `ota_end` returns `hash_mismatch` |
| Forced update shown | Set `min_firmware_version` above device version, confirm non-dismissable banner |
| Timeout recovery | Kill app mid-transfer, confirm device returns to IDLE after 30s |
| No data loss | Accumulate unsent logs, start OTA, confirm logs synced before transfer |
| Battery level displayed | Confirm live % replaces placeholder on connected device card |
| Version comparison correct | Unit tests pass for edge cases: `1.9.0` vs `1.10.0`, `2.0.0` vs `1.99.99` |

## Estimated Effort

**Total: ~5-6 working days** (tight for 1-week target but achievable)

| Task | Estimate | Notes |
|------|----------|-------|
| Task 1: Firmware partition + battery | 0.5 day | Partition table change + MAX17048 I2C driver + Battery Service |
| Task 2: Firmware OTA state machine | 1 day | Most complex firmware work — state machine, SHA256, timeouts |
| Task 3: Firebase setup | 0.5 day | Storage + Remote Config + security rules + publish script |
| Task 4: App BLE integration + battery UI | 0.5 day | `discoverServices` extension, `DeviceConnection` fields, battery display |
| Task 5: App OTA data layer | 1 day | Firebase datasource, BLE datasource, repo, use cases, version comparison |
| Task 6: App OTA presentation | 1 day | Bloc, banner, progress sheet, post-reboot, app version gate |
| Task 7: App analytics | 0.25 day | Add events to existing AnalyticsService |
| Task 8: Unit tests | 0.5 day | Version comparison, bloc states, use case |
| Task 9: Documentation | 0.25 day | Protocol, data flow, user guide, troubleshooting |

**Critical path:** Task 1 → Task 2 → Task 5 → Task 6 (3.5 days serial minimum)
**Parallel fast track:** Task 3 starts with Task 1; Task 4 starts after Task 1; Task 5 (Firebase parts) starts after Task 3

## Tasks Created
- [ ] #36 - Firmware: Dual-OTA Partition Table + MAX17048 Battery + Battery Service (parallel: true)
- [ ] #37 - Firmware: OTA Data Characteristic + Commands + State Machine + Rollback (parallel: false)
- [ ] #41 - Firebase: Storage Structure, Remote Config, Security Rules, Publish Script (parallel: true)
- [ ] #38 - App: BLE Integration — Discover New Characteristics + Battery Display (parallel: true)
- [ ] #43 - App: OTA Data Layer — Firebase Datasource, Version Comparison, BLE Transfer (parallel: false)
- [ ] #44 - App: OTA Presentation — Bloc, Update Banner, Progress Sheet, Post-Reboot (parallel: false)
- [ ] #39 - App: Analytics — OTA Telemetry Events + Firmware Version User Property (parallel: true)
- [ ] #40 - Testing: Unit Tests — Version Comparison, OtaBloc States, CheckForUpdate (parallel: true)
- [ ] #42 - Documentation: Update BLE Protocol, Data Flow, User Guide, Troubleshooting (parallel: true)

Total tasks: 9
Parallel tasks: 6
Sequential tasks: 3
Estimated total effort: 44 hours (~5.5 working days)
