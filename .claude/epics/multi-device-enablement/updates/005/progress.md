# Task 005: App - Update Firestore schema and user repository

## Status: Complete

## Started: 2026-01-25

## Progress Log

### 2026-01-25 - Implementation Complete
- Reviewed task requirements from 005.md and MULTI_DEVICE_IMPLEMENTATION_PLAN.md
- Explored existing codebase structure:
  - User entity at `lib/features/auth/domain/entities/user.dart`
  - UserModel at `lib/features/auth/data/models/user_model.dart`
  - No existing user repository - only AuthRepository for auth operations
  - BLE device entity at `lib/features/bluetooth/domain/entities/ble_device.dart`
  - Profile datasource shows Firestore patterns

### Implementation Completed
1. [x] Create PairedDevice entity
2. [x] Update User entity with new fields
3. [x] Create UserModel with Firestore conversion
4. [x] Create UserRepository interface
5. [x] Implement UserRepositoryImpl with Firestore methods
6. [x] Add unit tests (27 tests, all passing)
7. [x] Commit changes

### Files Created/Modified
- CREATE: `lib/features/bluetooth/domain/entities/paired_device.dart`
- MODIFY: `lib/features/auth/domain/entities/user.dart`
- MODIFY: `lib/features/auth/data/models/user_model.dart`
- CREATE: `lib/features/auth/domain/repositories/user_repository.dart`
- CREATE: `lib/features/auth/data/repositories/user_repository_impl.dart`
- CREATE: `test/features/auth/data/repositories/user_repository_impl_test.dart`
- CREATE: `test/features/bluetooth/domain/entities/paired_device_test.dart`
- MODIFY: `test/features/auth/helpers/test_helper.dart`
- MODIFY: `lib/features/auth/data/repositories/repositories.dart`
- MODIFY: `lib/features/auth/domain/repositories/repositories.dart`

### Test Results
- PairedDevice entity tests: 10 tests passing
- UserRepositoryImpl tests: 17 tests passing
- All auth feature tests: 147 tests passing

### Acceptance Criteria Met
- [x] Firestore schema updated with new fields
- [x] User entity/model updated with new fields
- [x] fetchSyncSequenceFromServer() method - always fetches fresh from server
- [x] updateSyncState() method - updates sync_seq and last_selected_device_item_id
- [x] addPairedDevice() method - adds device to paired_devices array
- [x] removePairedDevice() method - removes device from array
- [x] updateDeviceName() method - renames device in paired_devices array
- [x] PairedDevice entity created (deviceInstanceId, deviceName, pairedAt)
- [x] Device limit check (max 10)
