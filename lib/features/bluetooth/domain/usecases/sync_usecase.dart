import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/utils/logger.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/services/connectivity_service.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/domain/repositories/user_repository.dart';
import '../../../categories/domain/repositories/category_repository.dart';
import '../../../items/domain/entities/item.dart';
import '../../../items/domain/repositories/item_repository.dart';
import '../entities/paired_device.dart';
import '../entities/sync_state.dart';
import '../failures/sync_failures.dart';
import '../repositories/bluetooth_repository.dart';

/// Result of a successful sync operation.
enum SyncResultType {
  /// Normal sync completed (device -> app)
  success,

  /// Override completed (app -> device)
  overrideComplete,
}

/// Result of sync operation.
class SyncResult extends Equatable {
  final SyncResultType type;

  /// The Firestore ID of the selected item after sync.
  /// Null if no item selected.
  final String? selectedFirestoreId;

  /// The device_item_id of the selected item.
  /// -1 if no item selected.
  final int selectedDeviceItemId;

  /// The device instance ID from handshake response.
  /// Used to track which paired device is connected.
  final String? deviceInstanceId;

  /// Item names that were released while this device was offline.
  /// Non-empty means stale claim dialog should be shown before syncing.
  /// Populated from Firestore paired_devices during handshake so the BLoC
  /// can check synchronously without an extra async call.
  final List<String> staleClaims;

  const SyncResult({
    required this.type,
    this.selectedFirestoreId,
    this.selectedDeviceItemId = -1,
    this.deviceInstanceId,
    this.staleClaims = const [],
  });

  @override
  List<Object?> get props => [type, selectedFirestoreId, selectedDeviceItemId, deviceInstanceId, staleClaims];
}

/// Parameters for the PerformSyncUseCase.
class PerformSyncParams extends Equatable {
  /// ID of the connected BLE device (from flutter_blue_plus).
  /// Not used by the use case itself but passed through for repository calls.
  final String deviceId;

  const PerformSyncParams({required this.deviceId});

  @override
  List<Object?> get props => [deviceId];
}

/// Use case for performing the sync handshake flow.
///
/// This is the main entry point after BLE connection is established.
/// Handles:
/// 1. Internet connectivity check
/// 2. Handshake with device (sync_seq=-1 to skip comparison)
/// 3. Wrong account / uninitialized detection
/// 4. Conflict fallback (old firmware that doesn't understand -1)
/// 5. New device registration (with limit check)
///
/// After success, the BLoC pushes claim-filtered items via
/// [RefreshDeviceItemsUseCase]. No sync_complete or sync_seq update
/// is needed — sync_seq is obsolete in multi-device mode.
@lazySingleton
class PerformSyncUseCase {
  final BluetoothRepository _bluetoothRepository;
  final UserRepository _userRepository;
  final ConnectivityService _connectivityService;

  /// Maximum number of devices allowed per account.
  static const int maxDevices = 10;

  PerformSyncUseCase(
    this._bluetoothRepository,
    this._userRepository,
    this._connectivityService,
  );

  /// Performs the sync handshake flow.
  ///
  /// Steps:
  /// 1. Check internet connectivity
  /// 2. Send handshake to device (sync_seq=-1 to skip comparison)
  /// 3. Handle wrong account / uninitialized (return error)
  /// 4. Handle conflict (safety net for old firmware)
  /// 5. Add to paired_devices if new (check limit)
  /// 6. Return success — BLoC pushes items via RefreshDeviceItemsUseCase
  ///
  /// In multi-device mode, sync_seq serves no purpose: each device connection
  /// would increment the global counter, causing every reconnection to be a
  /// "conflict". Instead we send -1 so firmware skips the comparison and
  /// always returns in_sync. Items are pushed after handshake completes.
  Future<Either<Failure, SyncResult>> call(PerformSyncParams params) async {
    // Step 1: Check internet connectivity FIRST
    final hasInternet = await _connectivityService.hasInternetConnection();
    if (!hasInternet) {
      return const Left(NoInternetFailure());
    }

    // Step 2: Get current user
    final userResult = await _userRepository.getCurrentUser();
    if (userResult.isLeft()) {
      return userResult.fold(
        (failure) => Left(_mapToSyncFailure(failure)),
        (_) => const Left(NotAuthenticatedFailure()),
      );
    }
    final user = userResult.getOrElse(() => throw StateError('User should exist'));

    // Step 3: Send handshake to device
    // Send sync_seq=-1 to skip sync_seq comparison on firmware side.
    // This eliminates false conflicts in multi-device mode.
    final handshakeResult = await _bluetoothRepository.sendHandshake(
      deviceId: params.deviceId,
      uid: user.id,
      syncSeq: -1,
    );

    if (handshakeResult.isLeft()) {
      return handshakeResult.fold(
        (failure) => Left(BleSyncFailure(failure.message)),
        (_) => const Left(BleSyncFailure('Handshake failed')),
      );
    }
    final handshake = handshakeResult.getOrElse(
      () => throw StateError('Handshake should exist'),
    );

    // Step 4: Check for wrong account FIRST
    if (handshake.status == SyncStatus.wrongAccount) {
      return const Left(WrongAccountFailure());
    }

    // Normalize device instance ID to uppercase (ESP32 returns lowercase, Flutter Blue Plus uses uppercase)
    final deviceInstanceId = handshake.deviceInstanceId.toUpperCase();

    // Step 5: Check for uninitialized device (factory reset or new)
    // User must confirm setup before we proceed
    if (handshake.status == SyncStatus.uninitialized) {
      return Left(DeviceUninitializedFailure(
        deviceInstanceId: deviceInstanceId,
      ));
    }

    // Step 6: Safety net — old firmware that doesn't understand sync_seq=-1
    // will return conflict. BLoC auto-overrides for paired devices.
    if (handshake.status == SyncStatus.conflict) {
      return Left(SyncConflictFailure(
        deviceSyncSeq: handshake.deviceSyncSeq,
        appSyncSeq: 0,
        deviceInstanceId: deviceInstanceId,
      ));
    }

    // Step 7: Device is in sync - add to paired devices if new
    final isNewDevice = !user.pairedDevices.any(
      (d) => d.deviceInstanceId.toUpperCase() == deviceInstanceId,
    );

    if (isNewDevice) {
      // Check device limit
      if (user.pairedDevices.length >= maxDevices) {
        return const Left(DeviceLimitFailure());
      }

      // Compute next available color
      final usedColors = user.pairedDevices.map((d) => d.color).toSet();
      var nextColor = 0;
      for (var i = 0; i < 10; i++) {
        if (!usedColors.contains(i)) { nextColor = i; break; }
      }

      await _userRepository.addPairedDevice(
        PairedDevice(
          deviceInstanceId: deviceInstanceId,
          deviceName: 'Traxelos One',
          pairedAt: DateTime.now(),
          color: nextColor,
        ),
      );
    }

    // Step 8: Check for stale claims (items released while device was offline).
    // Include them in the result so the BLoC can guard synchronously —
    // avoids an async gap where firmware prefs/logs could slip through.
    final pairedDevice = user.pairedDevices.cast<PairedDevice?>().firstWhere(
      (d) => d!.deviceInstanceId.toUpperCase() == deviceInstanceId,
      orElse: () => null,
    );
    final staleClaims = pairedDevice?.staleClaims ?? const [];

    // Step 9: Return success — no sync_complete or sync_seq update needed.
    // BLoC handles item push in _onHandshakeCompleted via RefreshDeviceItemsUseCase.
    // Firmware sends prefs+logs automatically after in_sync handshake.
    return Right(SyncResult(
      type: SyncResultType.success,
      deviceInstanceId: deviceInstanceId,
      staleClaims: staleClaims,
    ));
  }

  /// Maps generic failures to sync-specific failures.
  Failure _mapToSyncFailure(Failure failure) {
    if (failure is AuthFailure) {
      return const NotAuthenticatedFailure();
    }
    if (failure is ServerFailure) {
      return FirestoreUpdateFailure(failure.message);
    }
    return BleSyncFailure(failure.message);
  }
}

/// Parameters for the PerformOverrideUseCase.
class PerformOverrideParams extends Equatable {
  /// ID of the connected BLE device.
  final String deviceId;

  /// Device instance ID (required for claim filtering in multi-device mode).
  final String deviceInstanceId;

  /// Device name for display in paired devices list.
  final String? deviceName;

  /// Current selected item's Firestore ID (from app UI state).
  /// If provided, this takes precedence over the last synced selection.
  final String? currentSelectedFirestoreId;

  /// When true, sends an empty item list with no selection.
  /// Used for fresh device setup so the user must explicitly claim an item.
  final bool startEmpty;

  const PerformOverrideParams({
    required this.deviceId,
    required this.deviceInstanceId,
    this.deviceName,
    this.currentSelectedFirestoreId,
    this.startEmpty = false,
  });

  @override
  List<Object?> get props => [deviceId, deviceInstanceId, deviceName, currentSelectedFirestoreId, startEmpty];
}

/// Use case for performing override flow (app is source of truth).
///
/// Called after user confirms in the conflict dialog.
/// Pushes app data to device using chunked protocol.
///
/// This use case:
/// 1. Re-checks internet connectivity
/// 2. Fetches items from Firestore
/// 3. Validates item count (max 100)
/// 4. Sends override to device
/// 5. Updates Firestore sync_seq (with retry)
@lazySingleton
class PerformOverrideUseCase {
  final BluetoothRepository _bluetoothRepository;
  final UserRepository _userRepository;
  final ItemRepository _itemRepository;
  final CategoryRepository _categoryRepository;
  final ConnectivityService _connectivityService;

  /// Maximum number of items that can be synced.
  static const int maxItems = 100;

  /// Maximum Firestore retry attempts.
  static const int maxRetries = 3;

  PerformOverrideUseCase(
    this._bluetoothRepository,
    this._userRepository,
    this._itemRepository,
    this._categoryRepository,
    this._connectivityService,
  );

  /// Performs the override flow.
  ///
  /// Steps:
  /// 1. Re-check internet (user may have lost connection)
  /// 2. Get current user
  /// 3. Fetch items from Firestore
  /// 4. Validate item count
  /// 5. Build category name map
  /// 6. Send override to device
  /// 7. Update Firestore (with retry)
  Future<Either<Failure, SyncResult>> call(PerformOverrideParams params) async {
    // Step 1: Re-check internet connectivity
    final hasInternet = await _connectivityService.hasInternetConnection();
    if (!hasInternet) {
      return const Left(NoInternetFailure());
    }

    // Step 2: Get current user
    final userResult = await _userRepository.getCurrentUser();
    if (userResult.isLeft()) {
      return userResult.fold(
        (failure) => Left(_mapToSyncFailure(failure)),
        (_) => const Left(NotAuthenticatedFailure()),
      );
    }
    final user = userResult.getOrElse(() => throw StateError('User should exist'));

    final newSyncSeq = user.syncSequenceNo + 1;

    // Start empty: send no items, no selection. Device gets paired but stays clean.
    if (params.startEmpty) {
      return _sendEmptyOverride(
        params: params,
        user: user,
        newSyncSeq: newSyncSeq,
      );
    }

    // Step 3: Fetch items from Firestore
    final itemsResult = await _itemRepository.getItems(user.id);
    if (itemsResult.isLeft()) {
      return itemsResult.fold(
        (failure) => Left(_mapToSyncFailure(failure)),
        (_) => const Left(FirestoreUpdateFailure('Failed to fetch items.')),
      );
    }
    final allItems = itemsResult.getOrElse(() => []);

    // Filter to items with device_item_id (synced items only)
    final syncedItems = allItems.where((i) => i.deviceItemId != null).toList();

    // Step 4: Determine selected item
    // Priority: current app selection > last synced selection > first item
    var selectedItemId = -1;

    // Step 5: Find selected item and filter to its category
    // (Device should only have items from the active category, like normal sync)
    List<Item> deviceItems;

    // Find the selected item based on priority
    Item? selectedItem;

    AppLogger.debug('Override selection debug:');
    AppLogger.debug('   params.currentSelectedFirestoreId: ${params.currentSelectedFirestoreId}');
    AppLogger.debug('   user.lastSelectedDeviceItemId: ${user.lastSelectedDeviceItemId}');
    AppLogger.debug('   allItems count: ${allItems.length}');
    AppLogger.debug('   syncedItems count: ${syncedItems.length}');
    for (final item in allItems) {
      AppLogger.debug('   - ${item.name}: firestoreId=${item.id}, deviceItemId=${item.deviceItemId}, categoryId=${item.categoryId}');
    }

    // First, try to use current app selection (Firestore ID from UI state)
    // IMPORTANT: Search in allItems first to find the item (even if it doesn't have deviceItemId)
    // This ensures we get the correct category for filtering
    Item? selectedItemFromAll;
    if (params.currentSelectedFirestoreId != null &&
        params.currentSelectedFirestoreId!.isNotEmpty &&
        params.currentSelectedFirestoreId != 'none') {
      // First, find the item in allItems to get its category
      selectedItemFromAll = allItems.cast<Item?>().firstWhere(
        (i) => i?.id == params.currentSelectedFirestoreId,
        orElse: () => null,
      );
      if (selectedItemFromAll != null) {
        AppLogger.debug('   ✓ Found in allItems: ${selectedItemFromAll.name} (deviceItemId=${selectedItemFromAll.deviceItemId})');
        // Now check if this item is also in syncedItems (has deviceItemId)
        if (selectedItemFromAll.deviceItemId != null) {
          selectedItem = selectedItemFromAll;
          selectedItemId = selectedItemFromAll.deviceItemId!;
          AppLogger.debug('   ✓ Item has deviceItemId: $selectedItemId');
        } else {
          // Item exists but doesn't have deviceItemId - use its category to filter
          // and pick the first synced item in that category
          AppLogger.debug('   ⚠ Item has no deviceItemId, will use its category to filter');
        }
      } else {
        AppLogger.debug('   ✗ currentSelectedFirestoreId not found in allItems');
      }
    }

    // If we found an item in allItems but it doesn't have deviceItemId,
    // use its category to filter syncedItems and pick the first one
    if (selectedItem == null && selectedItemFromAll != null) {
      final targetCategoryId = selectedItemFromAll.categoryId ?? '';
      final itemsInCategory = syncedItems.where((i) {
        final itemCategoryId = i.categoryId ?? '';
        return itemCategoryId == targetCategoryId;
      }).toList();
      if (itemsInCategory.isNotEmpty) {
        itemsInCategory.sort((a, b) => a.categoryOrder.compareTo(b.categoryOrder));
        final firstInCategory = itemsInCategory.first;
        selectedItem = firstInCategory;
        selectedItemId = firstInCategory.deviceItemId ?? -1;
        AppLogger.debug('   ✓ Using first synced item in same category: ${firstInCategory.name} (deviceItemId=$selectedItemId)');
      } else {
        AppLogger.debug('   ⚠ No synced items in category $targetCategoryId');
      }
    }

    // Fall back to device's current claim (reconnection — device had an item selected)
    if (selectedItem == null && params.deviceInstanceId != null && syncedItems.isNotEmpty) {
      selectedItem = syncedItems.cast<Item?>().firstWhere(
        (i) => i?.claimedBy == params.deviceInstanceId,
        orElse: () => null,
      );
      if (selectedItem != null) {
        selectedItemId = selectedItem.deviceItemId ?? -1;
        AppLogger.debug('   ✓ Found by claimedBy ${params.deviceInstanceId}: ${selectedItem.name} (deviceItemId=$selectedItemId)');
      }
    }

    // If no current selection, fall back to last synced selection
    if (selectedItem == null && user.lastSelectedDeviceItemId >= 0 && syncedItems.isNotEmpty) {
      selectedItem = syncedItems.cast<Item?>().firstWhere(
        (i) => i?.deviceItemId == user.lastSelectedDeviceItemId,
        orElse: () => null,
      );
      if (selectedItem != null) {
        selectedItemId = selectedItem.deviceItemId ?? -1;
        AppLogger.debug('   ✓ Found by lastSelectedDeviceItemId: ${selectedItem.name} (deviceItemId=$selectedItemId)');
      } else {
        AppLogger.debug('   ✗ lastSelectedDeviceItemId not found in syncedItems');
      }
    }

    // If still no selection, pick the first synced item
    if (selectedItem == null && syncedItems.isNotEmpty) {
      selectedItem = syncedItems.first;
      selectedItemId = selectedItem.deviceItemId ?? -1;
      AppLogger.debug('   ⚠ Falling back to first item: ${selectedItem.name} (deviceItemId=$selectedItemId)');
    }

    if (selectedItem != null) {
      final selectedCategoryId = selectedItem.categoryId ?? '';

      // Filter to only items in the selected item's category
      deviceItems = syncedItems.where((i) {
        final itemCategoryId = i.categoryId ?? '';
        return itemCategoryId == selectedCategoryId;
      }).toList();

      // Sort by categoryOrder for consistent ordering
      deviceItems.sort((a, b) => a.categoryOrder.compareTo(b.categoryOrder));

      // Filter out items claimed by other devices (exclusive leasing)
      deviceItems = deviceItems.where((i) =>
        i.claimedBy == null || i.claimedBy == params.deviceInstanceId
      ).toList();

      // Validate selected item is still in claim-filtered list
      if (selectedItemId >= 0 &&
          !deviceItems.any((i) => i.deviceItemId == selectedItemId)) {
        // Selected item was claimed by another device — redirect
        if (deviceItems.isNotEmpty) {
          selectedItemId = deviceItems.first.deviceItemId ?? -1;
        } else {
          selectedItemId = -1;
        }
      }
    } else {
      // No items at all - send empty list
      deviceItems = [];
    }

    // Step 6: Validate item count
    if (deviceItems.length > maxItems) {
      return Left(TooManyItemsFailure(itemCount: deviceItems.length));
    }

    // Step 7: Build category name map
    final categoryNames = await _buildCategoryNameMap(user.id);

    // Step 8: Send override to device (uid is stored on device during setup)
    final overrideResult = await _bluetoothRepository.sendOverrideChunked(
      deviceId: params.deviceId,
      uid: user.id,
      syncSeq: newSyncSeq,
      selectedId: selectedItemId,
      items: deviceItems,
      categoryNames: categoryNames,
    );

    if (overrideResult.isLeft()) {
      return overrideResult.fold(
        (failure) => Left(BleSyncFailure(failure.message)),
        (_) => const Left(OverrideFailure()),
      );
    }

    final result = overrideResult.getOrElse(
      () => throw StateError('Override result should exist'),
    );

    if (!result.isSuccess) {
      return Left(OverrideFailure(deviceMessage: result.message));
    }


    // Step 8: Update Firestore sync_seq (with retry)
    final updateResult = await _updateSyncStateWithRetry(
      syncSequenceNo: newSyncSeq,
      lastSelectedDeviceItemId: selectedItemId,
    );

    if (updateResult.isLeft()) {
      return updateResult.fold(
        (failure) => Left(failure),
        (_) => const Left(FirestoreUpdateFailure()),
      );
    }


    // Step 9: Add device to paired devices (await to ensure it completes before LoadPairedDevices)
    if (params.deviceInstanceId != null) {
      // Compute next available color
      final usedColors = user.pairedDevices.map((d) => d.color).toSet();
      var nextColor = 0;
      for (var i = 0; i < 10; i++) {
        if (!usedColors.contains(i)) { nextColor = i; break; }
      }

      await _userRepository.addPairedDevice(
        PairedDevice(
          deviceInstanceId: params.deviceInstanceId!,
          deviceName: params.deviceName ?? 'Traxelos One',
          pairedAt: DateTime.now(),
          color: nextColor,
        ),
      );
    }

    // Find the Firestore ID of the selected item
    String? selectedFirestoreId;
    if (selectedItemId >= 0 && deviceItems.isNotEmpty) {
      final selectedItem = deviceItems.cast<Item?>().firstWhere(
        (i) => i?.deviceItemId == selectedItemId,
        orElse: () => deviceItems.first,
      );
      selectedFirestoreId = selectedItem?.id;
    }

    return Right(SyncResult(
      type: SyncResultType.overrideComplete,
      selectedFirestoreId: selectedFirestoreId,
      selectedDeviceItemId: selectedItemId,
      deviceInstanceId: params.deviceInstanceId,
    ));
  }

  /// Sends an empty override: pairs the device but pushes no items.
  Future<Either<Failure, SyncResult>> _sendEmptyOverride({
    required PerformOverrideParams params,
    required User user,
    required int newSyncSeq,
  }) async {
    final overrideResult = await _bluetoothRepository.sendOverrideChunked(
      deviceId: params.deviceId,
      uid: user.id,
      syncSeq: newSyncSeq,
      selectedId: -1,
      items: [],
    );

    if (overrideResult.isLeft()) {
      return overrideResult.fold(
        (failure) => Left(BleSyncFailure(failure.message)),
        (_) => const Left(OverrideFailure()),
      );
    }

    final result = overrideResult.getOrElse(
      () => throw StateError('Override result should exist'),
    );

    if (!result.isSuccess) {
      return Left(OverrideFailure(deviceMessage: result.message));
    }

    // Update Firestore sync_seq
    final updateResult = await _updateSyncStateWithRetry(
      syncSequenceNo: newSyncSeq,
      lastSelectedDeviceItemId: -1,
    );

    if (updateResult.isLeft()) {
      return updateResult.fold(
        (failure) => Left(failure),
        (_) => const Left(FirestoreUpdateFailure()),
      );
    }

    // Add device to paired devices
    final usedColors = user.pairedDevices.map((d) => d.color).toSet();
    var nextColor = 0;
    for (var i = 0; i < 10; i++) {
      if (!usedColors.contains(i)) { nextColor = i; break; }
    }

    await _userRepository.addPairedDevice(
      PairedDevice(
        deviceInstanceId: params.deviceInstanceId,
        deviceName: params.deviceName ?? 'Traxelos One',
        pairedAt: DateTime.now(),
        color: nextColor,
      ),
    );

    return Right(SyncResult(
      type: SyncResultType.overrideComplete,
      selectedFirestoreId: null,
      selectedDeviceItemId: -1,
      deviceInstanceId: params.deviceInstanceId,
    ));
  }

  /// Builds a map of categoryId -> categoryName.
  Future<Map<String, String>> _buildCategoryNameMap(String userId) async {
    final categoriesResult = await _categoryRepository.getCategories(userId);

    return categoriesResult.fold(
      (failure) {
        return <String, String>{};
      },
      (categories) {
        return {
          for (final cat in categories) cat.id: cat.name,
        };
      },
    );
  }

  /// Updates Firestore sync state with retry logic.
  Future<Either<Failure, void>> _updateSyncStateWithRetry({
    required int syncSequenceNo,
    required int lastSelectedDeviceItemId,
  }) async {
    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      final result = await _userRepository.updateSyncState(
        syncSequenceNo: syncSequenceNo,
        lastSelectedDeviceItemId: lastSelectedDeviceItemId,
      );

      if (result.isRight()) {
        return const Right(null);
      }

      if (attempt == maxRetries) {
        return const Left(FirestoreUpdateFailure());
      }

      // Backoff: 1s, 2s, 3s
      await Future.delayed(Duration(seconds: attempt));
    }

    return const Left(FirestoreUpdateFailure());
  }

  /// Maps generic failures to sync-specific failures.
  Failure _mapToSyncFailure(Failure failure) {
    if (failure is AuthFailure) {
      return const NotAuthenticatedFailure();
    }
    if (failure is ServerFailure) {
      return FirestoreUpdateFailure(failure.message);
    }
    return BleSyncFailure(failure.message);
  }
}
