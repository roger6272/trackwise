# OTA Test Plan

**Goal:** Verify the device's OTA reboot UX — specifically that the app keeps showing "Rebooting…" through the BLE disconnect and transitions to "Update Complete" only after the device reconnects with the new firmware version.

**Date:** 2026-05-15
**Related fix:** N/A — this is a behavior verification, not a bug-fix test.

---

## What you're testing

| Stage | Expected app UI |
|---|---|
| Downloading firmware from Firebase | "Downloading…" with progress bar |
| Transferring chunks over BLE | "Transferring to device…" with progress |
| Device verifying SHA256 | "Verifying…" |
| Device sent `ota_rebooting` notification | "Rebooting…" |
| **Device disconnects (~500 ms after `ota_rebooting`)** | **Still "Rebooting…" — must NOT flip to "Update Failed"** |
| Device reconnects, handshake reports new `firmware_version` | "Update Complete" with new version shown |

The carve-out being verified is `lib/features/ota/presentation/bloc/ota_bloc.dart:397` (`transfer is! OtaTransferRebooting` skips the disconnect→error transition).

---

## Prerequisites

- [ ] Arduino IDE (or PlatformIO) with ESP32 board support installed
- [ ] USB cable for flashing the device
- [ ] Firebase Console access for the Trackwise project (Storage + Remote Config)
- [ ] One Traxelos device available for testing
- [ ] Phone with the Trackwise app installed and signed in
- [ ] Bash shell available (Git Bash on Windows is fine — `publish_firmware.sh` requires bash)

---

## Phase 1 — Prepare the device with an older firmware

The test device must be running a firmware version **strictly lower** than the version you'll publish. Current code at `firmware/Trackwise_ESP32/Trackwise_ESP32.ino:81` is `2.1.0`. A pre-built `trackwise_2.1.1.bin` already exists at `firmware/Trackwise_ESP32/build/esp32.esp32.esp32/`, so you'll publish 2.1.1 and the device must be on ≤ 2.1.0.

### 1.1 Confirm current device firmware version

> **Note:** The app UI does NOT display the device's current firmware version anywhere. Use the serial monitor instead. Firmware logs `🔖 FIRMWARE_VERSION: X.Y.Z` on every boot (added in `setup()`).

- [ ] Connect the device to your PC via USB.
- [ ] Open Arduino IDE → **Tools → Serial Monitor**, set baud rate to **115200**.
- [ ] Press the reset button on the device (or unplug/replug USB).
- [ ] Look for the line: `🔖 FIRMWARE_VERSION: 2.1.0` (or whatever version is on the device).
- [ ] Note the version: ______________

Alternative for already-paired devices without USB access: trigger a test OTA attempt with a deliberately *lower* version. The firmware will reject it and log `❌ OTA rejected: version <X> is not newer than <FIRMWARE_VERSION>` — which reveals the current version. Clunky; serial is preferred.

### 1.2 If the device is already on 2.1.1 or newer

You need to flash it down to an older version first:

- [ ] In `firmware/Trackwise_ESP32/Trackwise_ESP32.ino`, temporarily change `#define FIRMWARE_VERSION "2.1.0"` (line 81) to `"2.0.9"`.
- [ ] In the Arduino IDE, select **Tools → Board → ESP32 Dev Module** (or your specific ESP32 variant).
- [ ] Connect the device via USB, select the correct COM port.
- [ ] Sketch → Upload. Wait for "Done uploading".
- [ ] Serial Monitor (115200 baud) → power-cycle the device → boot log should now show `🔖 FIRMWARE_VERSION: 2.0.9`.
- [ ] **Revert** the `FIRMWARE_VERSION` line back to `"2.1.0"` in the source — do **not** commit this temporary change. (You don't need to rebuild after reverting; the build for upload was already done.)

### 1.3 Re-confirm on the device

- [ ] With Serial Monitor still open, press reset once more.
- [ ] Confirm the boot banner reads `🔖 FIRMWARE_VERSION: 2.0.9` (or whichever older version you flashed).
- [ ] Then disconnect USB and reconnect the device in the app.

---

## Phase 2 — Generate the OTA manifest

### 2.1 Locate the binary

The pre-built binary at `firmware/Trackwise_ESP32/build/esp32.esp32.esp32/trackwise_2.1.1.bin` works if you're testing 2.1.1. If you need a different target version, build it first (Arduino IDE → Sketch → Export Compiled Binary).

- [ ] Confirm the .bin exists: `ls firmware/Trackwise_ESP32/build/esp32.esp32.esp32/trackwise_*.bin`
- [ ] Note the path: ______________

### 2.2 Run the publish script for the **beta** channel

Using `--channel beta` so you don't ship a test build to release users.

```bash
./scripts/publish_firmware.sh \
  firmware/Trackwise_ESP32/build/esp32.esp32.esp32/trackwise_2.1.1.bin \
  2.1.1 \
  --channel beta \
  --changelog "OTA reboot UI verification test"
```

- [ ] Script ran without errors.
- [ ] Script printed an upload destination like:
  - `firmware/beta/bins/trackwise_2.1.1.bin` (the binary)
  - `firmware/beta/latest.json` (the metadata)
- [ ] A `latest.json` was written next to the .bin.

---

## Phase 3 — Upload to Firebase Storage

### 3.1 Via Firebase Console

- [ ] Open https://console.firebase.google.com/ → Trackwise project → Storage.
- [ ] Navigate to `firmware/beta/bins/` (create the folders if they don't exist).
- [ ] Upload `trackwise_2.1.1.bin`. Confirm filename matches exactly.
- [ ] Navigate up to `firmware/beta/`.
- [ ] Upload `latest.json` (the one the publish script generated, next to the .bin).
- [ ] Verify both files now appear in the Console.

### 3.2 Sanity check the metadata

Open `latest.json` in the Console and confirm:
- [ ] `version`: `"2.1.1"`
- [ ] `file_path`: `"firmware/beta/bins/trackwise_2.1.1.bin"`
- [ ] `sha256`: 64 hex characters
- [ ] `channel`: `"beta"`

---

## Phase 4 — Switch the app to the beta channel

The app picks its channel at **build time** via `--dart-define=OTA_CHANNEL=beta` (see `lib/features/ota/data/datasources/ota_remote_datasource_impl.dart:25`). The release build defaults to `release`.

### 4.1 Build the app with beta channel

- [ ] Stop any running instance of the app.
- [ ] From the project root:
  ```bash
  flutter run --dart-define=OTA_CHANNEL=beta
  ```
  Or for release build to your device:
  ```bash
  flutter build apk --release --dart-define=OTA_CHANNEL=beta
  # install the produced APK to the test phone
  ```
- [ ] App launches. Sign in if not already.

### 4.2 Confirm the app reads from the beta channel

- [ ] In the app's debug log (or via `adb logcat` filtering for `OtaRemoteDataSourceImpl`), look for: `Fetching firmware info (channel: beta)`.
- [ ] If you see `(channel: release)`, the `--dart-define` didn't take. Rebuild.

---

## Phase 5 — Trigger and observe the OTA flow

### 5.1 Connect

- [ ] Connect the test device in the app.
- [ ] Wait for handshake to complete and device to show as connected (green icon).

### 5.2 Trigger the update

The app should detect the newer firmware automatically and surface an update banner/dialog.

- [ ] Update banner appears showing "Update available" with version 2.1.1.
- [ ] Tap **Update Now** (or equivalent action).
- [ ] The OTA progress sheet appears.

### 5.3 Observe each stage — **this is the actual test**

Watch the sheet carefully. Note each transition.

- [ ] **"Downloading…"** with progress bar (0% → 100%). Time: ~2–10s depending on connection.
- [ ] **"Transferring to device…"** with progress bar (0% → 100%). Time: ~30–90s depending on MTU and chunk size.
- [ ] **"Verifying…"** (no progress bar, just a spinner). Time: ~1–3s.
- [ ] **"Rebooting…"** appears.
- [ ] **Phone disconnects from device (BLE icon may go red/grey in another part of UI).**
  - [ ] ⚠️ **CRITICAL CHECK:** The OTA progress sheet should STILL show "Rebooting…" through this disconnect. It must NOT flash "Update Failed" / "Device disconnected during update."
- [ ] After ~3–10 seconds, the device reboots into the new firmware and the app auto-reconnects.
- [ ] **"Update Complete"** appears, showing the new version (2.1.1).

### 5.4 Verify the device

- [ ] After the sheet shows "Update Complete", dismiss it.
- [ ] Paired Devices → device firmware version reads `2.1.1`.
- [ ] All items, counts, and selection from before the update are preserved (paired_uid and NVS survive across OTA).
- [ ] Press a button on the device, confirm count increments and syncs to the app.

✅ If all the above pass, the primary behavior is verified.

---

## Phase 6 (optional) — Verify the failure-path UI

This confirms the 60s timeout error correctly fires when the device doesn't come back.

- [ ] Trigger another OTA. (You'll need a higher version; either temporarily flash an even older firmware, or bump the published version.)
- [ ] When the sheet hits **"Rebooting…"**, **immediately hold the device's power button to keep it from completing the reboot** (or pull the battery if accessible).
- [ ] Watch the sheet for 60 seconds.
- [ ] **Expected:** Around the 60s mark, the sheet transitions to **"Update failed: Device didn't respond after update. Try turning it off and on again."**
- [ ] Release the power button / reinsert battery. Device boots normally (into the new firmware, since `esp_ota_set_boot_partition` ran before the reboot).
- [ ] Reconnect in the app. Confirm firmware is now on the new version anyway (the partition switch already happened — the timeout was just a UI signal).

---

## Phase 7 — Cleanup

- [ ] **Delete the test `latest.json` from Firebase Storage** (`firmware/beta/latest.json`) if you don't want the next user testing beta to get this build, OR replace it with a manifest pointing to whatever is "real" beta.
- [ ] (Optional) Delete `firmware/beta/bins/trackwise_2.1.1.bin` if it shouldn't remain available.
- [ ] In `firmware/Trackwise_ESP32/Trackwise_ESP32.ino`, confirm `FIRMWARE_VERSION` is back to `"2.1.0"` (or whatever it should be on master). Run `git diff firmware/` to check.
- [ ] Delete this plan file once tests are done, OR keep it as a runbook for future OTA testing — your call.

---

## Failure modes & what they mean

| Symptom | Likely cause | Investigation |
|---|---|---|
| Update banner never appears | App is on release channel, or device is already on latest, or `latest.json` not uploaded | Check `_channel` log line; check Firebase Console paths exactly |
| "Update failed: invalid_version" | Published version ≤ device's current version | Phase 1.2 — flash an older version first |
| "Update failed: hash_mismatch" | The .bin uploaded doesn't match the SHA256 in `latest.json` | Re-run `publish_firmware.sh` against the exact same .bin you uploaded |
| "Update failed: low_battery" | Device battery < 20% | Charge the device above 20%, retry |
| "Rebooting…" flashes to "Update Failed" briefly, then to "Update Complete" | **Bug** — the carve-out at `ota_bloc.dart:397` isn't working as expected | File a bug. Capture timestamps and `adb logcat` output. |
| "Rebooting…" stays for 60s then transitions to error | Device didn't come back. Possible rollback (new firmware failed to boot), or device hardware issue | Check device serial output via USB; check whether device is on old or new firmware on next connect |
| App reconnects but reports old version | Bootloader rolled back. The new firmware may have crashed on boot | Inspect device serial output during boot; check `esp_ota_mark_app_valid_cancel_rollback` is being called somewhere in the new firmware |

---

## What this test plan does NOT cover

- Multi-device OTA (multiple devices connected simultaneously during an update)
- OTA while the device is on battery vs. charging (timing differences)
- OTA on iOS specifically (BLE behavior under iOS background restrictions differs from Android)
- Cellular vs. Wi-Fi for the Firebase download phase
- Resuming an OTA after app force-close mid-transfer

If any of these are relevant to what you're shipping, add them as follow-up phases.
