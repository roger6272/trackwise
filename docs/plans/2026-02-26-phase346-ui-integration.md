# Phases 3, 4, & 6: Multi-Device UI & Integration Testing

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Complete the Exclusive Leasing UI — device color tinting, claim-aware swipe actions, unlock dialogs, device dropdown, drag-and-drop ungating, color picker, and CSV device column — then verify everything end-to-end.

**Architecture:** All Phase 3 changes center on `_buildItemTile` in `items_list_page.dart` plus two new widgets (`DeviceSelectorSheet`, `UnlockConfirmDialog`). Phase 4 adds `DeviceColorPickerDialog` and `UpdateDeviceColor` event mirroring the existing `UpdateDeviceName` pattern. Phase 6 is manual QA with physical hardware. No domain/data layer changes — all data already flows through `BluetoothState`.

**Tech Stack:** Flutter Slidable, BLoC, AppColors, showModalBottomSheet, AlertDialog, mocktail

> **⚠️ Note:** References to `sync_seq` in this document are outdated — `sync_seq` and `sync_complete` were removed in protocol v3.

**Spec:** `docs/EXCLUSIVE_LEASING_SPEC.md` Sections 4, 8.4, 10, 12

---

## Phase 3: UI — Item List

### Task 3.1: Add Device Color Palette to AppColors

**Files:**
- Modify: `lib/core/theme/app_colors.dart`
- Create: `test/core/theme/app_colors_test.dart`

**Context:** `PairedDevice.color` is int 0-9 but no color mapping exists. Need 10 light-mode + 10 dark-mode colors, a `deviceColor(index, brightness)` helper, a `deviceColorTint()` for subtle backgrounds, and `deviceColorOffline()` for grayed-out.

**Step 1: Write failing test**

```dart
// test/core/theme/app_colors_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traxelos/core/theme/app_colors.dart';

void main() {
  group('AppColors.deviceColor', () {
    test('returns a color for each index 0-9 in light mode', () {
      for (int i = 0; i < 10; i++) {
        expect(AppColors.deviceColor(i, Brightness.light), isA<Color>());
      }
    });

    test('returns a color for each index 0-9 in dark mode', () {
      for (int i = 0; i < 10; i++) {
        expect(AppColors.deviceColor(i, Brightness.dark), isA<Color>());
      }
    });

    test('clamps out-of-range index', () {
      expect(AppColors.deviceColor(-1, Brightness.light), isA<Color>());
      expect(AppColors.deviceColor(99, Brightness.light), isA<Color>());
    });

    test('light and dark colors differ', () {
      final light = AppColors.deviceColor(0, Brightness.light);
      final dark = AppColors.deviceColor(0, Brightness.dark);
      expect(light, isNot(equals(dark)));
    });

    test('deviceColorTint has transparency', () {
      final tint = AppColors.deviceColorTint(0, Brightness.light);
      expect(tint.a, lessThan(1.0));
    });
  });
}
```

**Step 2:** Run test → FAIL

**Step 3: Add palette to `app_colors.dart`**

After `primaryAdaptive()`, before closing `}`:

```dart
  // ==================== Device Color Palette ====================

  static const List<Color> _deviceColorsLight = [
    Color(0xFF1565C0), // 0 Blue
    Color(0xFF2E7D32), // 1 Green
    Color(0xFFE65100), // 2 Orange
    Color(0xFF6A1B9A), // 3 Purple
    Color(0xFFC62828), // 4 Red
    Color(0xFF00695C), // 5 Teal
    Color(0xFFAD1457), // 6 Pink
    Color(0xFFF57F17), // 7 Amber
    Color(0xFF283593), // 8 Indigo
    Color(0xFF4E342E), // 9 Brown
  ];

  static const List<Color> _deviceColorsDark = [
    Color(0xFF64B5F6), // 0 Blue
    Color(0xFF81C784), // 1 Green
    Color(0xFFFFB74D), // 2 Orange
    Color(0xFFCE93D8), // 3 Purple
    Color(0xFFEF9A9A), // 4 Red
    Color(0xFF80CBC4), // 5 Teal
    Color(0xFFF48FB1), // 6 Pink
    Color(0xFFFFE082), // 7 Amber
    Color(0xFF9FA8DA), // 8 Indigo
    Color(0xFFBCAAA4), // 9 Brown
  ];

  static Color deviceColor(int index, Brightness brightness) {
    final i = index.clamp(0, 9);
    return brightness == Brightness.dark ? _deviceColorsDark[i] : _deviceColorsLight[i];
  }

  static Color deviceColorTint(int index, Brightness brightness) {
    return deviceColor(index, brightness).withValues(alpha: 0.15);
  }

  static Color deviceColorOffline(int index, Brightness brightness) {
    return deviceColor(index, brightness).withValues(alpha: 0.35);
  }
```

**Step 4:** Run test → PASS
**Step 5:** `flutter test` → ALL PASS
**Step 6:** Commit: `feat: add 10-color device palette to AppColors`

---

### Task 3.2: Device Color + Name in Item Tile

**Files:**
- Modify: `lib/features/items/presentation/pages/items_list_page.dart`

**Context:** `_buildItemTile` (line 1328) needs `connectedDevices` and `pairedDevices` params. In multi-device mode (2+ connected), claimed items show device color on accent bar + left border, and device name subtitle below item name. Single-device mode unchanged.

**Step 1: Add params to `_buildItemTile` signature**

Add after existing params:
```dart
  // Multi-device claim visualization (empty = single-device, no colors)
  Map<String, DeviceConnectionState> connectedDevices = const {},
  List<PairedDevice> pairedDevices = const [],
```

Import (if not present):
```dart
import '../../../bluetooth/domain/entities/paired_device.dart';
import '../../../bluetooth/presentation/bloc/device_connection_state.dart';
```

**Step 2: Pass the new params at all 4 call sites** (proxyDecorator ~505, ReorderableListView itemBuilder ~676, disconnected ListView ~761, and any category-label variant)

Add to each:
```dart
connectedDevices: bluetoothState.connectedDevices,
pairedDevices: bluetoothState.pairedDevices,
```

**Step 3: Add helper methods to `_ItemsListContentState`**

```dart
/// Returns device color for claimed item, or null (single-device / unclaimed).
Color? _claimColor(Item item, Map<String, DeviceConnectionState> connectedDevices,
    List<PairedDevice> pairedDevices, Brightness brightness, {bool forOffline = false}) {
  if (connectedDevices.length < 2 || item.claimedBy == null) return null;
  final idx = pairedDevices.indexWhere((d) => d.deviceInstanceId == item.claimedBy);
  final colorIndex = idx >= 0 ? pairedDevices[idx].color : 0;
  return forOffline
      ? AppColors.deviceColorOffline(colorIndex, brightness)
      : AppColors.deviceColor(colorIndex, brightness);
}

/// Returns claiming device name (+ "· disconnected" if offline), or null.
String? _claimDeviceName(Item item, Map<String, DeviceConnectionState> connectedDevices,
    List<PairedDevice> pairedDevices) {
  if (connectedDevices.length < 2 || item.claimedBy == null) return null;
  final idx = pairedDevices.indexWhere((d) => d.deviceInstanceId == item.claimedBy);
  final name = idx >= 0 ? pairedDevices[idx].deviceName : item.claimedBy!;
  final isOnline = connectedDevices[item.claimedBy!]?.isOnline == true;
  return isOnline ? name : '$name \u00B7 disconnected';
}
```

**Step 4: Inside `_buildItemTile`, compute claim state after `isActivated`**

```dart
final brightness = Theme.of(context).brightness;
final isClaimedOnline = item.claimedBy != null &&
    connectedDevices[item.claimedBy!]?.isOnline == true &&
    connectedDevices.length >= 2;
final isClaimedOffline = item.claimedBy != null &&
    connectedDevices.length >= 2 &&
    (connectedDevices[item.claimedBy!] == null ||
     !connectedDevices[item.claimedBy!]!.isOnline);
final deviceAccentColor = isClaimedOnline
    ? _claimColor(item, connectedDevices, pairedDevices, brightness)
    : isClaimedOffline
        ? _claimColor(item, connectedDevices, pairedDevices, brightness, forOffline: true)
        : null;
```

**Step 5: Replace container decoration** (lines ~1355-1360)

```dart
decoration: BoxDecoration(
  color: isActivated ? activatedColor
      : deviceAccentColor != null ? deviceAccentColor.withValues(alpha: 0.15) : alternate,
  border: isActivated
      ? Border(left: BorderSide(color: deviceAccentColor ?? AppColors.actionActivate, width: 4.0))
      : deviceAccentColor != null
          ? Border(left: BorderSide(color: deviceAccentColor, width: 4.0))
          : null,
),
```

**Step 6: Replace accent bar color logic** (Builder at lines ~1401-1408)

Remove `final isDark = ...` inside Builder (use `brightness` from above). Replace:
```dart
final accentColor = deviceAccentColor ??
    (isActivated
        ? (brightness == Brightness.dark ? const Color(0xFFB8B4FF) : const Color(0xFF8580E0))
        : (brightness == Brightness.dark ? const Color(0xFF6B7280) : const Color(0xFFD1D5DB)));
final textColor = deviceAccentColor ??
    (isActivated
        ? (brightness == Brightness.dark ? const Color(0xFFB8B4FF) : AppColors.actionActivate)
        : primaryText);
```

**Step 7: Add device name subtitle** — wrap the `Text(item.name, ...)` Expanded child in a Column:

```dart
Expanded(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(item.name, /* existing style */),
      Builder(builder: (context) {
        final claimName = _claimDeviceName(item, connectedDevices, pairedDevices);
        if (claimName == null) return const SizedBox.shrink();
        return Text(claimName,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: isClaimedOffline
                ? AppColors.secondaryText(brightness).withValues(alpha: 0.6)
                : deviceAccentColor ?? AppColors.secondaryText(brightness),
            fontSize: 11.0, fontStyle: FontStyle.italic),
          overflow: TextOverflow.ellipsis);
      }),
    ],
  ),
),
```

**Step 8:** `flutter build apk --debug` → BUILD SUCCESSFUL
**Step 9:** Commit: `feat(items-list): device color tinting and name subtitle for claimed items`

---

### Task 3.3: Claim-Aware Swipe Actions

**Files:**
- Modify: `lib/features/items/presentation/pages/items_list_page.dart`

**Context:** The 3 hardcoded swipe actions (Activate, Edit, Delete) must become dynamic based on claim state. Use `isItemEditable()` from `device_connection_state.dart:53`.

**Swipe action matrix:**

| State | Actions |
|-------|---------|
| 0 devices | Edit (disabled), Delete (disabled) |
| 1+ devices, unclaimed | Activate, Edit, Delete |
| Claimed, device online | Unlock, Edit, Delete |
| Claimed, device offline | Unlock (break-glass), Edit (disabled), Delete (disabled) |

**Step 1: Compute claim state before Slidable** (in `_buildItemTile`, before `Widget result = Padding(`)

```dart
final isClaimed = item.claimedBy != null;
final isMultiDevice = connectedDevices.length >= 2;
final claimDeviceOnline = isClaimed && connectedDevices[item.claimedBy!]?.isOnline == true;
// In multi-device: use claim rules. In single-device: always editable if connected.
final editable = isMultiDevice ? isItemEditable(item.claimedBy, connectedDevices) : isConnected;
// Unlock only appears in multi-device mode. Single-device always shows Activate (spec: "same as today").
final showUnlock = isClaimed && isMultiDevice;
```

**Step 2: Replace the 3 `SlidableAction` children with conditional list**

```dart
children: [
  // Multi-device + claimed → Unlock. Otherwise when connected → Activate.
  if (showUnlock)
    SlidableAction(
      backgroundColor: claimDeviceOnline ? AppColors.actionActivate : AppColors.actionDisabled,
      icon: Icons.lock_open_rounded, autoClose: false,
      onPressed: (ctx) async {
        HapticFeedback.lightImpact();
        Slidable.of(ctx)?.close();
        await _handleUnlock(context, item, connectedDevices, pairedDevices);
      },
    )
  else if (isConnected)
    SlidableAction(
      backgroundColor: AppColors.actionActivate,
      icon: Icons.push_pin_rounded, autoClose: false,
      onPressed: (ctx) async {
        HapticFeedback.lightImpact();
        _dismissActivationHintIfShowing();
        await _handleActivate(context, item, appUiState, selectedItemId);
        Slidable.of(ctx)?.close();
      },
    ),
  // Edit
  SlidableAction(
    backgroundColor: editable ? AppColors.primary : AppColors.actionDisabled,
    icon: Icons.edit, autoClose: false,
    onPressed: (ctx) async {
      HapticFeedback.lightImpact();
      _dismissActivationHintIfShowing();
      Slidable.of(ctx)?.close();
      if (!isConnected) { await _showConnectDeviceDialog(context); return; }
      if (!editable) return;
      context.pushNamed(ItemFormPage.routeName, extra: {'item': item});
    },
  ),
  // Delete
  SlidableAction(
    backgroundColor: editable ? AppColors.actionDelete : AppColors.actionDisabled,
    icon: Icons.delete_outline_rounded, autoClose: false,
    onPressed: (ctx) async {
      HapticFeedback.mediumImpact();
      _dismissActivationHintIfShowing();
      if (!isConnected) { await _showConnectDeviceDialog(context); Slidable.of(ctx)?.close(); return; }
      if (!editable) { Slidable.of(ctx)?.close(); return; }
      // ... existing delete logic (capture refs, confirm, dispatch) ...
      Slidable.of(ctx)?.close();
    },
  ),
],
```

**Step 3: Extract activate logic into `_handleActivate`** (move the big inline block from the old Activate action)

```dart
Future<void> _handleActivate(BuildContext context, Item item,
    AppUiState appUiState, String? selectedItemId) async {
  final btBloc = context.read<BluetoothBloc>();
  final btState = btBloc.state;
  if (btState.hasMultipleDevices) {
    // Task 3.4 fills this in — show DeviceSelectorSheet
    return;
  }
  // Single device — claim immediately
  final deviceId = btState.connectedDeviceInstanceId ?? '';
  if (deviceId.isEmpty) return;
  _claimForDevice(context, item, deviceId, appUiState, btState);
}
```

**Step 4: Add `_claimForDevice` helper**

```dart
void _claimForDevice(BuildContext context, Item item, String deviceId,
    AppUiState appUiState, BluetoothState btState) {
  appUiState.activeItemId = item.id;
  final itemsState = context.read<ItemsBloc>().state;
  if (itemsState is ItemsLoaded) {
    final catId = item.categoryId;
    final categoryItems = itemsState.items.where((i) {
      final sameCat = catId == null || catId.isEmpty
          ? (i.categoryId == null || i.categoryId!.isEmpty)
          : i.categoryId == catId;
      return sameCat && (i.claimedBy == null || i.claimedBy == deviceId);
    }).toList()..sort((a, b) => a.categoryOrder.compareTo(b.categoryOrder));

    context.read<BluetoothBloc>().add(SendItemsToDevice(
      categoryItems, deviceInstanceId: deviceId, categoryNames: _cachedCategoryNames));
    _lastSyncedCategoryId = catId ?? '';
    _lastSyncedSignature = categoryItems.map((i) =>
      '${i.id}:${i.categoryId ?? ''}:${i.categoryOrder}:${i.name}:${i.incrementBy}:${i.reminder.index}:${i.reminderValue}').join(',');
    _lastSyncTime = DateTime.now();
  }
  final prevId = btState.connectedDevices[deviceId]?.selectedItemId;
  final btBloc = context.read<BluetoothBloc>();
  btBloc.add(SendSelectedItem(item.id, item.deviceItemId ?? 0, deviceInstanceId: deviceId));
  btBloc.add(ClaimItem(itemId: item.id, deviceInstanceId: deviceId, previousItemId: prevId));
}
```

**Step 5: Add placeholder `_handleUnlock`** (filled in Task 3.5)

```dart
Future<void> _handleUnlock(BuildContext context, Item item,
    Map<String, DeviceConnectionState> connectedDevices,
    List<PairedDevice> pairedDevices) async {
  // Task 3.5 fills this in
}
```

**Step 6:** `flutter build apk --debug` → BUILD SUCCESSFUL
**Step 7:** Commit: `feat(items-list): claim-aware swipe actions with activate/unlock/edit/delete`

---

### Task 3.4: Device Selector Sheet for Multi-Device Activate

**Files:**
- Create: `lib/features/items/presentation/widgets/device_selector_sheet.dart`
- Create: `test/features/items/presentation/widgets/device_selector_sheet_test.dart`
- Modify: `lib/features/items/presentation/pages/items_list_page.dart`

**Step 1: Write failing test**

```dart
// test/features/items/presentation/widgets/device_selector_sheet_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traxelos/features/items/presentation/widgets/device_selector_sheet.dart';

void main() {
  testWidgets('shows device names and calls onDeviceSelected', (tester) async {
    String? selected;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body:
      DeviceSelectorSheet(
        devices: [(instanceId: 'dev1', name: 'Office'), (instanceId: 'dev2', name: 'Home')],
        onDeviceSelected: (id) { selected = id; }))));
    expect(find.text('Office'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    await tester.tap(find.text('Office'));
    expect(selected, 'dev1');
  });
}
```

**Step 2:** Run test → FAIL

**Step 3: Create widget**

```dart
// lib/features/items/presentation/widgets/device_selector_sheet.dart
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class DeviceSelectorSheet extends StatelessWidget {
  final List<({String instanceId, String name})> devices;
  final ValueChanged<String> onDeviceSelected;

  const DeviceSelectorSheet({super.key, required this.devices, required this.onDeviceSelected});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground(brightness),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
      child: SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 8),
          decoration: BoxDecoration(
            color: AppColors.secondaryText(brightness).withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2))),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('Select Device', style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.primaryText(brightness), fontWeight: FontWeight.w600))),
        const Divider(height: 1),
        ...devices.map((d) => ListTile(
          leading: Icon(Icons.watch, color: AppColors.primary),
          title: Text(d.name, style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppColors.primaryText(brightness))),
          onTap: () => onDeviceSelected(d.instanceId))),
        const SizedBox(height: 8),
      ])));
  }
}
```

**Step 4:** Run test → PASS

**Step 5: Wire into `_handleActivate`** — replace the `if (btState.hasMultipleDevices)` placeholder:

```dart
if (btState.hasMultipleDevices) {
  final devicesList = btState.connectedDevices.entries
      .where((e) => e.value.isOnline)
      .map((e) {
        final pd = btState.pairedDevices.firstWhere(
          (p) => p.deviceInstanceId == e.key,
          orElse: () => PairedDevice(deviceInstanceId: e.key, deviceName: e.key, pairedAt: DateTime.now()));
        return (instanceId: e.key, name: pd.deviceName);
      }).toList();
  if (devicesList.isEmpty || !context.mounted) return;
  await showModalBottomSheet<void>(context: context, builder: (_) =>
    DeviceSelectorSheet(devices: devicesList, onDeviceSelected: (deviceId) {
      Navigator.of(context).pop();
      _claimForDevice(context, item, deviceId, appUiState, btBloc.state);
    }));
  return;
}
```

Import: `import '../widgets/device_selector_sheet.dart';`

**Step 6:** `flutter test && flutter build apk --debug` → ALL PASS, BUILD SUCCESSFUL
**Step 7:** Commit: `feat(items-list): device selector sheet for multi-device activate`

---

### Task 3.5: Unlock Confirm Dialog

**Files:**
- Create: `lib/features/items/presentation/widgets/unlock_confirm_dialog.dart`
- Create: `test/features/items/presentation/widgets/unlock_confirm_dialog_test.dart`
- Modify: `lib/features/items/presentation/pages/items_list_page.dart`

**Step 1: Write failing tests**

```dart
// test/features/items/presentation/widgets/unlock_confirm_dialog_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traxelos/features/items/presentation/widgets/unlock_confirm_dialog.dart';

void main() {
  testWidgets('online: shows names, no break-glass warning', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (ctx) =>
      TextButton(onPressed: () => showUnlockConfirmDialog(
        context: ctx, itemName: 'Push-ups', deviceName: 'Office', isBreakGlass: false),
        child: const Text('Open')))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Push-ups'), findsOneWidget);
    expect(find.textContaining('Office'), findsOneWidget);
    expect(find.textContaining('discarded'), findsNothing);
  });

  testWidgets('offline: shows break-glass warning', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (ctx) =>
      TextButton(onPressed: () => showUnlockConfirmDialog(
        context: ctx, itemName: 'Push-ups', deviceName: 'Home', isBreakGlass: true),
        child: const Text('Open')))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('discarded'), findsOneWidget);
  });

  testWidgets('returns true on Release', (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (ctx) =>
      TextButton(onPressed: () async {
        result = await showUnlockConfirmDialog(
          context: ctx, itemName: 'X', deviceName: 'D', isBreakGlass: false);
      }, child: const Text('Open')))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Release'));
    await tester.pumpAndSettle();
    expect(result, true);
  });
}
```

**Step 2:** Run test → FAIL

**Step 3: Create dialog**

```dart
// lib/features/items/presentation/widgets/unlock_confirm_dialog.dart
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

Future<bool> showUnlockConfirmDialog({
  required BuildContext context,
  required String itemName,
  required String deviceName,
  required bool isBreakGlass,
}) async {
  return await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
    backgroundColor: AppColors.secondaryBackground(Theme.of(ctx).brightness),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    title: Text('Release Item', style: TextStyle(
      fontWeight: FontWeight.w600, color: AppColors.primaryText(Theme.of(ctx).brightness))),
    content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text.rich(TextSpan(children: [
        const TextSpan(text: 'Release '),
        TextSpan(text: itemName, style: const TextStyle(fontWeight: FontWeight.w600)),
        const TextSpan(text: ' from '),
        TextSpan(text: deviceName, style: const TextStyle(fontWeight: FontWeight.w600)),
        const TextSpan(text: '?'),
      ])),
      if (isBreakGlass) ...[
        const SizedBox(height: 12),
        Container(padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.3))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(
              'Unsynced counts will be discarded when $deviceName reconnects.',
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: AppColors.error))),
          ])),
      ],
    ]),
    actions: [
      TextButton(onPressed: () => Navigator.of(ctx).pop(false),
        child: Text('Cancel', style: TextStyle(color: AppColors.secondaryText(Theme.of(ctx).brightness)))),
      FilledButton(onPressed: () => Navigator.of(ctx).pop(true),
        style: FilledButton.styleFrom(backgroundColor: isBreakGlass ? AppColors.error : AppColors.primary),
        child: const Text('Release', style: TextStyle(color: Colors.white))),
    ],
  )) ?? false;
}
```

**Step 4:** Run test → PASS

**Step 5: Implement `_handleUnlock`** — replace placeholder:

```dart
Future<void> _handleUnlock(BuildContext context, Item item,
    Map<String, DeviceConnectionState> connectedDevices,
    List<PairedDevice> pairedDevices) async {
  if (item.claimedBy == null) return;
  final idx = pairedDevices.indexWhere((d) => d.deviceInstanceId == item.claimedBy);
  final deviceName = idx >= 0 ? pairedDevices[idx].deviceName : item.claimedBy!;
  final isOnline = connectedDevices[item.claimedBy!]?.isOnline == true;
  if (!context.mounted) return;
  final confirmed = await showUnlockConfirmDialog(
    context: context, itemName: item.name, deviceName: deviceName, isBreakGlass: !isOnline);
  if (confirmed && context.mounted) {
    context.read<BluetoothBloc>().add(ReleaseItem(itemId: item.id));
  }
}
```

Import: `import '../widgets/unlock_confirm_dialog.dart';`

**Step 6:** `flutter test && flutter build apk --debug` → ALL PASS, BUILD SUCCESSFUL
**Step 7:** Commit: `feat(items-list): unlock confirm dialog with break-glass warning`

---

### Task 3.6: Enable Drag-and-Drop Regardless of Connection

**Files:**
- Modify: `lib/features/items/presentation/pages/items_list_page.dart`

**Step 1:** Change the `if (isConnected && _searchQuery.isEmpty)` guard (~line 428) to `if (_searchQuery.isEmpty)`. Preserve `isConnected` guards on the activation/reorder hint triggers inside.

**Step 2:** Remove the `if (isConnected)` guard on `ReorderableDelayedDragStartListener` (~line 1461). Always wrap with the listener.

**Step 3:** Remove the `Opacity(opacity: isConnected ? 1.0 : 0.5)` wrapper (~line 1350). Keep the muted text color for item name: `color: isConnected ? primaryText : secondaryText`.

**Step 4:** `flutter test && flutter build apk --debug` → ALL PASS, BUILD SUCCESSFUL
**Step 5:** Commit: `feat(items-list): enable drag-and-drop reorder regardless of connection state`

---

## Phase 4: UI — Supporting Pages

### Task 4.1: UpdateDeviceColor Event + BLoC Handler

**Files:**
- Modify: `lib/features/bluetooth/presentation/bloc/bluetooth_event.dart`
- Modify: `lib/features/bluetooth/presentation/bloc/bluetooth_bloc.dart`
- Modify: `lib/features/auth/domain/repositories/user_repository.dart`
- Modify: `lib/features/auth/data/repositories/user_repository_impl.dart`

**Step 1:** Add event (mirror `UpdateDeviceName`):

```dart
class UpdateDeviceColor extends BluetoothEvent {
  final String deviceInstanceId;
  final int newColor;
  const UpdateDeviceColor({required this.deviceInstanceId, required this.newColor});
  @override List<Object?> get props => [deviceInstanceId, newColor];
}
```

**Step 2:** Add `updateDeviceColor(String deviceInstanceId, int newColor)` to `UserRepository` abstract + impl (mirror `updateDeviceName` exactly but update `'color'` key).

**Step 3:** Register handler in BLoC: `on<UpdateDeviceColor>(_onUpdateDeviceColor);`

```dart
Future<void> _onUpdateDeviceColor(UpdateDeviceColor event, Emitter<BluetoothState> emit) async {
  final result = await _userRepository.updateDeviceColor(event.deviceInstanceId, event.newColor);
  result.fold(
    (f) => AppLogger.debug('Failed to update device color: ${f.message}'),
    (_) {
      final updated = state.pairedDevices.map((d) =>
        d.deviceInstanceId == event.deviceInstanceId ? d.copyWith(color: event.newColor) : d).toList();
      emit(state.copyWith(pairedDevices: updated));
    });
}
```

**Step 4:** `flutter test && flutter build apk --debug` → ALL PASS, BUILD SUCCESSFUL
**Step 5:** Commit: `feat(bluetooth): add UpdateDeviceColor event mirroring UpdateDeviceName`

---

### Task 4.2: Device Color Swatch on Device Tile

**Files:**
- Modify: `lib/features/bluetooth/presentation/pages/paired_devices_page.dart`

**Step 1:** In `_DeviceListTile`, replace the leading `Icon(Icons.watch, ...)` with a `Stack` that overlays a 12px colored dot in the bottom-right corner:

```dart
Stack(children: [
  Center(child: Icon(Icons.watch, color: isConnected ? AppColors.success : secondaryText, size: 28)),
  Positioned(right: 2, bottom: 2, child: Container(
    width: 12, height: 12,
    decoration: BoxDecoration(
      color: AppColors.deviceColor(device.color, Theme.of(context).brightness),
      shape: BoxShape.circle,
      border: Border.all(color: bgColor.withValues(alpha: 0.8), width: 1.5)))),
])
```

**Step 2:** `flutter build apk --debug` → BUILD SUCCESSFUL
**Step 3:** Commit: `feat(paired-devices): show device color swatch on device tile`

---

### Task 4.3: Color Picker Dialog

**Files:**
- Create: `lib/features/bluetooth/presentation/widgets/device_color_picker_dialog.dart`
- Create: `test/features/bluetooth/presentation/widgets/device_color_picker_dialog_test.dart`
- Modify: `lib/features/bluetooth/presentation/pages/paired_devices_page.dart`

**Step 1: Write failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traxelos/features/bluetooth/presentation/widgets/device_color_picker_dialog.dart';

void main() {
  testWidgets('shows 10 swatches, check on current', (tester) async {
    int? selected;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body:
      DeviceColorPickerDialog(currentColor: 2, onColorSelected: (i) { selected = i; }))));
    expect(find.byType(InkWell), findsNWidgets(10));
    expect(find.byIcon(Icons.check), findsOneWidget);
    await tester.tap(find.byType(InkWell).at(4));
    expect(selected, 4);
  });
}
```

**Step 2:** Run test → FAIL

**Step 3: Create widget** — AlertDialog with 5x2 grid of colored circles, checkmark on current

```dart
// lib/features/bluetooth/presentation/widgets/device_color_picker_dialog.dart
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class DeviceColorPickerDialog extends StatelessWidget {
  final int currentColor;
  final ValueChanged<int> onColorSelected;
  const DeviceColorPickerDialog({super.key, required this.currentColor, required this.onColorSelected});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return AlertDialog(
      backgroundColor: AppColors.secondaryBackground(brightness),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Choose Color', style: TextStyle(
        fontWeight: FontWeight.w600, color: AppColors.primaryText(brightness))),
      content: SizedBox(width: 280, child: GridView.builder(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5, mainAxisSpacing: 12, crossAxisSpacing: 12),
        itemCount: 10,
        itemBuilder: (ctx, i) => Semantics(
          label: ['Blue','Green','Orange','Purple','Red','Teal','Pink','Amber','Indigo','Brown'][i],
          child: InkWell(onTap: () => onColorSelected(i), borderRadius: BorderRadius.circular(24),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.deviceColor(i, brightness), shape: BoxShape.circle,
                border: i == currentColor ? Border.all(color: AppColors.primaryText(brightness), width: 3) : null),
              child: i == currentColor ? const Icon(Icons.check, color: Colors.white, size: 20) : null))))),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(),
        child: Text('Cancel', style: TextStyle(color: AppColors.secondaryText(brightness))))]);
  }
}
```

**Step 4:** Run test → PASS

**Step 5: Wire into paired_devices_page.dart** — add "Change Color" to popup menu, add `_showColorPickerDialog` method, pass `onChangeColor` callback to `_DeviceListTile`

**Step 6:** `flutter test && flutter build apk --debug` → ALL PASS, BUILD SUCCESSFUL
**Step 7:** Commit: `feat(paired-devices): add color picker dialog for device color customization`

---

### Task 4.4: CSV Export — Optional Device Column

**Files:**
- Modify: `lib/features/export/domain/entities/csv_export_config.dart`
- Modify: `lib/features/export/domain/usecases/generate_csv_usecase.dart`
- Modify: `lib/features/export/presentation/pages/export_page.dart`
- Modify: `test/features/export/domain/usecases/generate_csv_usecase_test.dart`

**Step 1: Write failing test** — test that raw CSV includes Device column when `includeDeviceColumn: true`

**Step 2:** Run test → FAIL

**Step 3: Add `includeDeviceColumn` (bool, default false) and `deviceNameMap` (Map, default empty) to `CSVExportConfig`**

**Step 4: Update `_generateCSV`** — add `,Device` to raw header when enabled; append `event.deviceInstanceId` (mapped via `deviceNameMap`) to each raw row. Device column only for raw (daily/byCycle aggregate across devices).

**Step 5:** Run test → PASS

**Step 6: Add `SwitchListTile` to export_page.dart** — visible only when aggregation = raw. Build `deviceNameMap` from `BluetoothState.pairedDevices`.

**Step 7:** `flutter test && flutter build apk --debug` → ALL PASS, BUILD SUCCESSFUL
**Step 8:** Commit: `feat(export): add optional Device column to raw CSV export`

---

### Task 4.5: Break-Glass Reconnection (Confirm No-Op)

**Context:** The spec's break-glass reconnection flow (device reconnects after force-release) is already handled by the existing sync conflict dialog (`SyncConflictDialog`). When handshake detects `sync_seq` mismatch, the conflict dialog shows "Override Device" / "Don't Sync" — which is exactly the spec's break-glass reconnection flow (Section 9.3). **No new dialog needed.**

Verify: read `lib/features/bluetooth/presentation/widgets/sync_conflict_dialog.dart` and confirm it handles this case. If the dialog text doesn't mention released items, consider updating the message — but this is a cosmetic enhancement, not a functional gap.

---

## Phase 6: Integration & Testing

### Task 6.1: Automated Test Suite Gate

Run: `flutter test` → ALL PASS
Run: `flutter build apk --debug` → BUILD SUCCESSFUL
Do not proceed to manual testing until green.

### Task 6.2: Single-Device Regression

| # | Scenario | Expected |
|---|----------|----------|
| 1 | Connect single device, browse items | No device colors, no name subtitles, no dropdown |
| 2 | Swipe activate | Purple accent (old behavior) |
| 3 | Edit/Delete while connected | Works normally |
| 4 | Drag-and-drop while connected | Works |
| 5 | Drag-and-drop while disconnected | Works (new) |
| 6 | Search mode | ListView, no drag |
| 7 | CSV export raw, Device toggle | Toggle visible, column appears |

### Task 6.3: Multi-Device Claim Flow

| # | Scenario | Expected |
|---|----------|----------|
| 1 | Connect 2 devices | Device colors on claimed items |
| 2 | Activate unclaimed item | Device selector sheet appears |
| 3 | Select device | Item claimed, color shown |
| 4 | Claimed item swipe | Unlock, Edit, Delete |
| 5 | Auto-release on new claim | Previous item unclaimed |
| 6 | Device only sees its items | BLE monitor confirms |

### Task 6.4: Offline Claim + Break-Glass

| # | Scenario | Expected |
|---|----------|----------|
| 1 | Disconnect claiming device | Grayed color, "· disconnected" |
| 2 | Edit/Delete on offline claim | Disabled (gray) |
| 3 | Unlock swipe on offline claim | Break-glass dialog with warning |
| 4 | Confirm break-glass release | Item released |
| 5 | Device reconnects after release | Conflict dialog → Override |

### Task 6.5: Claim-Triggered Push

| # | Scenario | Expected |
|---|----------|----------|
| 1 | Claim item, other device connected | Other device loses that item |
| 2 | Release item, other device connected | Other device gains that item |

### Task 6.6: Edge Cases (Spec Section 10)

| # | Scenario | Expected |
|---|----------|----------|
| 1 | All items claimed by others | Empty list, "no item selected" |
| 2 | Delete claimed item (online) | Deleted, device notified |
| 3 | Delete claimed item (offline) | Blocked |
| 4 | Simultaneous claim race | One wins, loser gets corrective push |
| 5 | Unpair device | All its claims released |
| 6 | 1 connected, 2 paired | Single-device behavior |
| 7 | App restart | Claims persist, devices disconnected |

### Task 6.7: Documentation

Update `docs/USER_GUIDE.md` (multi-device claiming, unlock, color picker) and `docs/TROUBLESHOOTING.md` (offline-claimed item troubleshooting).

---

## Dependency Graph

```
3.1 (AppColors palette)
 ├─→ 3.2 (device color + name in tile)
 │    └─→ 3.3 (claim-aware swipe actions)
 │         ├─→ 3.4 (device selector sheet)
 │         └─→ 3.5 (unlock dialog)
 └─→ 4.2 (device swatch on tile)
      └─→ 4.3 (color picker dialog)

3.6 (drag-and-drop ungating) — independent

4.1 (UpdateDeviceColor event) — independent of Phase 3
 └─→ 4.3 (color picker uses the event)

4.4 (CSV device column) — independent

4.5 (break-glass confirm no-op) — independent

6.x (testing) — blocked by all Phase 3 + 4 tasks
```

## Risk Areas

1. **`_buildItemTile` is 337 lines** — adding 4 parameters and claim-state logic makes it larger. Consider extracting the Slidable setup into a helper after Phase 3 is done (not during, to minimize change scope).
2. **Progressive complexity rule** — single-device mode must show zero multi-device UI. Every conditional must check `connectedDevices.length >= 2`.
3. **`extentRatio: 0.5`** — the Slidable extent ratio needs to accommodate 2-3 actions with varying widths. With Activate sometimes absent, the remaining actions may need `extentRatio` adjustment.
