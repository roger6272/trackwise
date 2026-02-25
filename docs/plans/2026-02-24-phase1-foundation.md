# Phase 1: Foundation — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add `claimedBy`/`claimedAt` fields to Item, `deviceInstanceId` to EventLog, and `color` to PairedDevice — the data-layer prerequisites for multi-device BLE (Phase 2).

**Architecture:** Extend existing entities and models following the established pattern: add fields to domain entity → extend in model with Firestore serialization → update all manual constructor call sites → update test fixtures. No UI or behavior changes.

**Tech Stack:** Dart, Equatable, Cloud Firestore, mocktail (tests)

---

### Task 1: Add `claimedBy` and `claimedAt` to Item Entity

**Files:**
- Modify: `lib/features/items/domain/entities/item.dart`

**Step 1: Add fields, copyWith params, and props**

Add two new fields to the `Item` class. Follow the existing `categoryId`/`clearCategoryId` pattern for the sentinel.

```dart
// After line 103 (cycleNotes field), add:
  /// Device instance ID that has claimed this item for exclusive use.
  /// Null means the item is unclaimed and available to any device.
  final String? claimedBy;

  /// Timestamp when the item was claimed. Null when unclaimed.
  final DateTime? claimedAt;
```

In the constructor (after `super.cycleNotes`), add:
```dart
    this.claimedBy,
    this.claimedAt,
```

In `copyWith()`, add parameters (after `cycleNotes`):
```dart
    String? claimedBy,
    bool clearClaimedBy = false,
    DateTime? claimedAt,
```

In the `copyWith()` return body (after `cycleNotes: cycleNotes ?? this.cycleNotes,`):
```dart
      claimedBy: clearClaimedBy ? null : (claimedBy ?? this.claimedBy),
      claimedAt: clearClaimedBy ? null : (claimedAt ?? this.claimedAt),
```

In `props` list (after `cycleNotes,`):
```dart
        claimedBy,
        claimedAt,
```

In `toString()` (append before closing paren):
```dart
        'claimedBy: $claimedBy, claimedAt: $claimedAt)';
```

**Step 2: Run tests to verify nothing breaks**

Run: `flutter test test/features/items/`
Expected: Tests compile but some may fail due to ItemModel constructor mismatch — that's fixed in Task 2.

**Step 3: Commit**

```
feat: add claimedBy and claimedAt fields to Item entity
```

---

### Task 2: Add `claimedBy` and `claimedAt` to ItemModel

**Files:**
- Modify: `lib/features/items/data/models/item_model.dart`

**Step 1: Update ItemModel constructor, fromFirestore, toFirestore, and copyWith**

In the `ItemModel` constructor (after `super.cycleNotes,`), add:
```dart
    super.claimedBy,
    super.claimedAt,
```

In `fromFirestore()` factory (after `cycleNotes:` line ~90), add:
```dart
      claimedBy: data['claimed_by'] as String?,
      claimedAt: _parseNullableDateTime(data['claimed_at']),
```

In `toFirestore()` method, add conditional fields (after the `deviceItemId` block ~line 155):
```dart
    if (this.claimedBy != null) {
      map['claimed_by'] = this.claimedBy!;
    }
    if (this.claimedAt != null) {
      map['claimed_at'] = Timestamp.fromDate(this.claimedAt!);
    }
```

Note: `claimed_at` uses Firestore `Timestamp` (not milliseconds int) per the spec requirement for server timestamp compatibility.

In the `copyWith()` override, add parameters (after `cycleNotes`):
```dart
    String? claimedBy,
    bool clearClaimedBy = false,
    DateTime? claimedAt,
```

In the `copyWith()` return body (after `cycleNotes:`):
```dart
      claimedBy: clearClaimedBy ? null : (claimedBy ?? this.claimedBy),
      claimedAt: clearClaimedBy ? null : (claimedAt ?? this.claimedAt),
```

**Step 2: Run tests to verify compilation**

Run: `flutter test test/features/items/data/models/item_model_test.dart`
Expected: PASS (existing tests don't set claimedBy/claimedAt, defaults to null)

**Step 3: Commit**

```
feat: add claimedBy/claimedAt serialization to ItemModel
```

---

### Task 3: Update ItemModel Constructor Calls in Repository Impl

**Files:**
- Modify: `lib/features/items/data/repositories/item_repository_impl.dart`

**Step 1: Add claimedBy/claimedAt to all 4 ItemModel(...) calls**

There are 4 manual `ItemModel(...)` constructors at lines 87, 139, 234, 265. In each, after the `cycleNotes: item.cycleNotes,` line, add:
```dart
        claimedBy: item.claimedBy,
        claimedAt: item.claimedAt,
```

**Step 2: Run tests**

Run: `flutter test test/features/items/data/repositories/item_repository_impl_test.dart`
Expected: PASS

**Step 3: Commit**

```
feat: propagate claimedBy/claimedAt through item repository
```

---

### Task 4: Update ItemModel Constructor Calls in Datasource Impl

**Files:**
- Modify: `lib/features/items/data/datasources/item_remote_datasource_impl.dart`

**Step 1: Add claimedBy/claimedAt to all 3 ItemModel(...) calls**

There are 3 manual `ItemModel(...)` constructors at lines 223, 266, 328. In each, after the `cycleNotes: item.cycleNotes,` line, add:
```dart
        claimedBy: item.claimedBy,
        claimedAt: item.claimedAt,
```

Note: The `incrementItem` method (line 328) reads from Firestore via `ItemModel.fromFirestore(doc)` first, so `claimedBy`/`claimedAt` are already parsed. They just need to be passed through in the manual constructor call.

**Step 2: Run tests**

Run: `flutter test test/features/items/data/datasources/item_remote_datasource_impl_test.dart`
Expected: PASS

**Step 3: Commit**

```
feat: propagate claimedBy/claimedAt through item datasource
```

---

### Task 5: Update Test Fixtures

**Files:**
- Modify: `test/features/items/helpers/test_fixtures.dart`

**Step 1: No changes needed to test fixtures**

The existing test fixtures don't set `claimedBy`/`claimedAt`, and the new fields default to `null`. Since `null` is the correct default for "unclaimed", no fixture changes are required. Existing tests should continue to pass.

**Step 2: Verify all item tests pass**

Run: `flutter test test/features/items/`
Expected: ALL PASS

**Step 3: Verify build succeeds**

Run: `flutter build apk --debug`
Expected: BUILD SUCCESSFUL

**Step 4: Commit (if any test file adjustments were needed)**

Skip if no changes needed.

---

### Task 6: Add Item Model Serialization Tests for New Fields

**Files:**
- Modify: `test/features/items/data/models/item_model_test.dart`

**Step 1: Write tests for claimedBy/claimedAt serialization**

Add a new test group after the existing `cycleNotes` tests. Follow the existing test patterns in this file:

```dart
    group('claimedBy and claimedAt', () {
      test('fromFirestore should parse claimed_by and claimed_at', () {
        // Use a mock DocumentSnapshot with claimed_by and claimed_at fields
        // claimed_by: String, claimed_at: Timestamp
        // Verify both fields are parsed correctly
      });

      test('fromFirestore should handle null claimed_by and claimed_at', () {
        // Standard doc without claimed fields → both should be null
      });

      test('toFirestore should include claimed_by and claimed_at when set', () {
        final model = ItemModel(
          id: 'test',
          name: 'Test',
          count: 0,
          todayCount: 0,
          incrementBy: 1,
          reminder: ReminderType.none,
          reminderValue: 0,
          lastUpdated: DateTime(2024, 1, 1),
          userId: 'user1',
          claimedBy: 'AA:BB:CC:DD:EE:FF',
          claimedAt: DateTime(2024, 6, 15, 10, 30),
        );
        final map = model.toFirestore();
        expect(map['claimed_by'], 'AA:BB:CC:DD:EE:FF');
        expect(map['claimed_at'], isA<Timestamp>());
      });

      test('toFirestore should omit claimed_by and claimed_at when null', () {
        final model = ItemModel(
          id: 'test',
          name: 'Test',
          count: 0,
          todayCount: 0,
          incrementBy: 1,
          reminder: ReminderType.none,
          reminderValue: 0,
          lastUpdated: DateTime(2024, 1, 1),
          userId: 'user1',
        );
        final map = model.toFirestore();
        expect(map.containsKey('claimed_by'), isFalse);
        expect(map.containsKey('claimed_at'), isFalse);
      });

      test('copyWith should support clearClaimedBy sentinel', () {
        final model = ItemModel(
          id: 'test',
          name: 'Test',
          count: 0,
          todayCount: 0,
          incrementBy: 1,
          reminder: ReminderType.none,
          reminderValue: 0,
          lastUpdated: DateTime(2024, 1, 1),
          userId: 'user1',
          claimedBy: 'AA:BB:CC:DD:EE:FF',
          claimedAt: DateTime(2024, 6, 15),
        );
        final cleared = model.copyWith(clearClaimedBy: true);
        expect(cleared.claimedBy, isNull);
        expect(cleared.claimedAt, isNull);
      });
    });
```

**Step 2: Run tests to verify they fail (TDD - tests first)**

Run: `flutter test test/features/items/data/models/item_model_test.dart`
Expected: The new tests should PASS since the implementation is already done in Tasks 1-2. This confirms the implementation is correct.

**Step 3: Commit**

```
test: add serialization tests for Item claimedBy/claimedAt fields
```

---

### Task 7: Add `deviceInstanceId` to EventLog Entity

**Files:**
- Modify: `lib/features/events/domain/entities/event_log.dart`

**Step 1: Add field, constructor param, copyWith, props, toString**

Add field (after `userId` field ~line 37):
```dart
  /// Device instance ID that generated this event.
  /// Null for app-initiated events (e.g., item creation from the app).
  final String? deviceInstanceId;
```

In constructor (after `required this.userId,`):
```dart
    this.deviceInstanceId,
```

In `copyWith()` params (after `userId`):
```dart
    String? deviceInstanceId,
```

In `copyWith()` return body (after `userId:`):
```dart
      deviceInstanceId: deviceInstanceId ?? this.deviceInstanceId,
```

In `props` list (after `userId,`):
```dart
        deviceInstanceId,
```

In `toString()` (append):
```dart
        'deviceInstanceId: $deviceInstanceId)';
```

**Step 2: Run tests**

Run: `flutter test test/features/events/`
Expected: May have compilation errors in EventLogModel — fixed in Task 8.

**Step 3: Commit**

```
feat: add deviceInstanceId field to EventLog entity
```

---

### Task 8: Add `deviceInstanceId` to EventLogModel

**Files:**
- Modify: `lib/features/events/data/models/event_log_model.dart`

**Step 1: Update constructor, fromFirestore, fromEntity, toFirestore**

In `EventLogModel` constructor (after `super.userId,`):
```dart
    super.deviceInstanceId,
```

In `fromFirestore()` (after `userId: userId,` ~line 80):
```dart
      deviceInstanceId: data['device_instance_id'] as String?,
```

In `fromEntity()` (after `userId: entity.userId,`):
```dart
      deviceInstanceId: entity.deviceInstanceId,
```

In `toFirestore()` method, add conditional field (after the `'id': id,` line):
```dart
      if (deviceInstanceId != null)
        'device_instance_id': deviceInstanceId!,
```

**Step 2: Run tests**

Run: `flutter test test/features/events/`
Expected: PASS (existing tests don't set deviceInstanceId, defaults to null)

**Step 3: Commit**

```
feat: add deviceInstanceId serialization to EventLogModel
```

---

### Task 9: Update EventLog Creation Sites

**Files:**
- Modify: `lib/features/bluetooth/domain/usecases/sync_device_data_usecase.dart` (2 sites)
- Modify: `lib/features/items/data/repositories/item_repository_impl.dart` (1 site)
- Modify: `lib/features/items/domain/usecases/create_item_usecase.dart` (1 site)

**Step 1: Add deviceInstanceId to sync_device_data_usecase.dart**

At line 258 (`_syncEventMessage` — EventLog creation), add after `userId: userId,`:
```dart
        // deviceInstanceId will be added in Phase 2 when SyncDeviceDataParams gains it
```

At line 328 (`_syncLogsMessage` — EventLog creation), same comment.

Note: The actual `deviceInstanceId` value comes from `SyncDeviceDataParams` which gains that field in Phase 2. For now, the field defaults to `null` which is correct — it means "not yet tracked". No code change needed here since the new field is optional.

**Step 2: Verify app-initiated EventLog creation sites pass null**

In `item_repository_impl.dart` (line 112) and `create_item_usecase.dart` (line 134), the EventLog creation already omits `deviceInstanceId`, which defaults to `null`. This is correct for app-initiated events per the spec. No changes needed.

**Step 3: Run tests**

Run: `flutter test`
Expected: ALL PASS

**Step 4: Commit (only if changes were made)**

Skip if no changes needed — null default handles this correctly.

---

### Task 10: Update EventLog Test Fixtures

**Files:**
- Modify: `test/features/events/helpers/test_fixtures.dart`

**Step 1: No changes required**

Existing test fixtures don't set `deviceInstanceId`, and `null` is the correct default for test events (which are app-initiated or don't specify a device). No fixture changes needed.

**Step 2: Verify all event tests pass**

Run: `flutter test test/features/events/`
Expected: ALL PASS

---

### Task 11: Add `color` to PairedDevice Entity

**Files:**
- Modify: `lib/features/bluetooth/domain/entities/paired_device.dart`

**Step 1: Add field, constructor param, copyWith, fromFirestore, toFirestore, props, toString**

Add field (after `pairedAt` field ~line 28):
```dart
  /// Color palette index (0-9) for distinguishing this device in multi-device UI.
  /// Default 0 (blue). Assigned automatically on pairing, user-changeable in settings.
  final int color;
```

In constructor (after `required this.pairedAt,`):
```dart
    this.color = 0,
```

In `copyWith()` params (after `pairedAt`):
```dart
    int? color,
```

In `copyWith()` return body (after `pairedAt:`):
```dart
      color: color ?? this.color,
```

In `fromFirestore()` (after `pairedAt:` line):
```dart
      color: data['color'] as int? ?? 0,
```

In `toFirestore()` (after `'paired_at':` line):
```dart
      'color': color,
```

In `props` list (after `pairedAt`):
```dart
        color,
```

In `toString()` (append before closing paren):
Add `color: $color` to the string.

**Step 2: Run tests**

Run: `flutter test test/features/bluetooth/domain/entities/paired_device_test.dart`
Expected: PASS (existing tests don't set color, defaults to 0)

**Step 3: Commit**

```
feat: add color field to PairedDevice entity
```

---

### Task 12: Add PairedDevice Color Tests

**Files:**
- Modify: `test/features/bluetooth/domain/entities/paired_device_test.dart`

**Step 1: Add tests for the color field**

```dart
    test('should default color to 0', () {
      expect(testDevice.color, 0);
    });

    test('copyWith should update color', () {
      final copy = testDevice.copyWith(color: 3);
      expect(copy.color, 3);
    });
```

In the `fromFirestore` group, add:
```dart
      test('should parse color field', () {
        final data = {
          'device_instance_id': 'device-456',
          'device_name': 'Work Device',
          'paired_at': Timestamp.fromDate(testDateTime),
          'color': 5,
        };
        final device = PairedDevice.fromFirestore(data);
        expect(device.color, 5);
      });

      test('should default color to 0 when missing', () {
        final data = {
          'device_instance_id': 'device-456',
          'device_name': 'Work Device',
          'paired_at': Timestamp.fromDate(testDateTime),
        };
        final device = PairedDevice.fromFirestore(data);
        expect(device.color, 0);
      });
```

In the `toFirestore` group, update existing test expectation:
```dart
        expect(map['color'], 0);
```

**Step 2: Run tests**

Run: `flutter test test/features/bluetooth/domain/entities/paired_device_test.dart`
Expected: ALL PASS

**Step 3: Commit**

```
test: add PairedDevice color field tests
```

---

### Task 13: Final Verification

**Step 1: Run full test suite**

Run: `flutter test`
Expected: ALL PASS (~728 tests, 1 pre-existing skip)

**Step 2: Verify build**

Run: `flutter build apk --debug`
Expected: BUILD SUCCESSFUL

**Step 3: Commit any remaining fixes, then push**

```
git push -u origin feature/multi-device-ble
```
