import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/utils/logger.dart';
import '../../../auth/domain/repositories/user_repository.dart';
import '../../../categories/domain/repositories/category_repository.dart';
import '../../../items/domain/entities/item.dart';
import '../../../items/domain/repositories/item_repository.dart';
import '../repositories/bluetooth_repository.dart';

/// Fetches items from Firestore, filters by category + claims, and pushes
/// to a specific device. Used after handshake, claim changes, and claim
/// failures to keep each device's item list correct.
@lazySingleton
class RefreshDeviceItemsUseCase {
  final ItemRepository _itemRepository;
  final CategoryRepository _categoryRepository;
  final BluetoothRepository _bluetoothRepository;
  final UserRepository _userRepository;

  RefreshDeviceItemsUseCase(
    this._itemRepository,
    this._categoryRepository,
    this._bluetoothRepository,
    this._userRepository,
  );

  Future<Either<Failure, RefreshDeviceItemsResult>> call(RefreshDeviceItemsParams params) async {
    // 1. Get current user
    final userResult = await _userRepository.getCurrentUser();
    if (userResult.isLeft()) {
      return userResult.fold(
        (f) => Left(f),
        (_) => const Left(ServerFailure('Failed to get user')),
      );
    }
    final user = userResult.getOrElse(() => throw StateError('User should exist'));

    // 2. Fetch all items
    final itemsResult = await _itemRepository.getItems(user.id);
    if (itemsResult.isLeft()) {
      return itemsResult.fold(
        (f) => Left(f),
        (_) => const Left(ServerFailure('Failed to fetch items')),
      );
    }
    final allItems = itemsResult.getOrElse(() => []);

    // 3. Filter to synced items (have deviceItemId)
    final syncedItems = allItems.where((i) => i.deviceItemId != null).toList();

    // 4. Find selected item to determine category
    Item? selectedItem;
    if (params.selectedItemId != null) {
      selectedItem = syncedItems.cast<Item?>().firstWhere(
        (i) => i?.id == params.selectedItemId,
        orElse: () => null,
      );
    }
    // Fall back to device's current claim (reconnection — device had an item selected)
    selectedItem ??= syncedItems.cast<Item?>().firstWhere(
      (i) => i?.claimedBy == params.deviceInstanceId,
      orElse: () => null,
    );
    // Fall back to first synced item if no selection
    selectedItem ??= syncedItems.isNotEmpty ? syncedItems.first : null;

    // 5. Filter by category
    final categoryId = selectedItem?.categoryId ?? '';
    var deviceItems = syncedItems.where((i) =>
      (i.categoryId ?? '') == categoryId).toList();

    // 6. CLAIM FILTER — only unclaimed items or items claimed by this device
    deviceItems = deviceItems.where((i) =>
      i.claimedBy == null || i.claimedBy == params.deviceInstanceId
    ).toList();

    // 7. Sort by categoryOrder
    deviceItems.sort((a, b) => a.categoryOrder.compareTo(b.categoryOrder));

    // 8. Validate selected item is still in claim-filtered list
    // If the selected item was claimed by another device, redirect to first available
    if (selectedItem != null && !deviceItems.any((i) => i.id == selectedItem!.id)) {
      selectedItem = deviceItems.isNotEmpty ? deviceItems.first : null;
    }

    // 9. Build category names
    final categoryNames = await _buildCategoryNameMap(user.id);

    // 10. Send items to device
    AppLogger.debug('RefreshDeviceItems: sending ${deviceItems.length} items to ${params.deviceId}');
    final sendResult = await _bluetoothRepository.sendItems(
      params.deviceId, deviceItems, categoryNames: categoryNames);
    if (sendResult.isLeft()) {
      return sendResult.fold(
        (f) => Left(f),
        (_) => const Left(ServerFailure('Failed to send items')),
      );
    }

    // 11. Send selected item (or -1 if none available)
    if (selectedItem != null && selectedItem.deviceItemId != null) {
      await _bluetoothRepository.sendSelectedItem(
        params.deviceId, selectedItem.deviceItemId!);
    } else {
      await _bluetoothRepository.sendSelectedItem(params.deviceId, -1);
    }

    return Right(RefreshDeviceItemsResult(categoryId: categoryId));
  }

  /// Lightweight category lookup — determines which category a device is in
  /// based on its selected item, WITHOUT sending any BLE data.
  Future<Either<Failure, String>> resolveCategory(RefreshDeviceItemsParams params) async {
    final userResult = await _userRepository.getCurrentUser();
    if (userResult.isLeft()) {
      return userResult.fold(
        (f) => Left(f),
        (_) => const Left(ServerFailure('Failed to get user')),
      );
    }
    final user = userResult.getOrElse(() => throw StateError('User should exist'));

    final itemsResult = await _itemRepository.getItems(user.id);
    if (itemsResult.isLeft()) {
      return itemsResult.fold(
        (f) => Left(f),
        (_) => const Left(ServerFailure('Failed to fetch items')),
      );
    }
    final allItems = itemsResult.getOrElse(() => []);
    final syncedItems = allItems.where((i) => i.deviceItemId != null).toList();

    Item? selectedItem;
    if (params.selectedItemId != null) {
      selectedItem = syncedItems.cast<Item?>().firstWhere(
        (i) => i?.id == params.selectedItemId,
        orElse: () => null,
      );
    }
    selectedItem ??= syncedItems.cast<Item?>().firstWhere(
      (i) => i?.claimedBy == params.deviceInstanceId,
      orElse: () => null,
    );
    selectedItem ??= syncedItems.isNotEmpty ? syncedItems.first : null;

    return Right(selectedItem?.categoryId ?? '');
  }

  Future<Map<String, String>> _buildCategoryNameMap(String userId) async {
    final result = await _categoryRepository.getCategories(userId);
    return result.fold(
      (_) => <String, String>{},
      (cats) => {for (final c in cats) c.id: c.name},
    );
  }
}

/// Parameters for [RefreshDeviceItemsUseCase].
class RefreshDeviceItemsParams extends Equatable {
  /// BLE transport ID (used for sendItems/sendSelectedItem).
  final String deviceId;

  /// Device instance ID (used for claim filtering).
  final String deviceInstanceId;

  /// Firestore ID of the selected item (determines which category to push).
  final String? selectedItemId;

  const RefreshDeviceItemsParams({
    required this.deviceId,
    required this.deviceInstanceId,
    this.selectedItemId,
  });

  @override
  List<Object?> get props => [deviceId, deviceInstanceId, selectedItemId];
}

/// Result of [RefreshDeviceItemsUseCase], including the resolved category.
class RefreshDeviceItemsResult {
  /// The category ID that was pushed to the device.
  final String categoryId;

  const RefreshDeviceItemsResult({required this.categoryId});
}
