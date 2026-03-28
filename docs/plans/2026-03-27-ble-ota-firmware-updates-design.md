# BLE OTA Firmware Updates — Design Document

> **Date:** 2026-03-27
> **Status:** Draft
> **Scope:** Firmware, App, Firebase Infrastructure

## 1. Overview

Over-the-air firmware updates for the Traxelos One ESP32 device, delivered over BLE from the Flutter app. Required for a commercial product — users cannot be expected to USB-flash firmware.

### Design Goals

- Users can update device firmware from the app in under 30 seconds
- Failed updates never brick the device (dual-partition rollback)
- Critical updates can be forced server-side via Firebase Remote Config
- Battery check prevents updates on low charge

### Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Hosting | Firebase Storage | Already in ecosystem |
| Download | On demand | 100KB binary is near-instant to download |
| Update discovery | Banner on device detail page | Noticeable, non-intrusive |
| Forced updates | Yes, via Remote Config | Protocol-breaking changes happen (v2→v3) |
| Min version source | Remote Config + hardcoded fallback | Server-side control without single point of failure |
| Signing | SHA256 integrity only in v1 | App-level signing added later with proper key management |
| Transfer protocol | Write-with-response + SHA256 final check | BLE stack handles delivery, SHA256 handles integrity |
| Battery check | MAX17048 ≥ 20% required | Prevent bad UX from mid-update power loss |
| During OTA | Pause normal device operation | Avoid flash contention and lost counts |
| Firmware timeouts | 30s inactivity → abort, 10s post-verify → auto-reboot | Clean up interrupted sessions |
| Rollback | Automatic via ESP-IDF bootloader | Crash on first boot → revert to previous firmware |
| Version format | Strict semver: major.minor.patch (integers only) | No pre-release tags, keeps comparison trivial |

---

## 2. Architecture

```
┌─────────────┐        ┌─────────────┐        ┌─────────────┐
│  Firebase    │        │  Flutter    │  BLE   │   ESP32     │
│             │        │  App        │        │   Device    │
│ - Storage   │  HTTP  │             │ chunks │             │
│   (.bin)    │◄──────►│ - Download  │───────►│ - OTA write │
│ - Remote    │        │ - Transfer  │        │ - Verify    │
│   Config    │        │ - UI/UX     │        │ - Reboot    │
│   (minVer)  │        │             │        │             │
└─────────────┘        └─────────────┘        └─────────────┘
```

**Firebase layer:**
- **Storage** hosts versioned firmware binaries
- **Metadata file** (`latest.json`) stores the latest version, SHA256 hash, and changelog
- **Remote Config** holds `min_firmware_version` — updatable server-side without an app release

**App layer:**
- On device connect, reads firmware version from handshake (already returned in handshake responses)
- Compares against Remote Config `min_firmware_version` and latest available version
- Downloads `.bin` on demand, transfers over BLE, shows progress

**Firmware layer:**
- New BLE characteristic for receiving binary chunks
- Uses ESP-IDF `esp_ota_ops.h` to write to the standby partition
- Verifies SHA256 before switching partitions and rebooting
- Automatic rollback if new firmware crashes on first boot

---

## 3. BLE OTA Transfer Protocol

### 3.1 BLE Interface Changes

```
Existing Service: "12345678-1234-1234-1234-123456789000"
├── (existing) Command char  — add ota_start, ota_end, reboot commands
├── (existing) Notify char   — OTA responses come here
└── (new) OTA Data (write-with-response): "12345678-1234-1234-1234-123456789011"
    App → Device: raw firmware bytes

Standard Battery Service: 0x180F
└── Battery Level (read/notify): 0x2A19
    Device → App: battery percentage 0-100 (from MAX17048 fuel gauge)
```

### 3.2 New Commands

**`ota_start`** — Begin OTA session

```json
{"cmd": "ota_start", "size": 102400, "sha256": "ab3f9c...", "version": "2.1.0"}
```

Device checks: battery ≥ 20%, not already in OTA, version is newer than current. Prepares OTA partition.

Success response:
```json
{"status": "ota_ready"}
```

Error responses:
```json
{"status": "error", "cmd": "ota_start", "reason": "low_battery", "battery": 15}
{"status": "error", "cmd": "ota_start", "reason": "already_in_progress"}
{"status": "error", "cmd": "ota_start", "reason": "invalid_version"}
```

**`ota_end`** — Finalize and verify

```json
{"cmd": "ota_end"}
```

Device computes final SHA256, compares against the hash provided in `ota_start`.

```json
{"status": "ota_verified"}
{"status": "error", "cmd": "ota_end", "reason": "hash_mismatch"}
```

**`reboot`** — Switch partition and restart

```json
{"cmd": "reboot"}
```

Only accepted when OTA state machine is in `VERIFIED` state. Ignored otherwise. Device sets boot partition to new firmware and calls `esp_restart()`.

### 3.3 Transfer Flow

```
App                                    ESP32
 │                                       │
 │── [Command] {"cmd":"ota_start",  ───►│
 │    "size":102400, "sha256":"ab3f..",  │
 │    "version":"2.1.0"}                 │
 │                                       │  Checks: battery ≥ 20%,
 │                                       │  not busy, version newer
 │◄── [Notify] {"status":"ota_ready"} ─│
 │                                       │
 │── [OTA Data] <chunk 1, ~MTU bytes> ─►│  write-with-response
 │── [OTA Data] <chunk 2> ────────────►│  app tracks progress
 │── ...  (~200 chunks for 100KB)        │  locally (chunks sent
 │── [OTA Data] <final chunk> ─────────►│  / total chunks)
 │                                       │
 │── [Command] {"cmd":"ota_end"} ──────►│  Verify SHA256
 │◄── [Notify] {"status":"ota_verified"}│
 │                                       │
 │── [Command] {"cmd":"reboot"} ───────►│  Switch partition, reboot
 │                                       │
```

### 3.4 Chunk Size

Dynamic based on negotiated BLE MTU: `chunk_size = negotiated_MTU - 3`. App negotiates max MTU on connect. If negotiation fails (default MTU = 23), chunk size is 20 bytes — slower but still works.

### 3.5 Firmware OTA State Machine

```
         ota_start (valid)
IDLE ──────────────────────► RECEIVING
  ▲                            │    │
  │  timeout (30s no data)     │    │ raw bytes on OTA Data char
  │◄───────────────────────────┘    └──────► (write to partition)
  │
  │  timeout (30s no data)         ota_end
  │◄──────────────────────── RECEIVING ────► VERIFYING
                                               │    │
                             hash mismatch     │    │ hash ok
                     IDLE ◄────────────────────┘    │
                       ▲                            ▼
                       │  timeout (10s)         VERIFIED
                       │◄───────────────────────   │
                                                   │ reboot cmd
                                                   ▼
                                               REBOOTING
                                            (switch partition,
                                             esp_restart())
```

- **30-second inactivity timeout** in RECEIVING → abort, clean up partial write, return to IDLE
- **10-second timeout** in VERIFIED → auto-reboot (handles app crash after verification)
- Device **pauses normal operation** during OTA: ignores button presses, shows "updating" on display
- SHA256 computed **incrementally** using `mbedtls_sha256` as chunks arrive (no RAM buffering)
- Each chunk written directly to flash via `esp_ota_write()` — minimal RAM overhead

### 3.6 Rollback Protection

`esp_ota_mark_app_valid_cancel_rollback()` is called at the **end of `setup()`**, after BLE, display, and peripherals are confirmed working. If the new firmware crashes before reaching that point, the bootloader automatically rolls back to the previous partition on next power-up.

---

## 4. Firebase Infrastructure

### 4.1 Storage Structure

```
firmware/
├── latest.json
└── bins/
    └── trackwise_2.1.0.bin
```

### 4.2 Metadata File (`latest.json`)

```json
{
  "version": "2.1.0",
  "file_path": "firmware/bins/trackwise_2.1.0.bin",
  "sha256": "ab3f9c...full_sha256_hash",
  "min_app_version": "3.0.0",
  "changelog": "Improved battery life, fixed counting bug",
  "released_at": "2026-04-15T00:00:00Z"
}
```

- `min_app_version`: prevents old app versions from attempting firmware they can't handle. If app version < `min_app_version`, don't show firmware update — show "Update the Traxelos app" instead.

### 4.3 Remote Config

```
min_firmware_version: "2.0.0"
```

Updated server-side when needed (e.g., after a protocol-breaking change). App falls back to a hardcoded value when Remote Config is unreachable.

### 4.4 Security Rules

- Firmware files: **read-only for authenticated users**, admin-only upload
- No public access

### 4.5 Publishing Workflow

Use the publish script to avoid manual SHA256 copy-paste errors:

```bash
#!/bin/bash
# publish_firmware.sh
VERSION=$1
FILE="trackwise_${VERSION}.bin"
HASH=$(sha256sum "$FILE" | cut -d' ' -f1)
cat > latest.json <<EOF
{
  "version": "$VERSION",
  "file_path": "firmware/bins/$FILE",
  "sha256": "$HASH",
  "min_app_version": "TODO",
  "changelog": "TODO",
  "released_at": "$(date -Iseconds)"
}
EOF
echo "Generated latest.json for $VERSION (sha256: $HASH)"
echo "Next steps:"
echo "  1. Edit latest.json — fill in changelog and min_app_version"
echo "  2. Upload $FILE to Firebase Storage: firmware/bins/"
echo "  3. Upload latest.json to Firebase Storage: firmware/"
echo "  4. Optionally update Remote Config min_firmware_version"
```

---

## 5. App Architecture

### 5.1 Update Check Flow

```
Device connects (handshake returns firmware_version)
    │
    ├── Read battery level from Battery Service (0x180F)
    ├── Read cached Remote Config → min_firmware_version
    │   (fetched once per app launch, hardcoded fallback if offline)
    └── Fetch latest.json from Firebase Storage
            │
            ├── App version < min_app_version (from latest.json)
            │       → "Update the Traxelos app" message (no firmware banner)
            │         (stop here — app may not support the new firmware)
            │
            ├── Device version < min_firmware_version
            │       → Non-dismissable banner: "Update required"
            │
            ├── Device version < latest version
            │       → Dismissable banner: "Update available"
            │
            └── Device is up to date
                    → No banner
```

### 5.2 Feature Structure

```
lib/features/ota/
├── data/
│   ├── datasources/     Firebase Storage, Remote Config, BLE OTA writes
│   └── repositories/
├── domain/
│   ├── entities/         FirmwareVersion, UpdateInfo
│   └── usecases/         CheckForUpdate, PerformOtaUpdate
└── presentation/
    ├── bloc/             OtaBloc
    └── widgets/          Update banner, progress bottom sheet
```

### 5.3 OtaBloc States

```
OtaIdle                              → No update, or not checked yet
OtaUpdateAvailable(version, changelog) → Dismissable banner
OtaUpdateRequired(version, changelog)  → Non-dismissable banner
OtaDownloading(progress)             → Downloading .bin from Firebase
OtaTransferring(progress)            → Sending chunks over BLE
OtaVerifying                         → Waiting for SHA256 confirmation
OtaRebooting                         → Device restarting, awaiting reconnect
OtaComplete(newVersion)              → Success, verified new version
OtaError(reason)                     → Error with actionable message
```

### 5.4 OtaBloc Events

```
CheckForUpdate(deviceFirmwareVersion)
StartOtaUpdate
AbortOtaUpdate
OtaRebootComplete(newFirmwareVersion)
```

### 5.5 UI Components

**Update banner** (on device detail page):
- Dismissable for optional updates, non-dismissable for required updates
- Tap opens bottom sheet with changelog, version info, and "Update Now" button

**Progress bottom sheet:**
- Shows download progress → transfer progress sequentially
- "Don't turn off your device" message during transfer
- Cancel button with confirmation dialog ("Cancelling won't damage your device. You can retry later.")

**Post-reboot:**
- App sets `awaitingOtaReboot` flag before sending reboot command
- Connection logic auto-reconnects silently (no disconnect error shown)
- 30-second reconnect timeout — if device doesn't reconnect, show `OtaError("Device didn't respond after update. Try turning it off and on again.")`
- On reconnect: full handshake, reads firmware version to confirm update succeeded
- Shows "Updated to v2.1.0" success message

**Offline handling:**
- If user taps "Update Now" without internet: `OtaError` with "Connect to the internet to download the update"

---

## 6. Implementation Plan

### Prerequisites (before any OTA code)

1. **Switch to dual-OTA partition table** — one-time USB flash. Every device shipped must have this from the factory. Devices on the old single-partition table can never receive OTA.
2. **Add MAX17048 I2C library** — for battery SOC% reading.

### Phase 1: Firmware Foundation

- Switch partition table to dual-OTA
- Add MAX17048 battery reading over I2C (address `0x36`, SOC register `0x04`)
- Add BLE Battery Service (0x180F) with Battery Level characteristic (0x2A19)
- Add OTA Data characteristic to existing service (write-with-response)
- Add `ota_start`, `ota_end`, `reboot` command handlers
- OTA state machine with 30s inactivity and 10s post-verify timeouts
- Pause normal operation during OTA (ignore button, show "updating" on display)
- `esp_ota_mark_app_valid_cancel_rollback()` at end of `setup()`

### Phase 2: Firebase Infrastructure

- Create Storage bucket structure (`firmware/bins/`, `latest.json`)
- Write `publish_firmware.sh` script
- Set up Security Rules (authenticated read-only)
- Add Remote Config: `min_firmware_version`
- Upload first OTA-capable firmware binary as baseline

### Phase 3: App — Data Layer

- Create `lib/features/ota/` with clean architecture structure
- OTA datasource: fetch `latest.json`, download `.bin`, read Remote Config
- BLE OTA datasource: write to OTA Data characteristic, send OTA commands (uses existing device connection)
- Repository + use cases: `CheckForUpdate`, `PerformOtaUpdate`
- Version comparison logic (strict `major.minor.patch` integers)

### Phase 4: App — Presentation Layer

- `OtaBloc` with full state machine
- Update banner widget (dismissable / non-dismissable)
- Update bottom sheet (changelog, version info, "Update Now")
- Progress UI with cancel + confirmation dialog
- Post-reboot: auto-reconnect, version verification, success message
- "Update your app" message when `min_app_version` > current app version
- Offline download error handling

### Phase 5: Testing

**Unit tests (app, run in CI):**
- Version comparison logic (semver edge cases)
- `OtaBloc` state transitions
- `CheckForUpdate` use case (newer available, forced required, up to date, offline fallback)

**Integration tests (require physical device):**
- OTA with known-good `.bin` over BLE
- Timeout recovery (kill app mid-transfer, verify device returns to IDLE)
- Hash mismatch rejection
- Rollback on crash (upload a deliberately broken firmware, verify rollback)
- Low battery rejection
- Forced update flow (`min_firmware_version` enforcement)
- Optional update flow (dismiss and re-show)
- Cancel mid-transfer and retry
- Remote Config fallback when offline

### Phase 6: Documentation

- Update `docs/BLE_PROTOCOL.md`: new commands (`ota_start`, `ota_end`, `reboot`), new characteristic (OTA Data), Battery Service
- Update `docs/DATA_FLOW.md`: OTA update flow diagram
- Update `docs/USER_GUIDE.md`: how to update firmware
- Update `docs/TROUBLESHOOTING.md`: OTA failure scenarios and recovery
- Create ADR if any non-obvious decisions arise during implementation
