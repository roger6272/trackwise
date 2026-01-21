import 'package:equatable/equatable.dart';

import '../../domain/entities/item.dart';

/// Base event class for Items BLoC.
///
/// All item-related events extend this class and use Equatable for value equality.
/// Events represent user actions that trigger BLoC state changes.
abstract class ItemsEvent extends Equatable {
  const ItemsEvent();

  @override
  List<Object?> get props => [];
}

/// Event to load items once from Firestore.
///
/// Uses GetItemsUseCase to fetch items for a specific user.
/// Emits ItemsLoading, then either ItemsLoaded or ItemsError.
///
/// Example:
/// ```dart
/// bloc.add(LoadItemsEvent('user_123'));
/// ```
class LoadItemsEvent extends ItemsEvent {
  final String userId;

  const LoadItemsEvent(this.userId);

  @override
  List<Object?> get props => [userId];
}

/// Event to subscribe to real-time item updates.
///
/// Uses WatchItemsUseCase to create a Firestore snapshot listener.
/// The BLoC will emit ItemsLoaded(isWatching: true) whenever data changes.
///
/// Automatically cancels any previous subscription before creating a new one.
///
/// Example:
/// ```dart
/// bloc.add(WatchItemsEvent('user_123'));
/// ```
class WatchItemsEvent extends ItemsEvent {
  final String userId;

  const WatchItemsEvent(this.userId);

  @override
  List<Object?> get props => [userId];
}

/// Event to stop watching real-time updates.
///
/// Cancels the Firestore snapshot listener and updates isWatching flag to false.
/// Items remain in the loaded state.
///
/// Example:
/// ```dart
/// bloc.add(StopWatchingItemsEvent());
/// ```
class StopWatchingItemsEvent extends ItemsEvent {}

/// Event to create a new item.
///
/// Uses CreateItemUseCase with validation. The repository will generate
/// the item ID.
///
/// After successful creation:
/// - If watching: Stream will automatically emit updated list
/// - If not watching: Manually reloads items
///
/// Example:
/// ```dart
/// bloc.add(CreateItemEvent(
///   name: 'Coffee',
///   initialValue: 0,
///   incrementBy: 1,
///   reminder: ReminderType.target,
///   reminderValue: 20,
///   userId: 'user_123',
/// ));
/// ```
class CreateItemEvent extends ItemsEvent {
  final String name;
  final int initialValue;
  final int incrementBy;
  final ReminderType reminder;
  final int reminderValue;
  final String userId;

  const CreateItemEvent({
    required this.name,
    this.initialValue = 0,
    required this.incrementBy,
    required this.reminder,
    required this.reminderValue,
    required this.userId,
  });

  @override
  List<Object?> get props => [name, initialValue, incrementBy, reminder, reminderValue, userId];
}

/// Event to update an existing item.
///
/// Uses UpdateItemUseCase with validation. Updates are optimistic - the UI
/// shows the change immediately and reverts if the operation fails.
///
/// Example:
/// ```dart
/// final updatedItem = item.copyWith(name: 'New Name');
/// bloc.add(UpdateItemEvent(updatedItem));
/// ```
class UpdateItemEvent extends ItemsEvent {
  final Item item;

  const UpdateItemEvent(this.item);

  @override
  List<Object?> get props => [item];
}

/// Event to delete an item.
///
/// Uses DeleteItemUseCase which also deletes associated EventLog entries.
/// Deletion is optimistic - the item is removed from the UI immediately
/// and restored if the operation fails.
///
/// Warning: This operation is permanent and cannot be undone.
///
/// Example:
/// ```dart
/// bloc.add(DeleteItemEvent('item_123'));
/// ```
class DeleteItemEvent extends ItemsEvent {
  final String itemId;

  const DeleteItemEvent(this.itemId);

  @override
  List<Object?> get props => [itemId];
}

/// Event to increment an item's count.
///
/// Uses IncrementItemUseCase to increment both count and todayCount.
/// Increment is optimistic - the counts update immediately in the UI
/// and revert if the operation fails.
///
/// Example:
/// ```dart
/// // Increment by 1 (default)
/// bloc.add(IncrementItemEvent(itemId: 'item_123'));
///
/// // Increment by custom amount
/// bloc.add(IncrementItemEvent(itemId: 'item_123', amount: 5));
/// ```
class IncrementItemEvent extends ItemsEvent {
  final String itemId;
  final int amount;

  const IncrementItemEvent({
    required this.itemId,
    this.amount = 1,
  });

  @override
  List<Object?> get props => [itemId, amount];
}

/// Event to reorder items in the list.
///
/// Used for drag-to-reorder functionality. Handles moving an item from
/// one position to another.
///
/// Uses optimistic update: UI reorders immediately, then persists to Firestore.
/// Reverts on failure.
///
/// Example:
/// ```dart
/// // Move item from index 2 to index 0
/// bloc.add(ReorderItemsEvent(oldIndex: 2, newIndex: 0));
/// ```
class ReorderItemsEvent extends ItemsEvent {
  final int oldIndex;
  final int newIndex;

  const ReorderItemsEvent({
    required this.oldIndex,
    required this.newIndex,
  });

  @override
  List<Object?> get props => [oldIndex, newIndex];
}

/// Event to filter items by category.
///
/// Sets the selected category filter for the items list.
/// - null: Show all items (sorted by global order)
/// - '': Show uncategorized items only
/// - categoryId: Show items in that category (sorted by categoryOrder)
///
/// The filter is applied client-side on the already-watched items.
///
/// Example:
/// ```dart
/// // Show all items
/// bloc.add(FilterByCategoryEvent(null));
///
/// // Show uncategorized items
/// bloc.add(FilterByCategoryEvent(''));
///
/// // Show items in a specific category
/// bloc.add(FilterByCategoryEvent('category_123'));
/// ```
class FilterByCategoryEvent extends ItemsEvent {
  final String? categoryId;

  const FilterByCategoryEvent(this.categoryId);

  @override
  List<Object?> get props => [categoryId];
}

/// Event to reorder items within a category.
///
/// Similar to ReorderItemsEvent but updates categoryOrder instead of order.
/// Used when viewing items filtered by a specific category.
/// Uses the current selectedCategoryId from state to determine which items to reorder.
///
/// Example:
/// ```dart
/// bloc.add(ReorderItemsInCategoryEvent(
///   oldIndex: 2,
///   newIndex: 0,
/// ));
/// ```
class ReorderItemsInCategoryEvent extends ItemsEvent {
  final int oldIndex;
  final int newIndex;

  const ReorderItemsInCategoryEvent({
    required this.oldIndex,
    required this.newIndex,
  });

  @override
  List<Object?> get props => [oldIndex, newIndex];
}
