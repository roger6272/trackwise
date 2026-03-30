# OTA Testing Checklist

## Prerequisites
- [ ] Flash device with dual-OTA partition table via USB (`partitions_ota.csv`)
- [ ] MAX17048 fuel gauge wired to I2C (SDA/SCL)
- [ ] Firebase Storage: upload a test `latest.json` + binary to `firmware/` path
- [ ] Firebase Remote Config: set `min_firmware_version` parameter
- [ ] Build and install debug APK: `flutter build apk --debug`

## Must Test (blocks merge)

### 1. OTA End-to-End Transfer
- [ ] Connect to device, confirm handshake reports version 2.1.0
- [ ] Upload a valid test binary (e.g., same firmware) to Firebase Storage
- [ ] Set `latest.json` version to 2.1.1 (higher than device)
- [ ] Reconnect — update banner appears (optional, dismissable)
- [ ] Tap banner — bottom sheet opens with changelog and "Update Now"
- [ ] Tap "Update Now" — download progress shows, then transfer progress
- [ ] Transfer completes — "Don't turn off your device" message visible during transfer
- [ ] Device reboots automatically
- [ ] App reconnects within 30s — success message shown (NOT timeout error)
- [ ] Device card shows new firmware version

### 2. Battery Display
- [ ] Connect to device with MAX17048 present
- [ ] Battery percentage appears on device card (not `--% ` or `battery_unknown`)
- [ ] Battery icon matches level (full >75%, half 25-75%, low 10-25%, critical <10%)
- [ ] Battery updates while connected (change charge state and observe)

### 3. Post-Reboot Flow
- [ ] During OTA reboot, no "Device disconnected" error appears
- [ ] App auto-reconnects (not manual reconnect needed)
- [ ] After reconnect, handshake runs and new version is confirmed
- [ ] OTA bloc shows Complete state with correct new version

## Should Test (high risk)

### 4. Rollback Protection
- [ ] Upload a deliberately broken binary (e.g., random bytes, correct size)
- [ ] Complete OTA transfer — device reboots
- [ ] Broken firmware fails to boot → device automatically rolls back
- [ ] Device comes back online with previous working firmware
- [ ] App reconnects and reports original version

### 5. Battery Gate (< 20%)
- [ ] Drain or simulate battery below 20%
- [ ] Attempt OTA — app should show "Battery too low" error
- [ ] Firmware rejects `ota_start` with `low_battery` reason
- [ ] No transfer begins

### 6. Hash Mismatch
- [ ] Modify the binary after upload (or set wrong SHA256 in `latest.json`)
- [ ] Attempt OTA transfer
- [ ] Transfer completes but `ota_end` returns `hash_mismatch`
- [ ] Device stays on current firmware (does not reboot to bad image)
- [ ] App shows verification error

### 7. Cancel Mid-Transfer
- [ ] Start OTA transfer
- [ ] Tap Cancel during transfer progress
- [ ] Confirmation dialog appears
- [ ] Confirm cancel — transfer stops
- [ ] Device returns to IDLE (30s timeout or immediate)
- [ ] Device continues normal operation (counting, BLE commands work)
- [ ] Update banner reappears — can retry

### 8. Timeout Recovery
- [ ] Start OTA transfer
- [ ] Kill the app mid-transfer (force close)
- [ ] Wait 30s — device should return to IDLE
- [ ] Reopen app, reconnect — device works normally
- [ ] Update banner appears again — can retry

## Can Skip For Now

### 9. Forced Update Banner
- [ ] Set Remote Config `min_firmware_version` above device version
- [ ] Connect — non-dismissable banner appears
- [ ] Banner persists, no X button
- [ ] Device still functions normally until user starts update

### 10. App Version Gate
- [ ] Set `min_app_version` in `latest.json` higher than current app version
- [ ] Connect — "Update the Traxelos app" message instead of OTA banner

### 11. Offline Handling
- [ ] Disable internet on phone
- [ ] Tap "Update Now" — error about no internet connection

### 12. Analytics (verify in Firebase console)
- [ ] `ota_started` event logged
- [ ] `ota_completed` event with duration
- [ ] `firmware_version` user property set on connect

## Notes
- If test 1 fails on post-reboot (shows timeout error instead of success), check that `_awaitingOtaReboot` flag is being set and cleared correctly
- If transfer fails silently (no error shown, just waits), check the notification key — firmware should use `"status"` not `"type"`
- If app can't download binary, check `latest.json` `file_path` is the full Storage path (e.g., `firmware/bins/trackwise_2.1.1.bin`)
