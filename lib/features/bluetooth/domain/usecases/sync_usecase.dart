import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/utils/logger.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/services/connectivity_service.dart';
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

  const SyncResult({
    required this.type,
    this.selectedFirestoreId,
    this.selectedDeviceItemId = -1,
    this.deviceInstanceId,
  });

  @override
  List<Object?> get props => [type, selectedFirestoreId, selectedDeviceItemId, deviceInstanceId];
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

/// Use case for performing the complete sync handshake flow.
///
/// This is the main entry point after BLE connection is established.
/// Handles:
/// 1. Internet connectivity check
/// 2. Fresh sync_seq fetch from Firestore
/// 3. Handshake with device
/// 4. Wrong account detection
/// 5. New device registration (with limit check)
/// 6. Normal sync or conflict detection
///
/// Returns [SyncConflictFailure] when conflict is detected - the UI should
/// then prompt the user and call [PerformOverrideUseCase] if they confirm.
@lazySingleton
class PerformSyncUseCase {
  final BluetoothRepository _bluetoothRepository;
  final UserRepository _userRepository;
  final ItemRepository _itemRepository;
  final CategoryRepository _categoryRepository;
  final ConnectivityService _connectivityService;

  /// Maximum number of devices allowed per account.
  static const int maxDevices = 10;

  /// Maximum number of items that can be synced.
  static const int maxItems = 100;

  /// Maximum Firestore retry attempts.
  static const int maxRetries = 3;

  PerformSyncUseCase(
    this._bluetoothRepository,
    this._userRepository,
    this._itemRepository,
    this._categoryRepository,
    this._connectivityService,
  );

  /// Performs the sync handshake flow.
  ///
  /// Steps:
  /// 1. Check internet connectivity
  /// 2. Fetch fresh sync_seq from Firestore
  /// 3. Send handshake to device
  /// 4. Handle wrong account (return error)
  /// 5. Add to paired_devices if new (check limit)
  /// 6. If in_sync -> perform normal sync
  /// 7. If conflict -> return [SyncConflictFailure] for UI
  Future<Either<Failure, SyncResult>> call(PerformSyncParams params) async {
    // Step 0: Check internet connectivity FIRST
    final hasInternet = await _connectivityService.hasInternetConnection();
    if (!hasInternet) {
      return const Left(NoInternetFailure());
    }

    // Step 1: Get current user
    final userResult = await _userRepository.getCurrentUser();
    if (userResult.isLeft()) {
      return userResult.fold(
        (failure) => Left(_mapToSyncFailure(failure)),
        (_) => const Left(NotAuthenticatedFailure()),
      );
    }
    final user = userResult.getOrElse(() => throw StateError('User should exist'));

    // Step 2: Fetch FRESH sync_seq from Firestore (not cached!)
    final syncSeqResult = await _userRepository.fetchSyncSequenceFromServer();
    if (syncSeqResult.isLeft()) {
      return syncSeqResult.fold(
        (failure) => Left(_mapToSyncFailure(failure)),
        (_) => const Left(FirestoreUpdateFailure('Failed to fetch sync state.')),
      );
    }
    final appSyncSeq = syncSeqResult.getOrElse(() => 0);


    // Step 3: Send handshake to device
    final handshakeResult = await _bluetoothRepository.sendHandshake(
      uid: user.id,
      syncSeq: appSyncSeq,
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

    // Step 6: Check for conflict BEFORE adding to paired devices
    // (Don't add device until sync is successful)
    if (handshake.status == SyncStatus.conflict) {
      return Left(SyncConflictFailure(
        deviceSyncSeq: handshake.deviceSyncSeq,
        appSyncSeq: appSyncSeq,
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

      await _userRepository.addPairedDevice(
        PairedDevice(
          deviceInstanceId: deviceInstanceId,
          deviceName: 'Traxelos One',
          pairedAt: DateTime.now(),
        ),
      );
    }

    // Step 8: Perform normal sync (device is source of truth)
    return _performNormalSync(user.id, appSyncSeq, deviceInstanceId);
  }

  /// Performs normal sync flow (device is source of truth).
  ///
  /// Steps:
  /// 1. Request prefs from device
  /// 2. Increment sync_seq
  /// 3. Send sync_complete and wait for ack
  /// 4. Update Firestore (with retry)
  Future<Either<Failure, SyncResult>> _performNormalSync(
    String userId,
    int currentSeq,
    String deviceInstanceId,
  ) async {

    // Step 1: Request prefs from device
    // This is handled by the existing BLE message flow (prefs are sent
    // automatically after handshake success). The BLoC will receive them
    // via watchMessages and call SyncDeviceDataUseCase.
    // Here we need to wait for that to complete...
    //
    // NOTE: For now, we rely on the existing flow where prefs arrive
    // via the notification stream. This use case focuses on the handshake
    // and sync_complete logic. The actual prefs processing happens in
    // SyncDeviceDataUseCase which the BLoC already calls.

    // Step 2: Increment sync_seq
    final newSyncSeq = currentSeq + 1;

    // Step 3: Send sync_complete and WAIT for acknowledgment
    final ackResult = await _bluetoothRepository.sendSyncComplete(newSyncSeq);

    if (ackResult.isLeft()) {
      return ackResult.fold(
        (failure) => Left(BleSyncFailure(failure.message)),
        (_) => const Left(SyncCompleteNotAcknowledgedFailure()),
      );
    }

    final ack = ackResult.getOrElse(
      () => throw StateError('Ack should exist'),
    );

    if (!ack.isSuccess) {
      return const Left(SyncCompleteNotAcknowledgedFailure());
    }


    // Step 4: Update Firestore (with retry)
    // Note: In the full implementation, we'd get the selected item from prefs
    // For now, preserve existing value (-1 means unknown)
    final updateResult = await _updateSyncStateWithRetry(
      syncSequenceNo: newSyncSeq,
      lastSelectedDeviceItemId: -1, // Prefs handling updates this separately
    );

    if (updateResult.isLeft()) {
      return updateResult.fold(
        (failure) => Left(failure),
        (_) => const Left(FirestoreUpdateFailure()),
      );
    }


    return Right(SyncResult(
      type: SyncResultType.success,
      deviceInstanceId: deviceInstanceId,
    ));
  }

  /// Updates Firestore sync state with retry logic.
  ///
  /// Retries up to 3 times with exponential backoff (1s, 2s, 3s).
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

/// Parameters for the PerformOverrideUseCase.
class PerformOverrideParams extends Equatable {
  /// ID of the connected BLE device.
  final String deviceId;

  /// Device instance ID from the conflict (needed to add to paired devices).
  final String? deviceInstanceId;

  /// Device name for display in paired devices list.
  final String? deviceName;

  /// Current selected item's Firestore ID (from app UI state).
  /// If provided, this takes precedence over the last synced selection.
  final String? currentSelectedFirestoreId;

  const PerformOverrideParams({
    required this.deviceId,
    this.deviceInstanceId,
    this.deviceName,
    this.currentSelectedFirestoreId,
  });

  @override
  List<Object?> get props => [deviceId, deviceInstanceId, deviceName, currentSelectedFirestoreId];
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
    final newSyncSeq = user.syncSequenceNo + 1;

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

      // Keep the original selectedItemId - don't override with first item
      // The selection was already determined above based on lastSelectedDeviceItemId
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
      await _userRepository.addPairedDevice(
        PairedDevice(
          deviceInstanceId: params.deviceInstanceId!,
          deviceName: params.deviceName ?? 'Traxelos One',
          pairedAt: DateTime.now(),
        ),
      );
    }

    // Find the Firestore ID of the selected item
    String? selectedFirestoreId;
    if (selectedItemId >= 0) {
      final selectedItem = deviceItems.firstWhere(
        (i) => i.deviceItemId == selectedItemId,
        orElse: () => deviceItems.isNotEmpty ? deviceItems.first : deviceItems.first,
      );
      selectedFirestoreId = selectedItem.id;
    }

    return Right(SyncResult(
      type: SyncResultType.overrideComplete,
      selectedFirestoreId: selectedFirestoreId,
      selectedDeviceItemId: selectedItemId,
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
