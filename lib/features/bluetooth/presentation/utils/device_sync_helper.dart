import '../../../items/domain/entities/item.dart';
import '../bloc/bluetooth_bloc.dart';
import '../bloc/bluetooth_event.dart';

/// Filters items to the device-selected category and sends them to the device.
///
/// This is the single place that decides which items reach the device.
/// Every caller (items list, profile reset, deleted-items restore) must go
/// through here so the device always receives a consistent, category-filtered
/// item list.
void syncItemsToDevice({
  required BluetoothBloc bluetoothBloc,
  required List<Item> allItems,
  required String? deviceSelectedId,
  required Map<String, String> categoryNames,
  String? excludeItemId,
  Item? includeItem,
  String? fallbackCategoryId,
  String? deviceInstanceId,
}) {
  final resolvedDeviceInstanceId =
      deviceInstanceId ?? bluetoothBloc.state.connectedDeviceInstanceId ?? '';
  // Find the selected item and its category
  String? selectedCategoryId;
  Item? selectedItem;
  if (deviceSelectedId != null && deviceSelectedId != 'none') {
    selectedItem =
        allItems.where((i) => i.id == deviceSelectedId).firstOrNull;
    selectedCategoryId = selectedItem?.categoryId;
  } else if (fallbackCategoryId != null) {
    selectedCategoryId = fallbackCategoryId;
  }

  // Get items from the selected item's category
  var categoryItems = allItems.where((i) {
    final cat = i.categoryId;
    final targetCat = selectedCategoryId;
    // Match category (treat null and empty as same - uncategorized)
    final catEmpty = cat == null || cat.isEmpty;
    final targetEmpty = targetCat == null || targetCat.isEmpty;
    if (catEmpty && targetEmpty) return true;
    if (catEmpty || targetEmpty) return false;
    return cat == targetCat;
  }).toList();

  // Exclude item if specified (for delete)
  if (excludeItemId != null) {
    categoryItems =
        categoryItems.where((i) => i.id != excludeItemId).toList();
  }

  // Include/update item if specified (for create/update/restore)
  // Only add if the item belongs to the selected category
  if (includeItem != null) {
    final inclCat = includeItem.categoryId;
    final targetCat = selectedCategoryId;
    final inclEmpty = inclCat == null || inclCat.isEmpty;
    final targetEmpty = targetCat == null || targetCat.isEmpty;
    final sameCategory = (inclEmpty && targetEmpty) ||
        (!inclEmpty && !targetEmpty && inclCat == targetCat);

    if (sameCategory) {
      categoryItems = categoryItems
          .map((i) => i.id == includeItem.id ? includeItem : i)
          .toList();
      if (!categoryItems.any((i) => i.id == includeItem.id)) {
        categoryItems.add(includeItem);
      }
    }
  }

  // Sort by categoryOrder to match app's order
  categoryItems.sort((a, b) => a.categoryOrder.compareTo(b.categoryOrder));

  bluetoothBloc.add(SendItemsToDevice(
    categoryItems,
    deviceInstanceId: resolvedDeviceInstanceId,
    categoryNames: categoryNames,
  ));

  // Update selected item on device (including 'none' to clear selection)
  if (deviceSelectedId != null) {
    final deviceItemId =
        (deviceSelectedId == 'none' || selectedItem == null)
            ? -1
            : selectedItem.deviceItemId ?? 0;
    bluetoothBloc.add(SendSelectedItem(
      deviceSelectedId,
      deviceItemId,
      deviceInstanceId: resolvedDeviceInstanceId,
    ));
  }
}
