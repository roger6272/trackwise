# Bluetooth Page Merge Design

## Goal

Merge `bluetooth_page.dart` (single-device status dashboard) and `paired_devices_page.dart` (device list with management actions) into a single unified Bluetooth page. Eliminates the navigation hop between two pages that now serve overlapping purposes in multi-device mode.

## Layout (top to bottom)

### 1. AppBar
- Title: "Bluetooth"
- No back button (tab destination)

### 2. Permission / Bluetooth banners
- Only shown when there's an issue
- Bluetooth disabled: red banner with "Enable Bluetooth" action
- Permissions not granted: amber banner with "Grant" action
- Same style as `ble_status_banner.dart`

### 3. Summary bar
- Compact card/row above device list
- Left: Bluetooth icon + "X of Y connected" (or "No devices connected")
- Right: Small status dots for Bluetooth adapter (green/red) and permissions (green/amber)
- Hidden when no devices are paired (empty state shown instead)

### 4. Device list
- `ListView` of paired devices, one tile per device
- Reuses existing `_DeviceListTile` from `paired_devices_page.dart`
- Each tile: device color dot, name, connected/paired subtitle, popup menu
- Popup menu: Connect/Disconnect, Rename, Change Color, Unpair
- Tap disconnected tile to connect
- Connected tiles get green background/border (existing style)

### 5. FAB
- Bluetooth search icon (bottom-right)
- Navigates to `BluetoothSearchPage`
- Disabled (grayed) when permissions not granted or Bluetooth off

### 6. Empty state
- Shown when no devices are paired
- Existing illustration + "Find Device" button

### 7. Dialog listeners
- Sync conflict, device setup, wrong account dialogs (moved from old bluetooth_page)

## Files changed

| File | Action |
|------|--------|
| `bluetooth_page.dart` | Rewrite with merged design |
| `paired_devices_page.dart` | Delete |
| `app_router.dart` | Remove `paired-devices` route |
| `profile_page.dart` | Change "Paired Devices" nav to point to `/bluetooth` tab |

## What stays the same

- `BluetoothSearchPage` — untouched
- All dialog widgets — untouched
- `ble_status_banner.dart`, `blinking_widget.dart` — untouched
- BLoC layer — no changes needed
- `_DeviceListTile` — moved into `bluetooth_page.dart` (no logic changes)

## Implementation steps

1. Move `_DeviceListTile` and dialog methods (rename, color picker, unpair) from `paired_devices_page.dart` into `bluetooth_page.dart`
2. Rewrite `bluetooth_page.dart` body: summary bar + device list + FAB + empty state
3. Move `LoadPairedDevices` dispatch and conflict/setup/wrong-account listeners into new page
4. Delete `paired_devices_page.dart`
5. Update `app_router.dart` — remove paired-devices route
6. Update `profile_page.dart` — redirect "Paired Devices" to Bluetooth tab
7. Test: build, verify navigation, verify all device actions work
