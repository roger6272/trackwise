import 'package:equatable/equatable.dart';

import '../../domain/entities/item.dart';

/// Base state class for Items BLoC.
///
/// All item-related states extend this class and use Equatable for value equality.
/// States represent the current status of the items feature in the UI.
abstract class ItemsState extends Equatable {
  const ItemsState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any items are loaded.
///
/// This is the starting state when the BLoC is first created.
/// The UI should show a placeholder or empty state.
class ItemsInitial extends ItemsState {}

/// Loading state while fetching or processing items.
///
/// Emitted during:
/// - Initial load (LoadItemsEvent)
/// - Setting up real-time updates (WatchItemsEvent)
/// - Creating new item (CreateItemEvent)
///
/// The UI should show a loading indicator.
class ItemsLoading extends ItemsState {}

/// Success state with loaded items.
///
/// Contains the list of items and a flag indicating whether real-time
/// updates are active.
///
/// The isWatching flag is used to:
/// - Show real-time indicator in UI
/// - Determine reload behavior after mutations
/// - Decide whether to use optimistic updates
class ItemsLoaded extends ItemsState {
  /// List of all items for the current user (unfiltered)
  final List<Item> items;

  /// True if subscribed to Firestore real-time updates via WatchItemsUseCase
  final bool isWatching;

  /// Currently selected category filter.
  /// - null: Show all items (sorted by global order)
  /// - '': Show uncategorized items only
  /// - categoryId: Show items in that category (sorted by categoryOrder)
  final String? selectedCategoryId;

  const ItemsLoaded(
    this.items, {
    this.isWatching = false,
    this.selectedCategoryId,
  });

  /// Returns filtered items based on selectedCategoryId.
  List<Item> get filteredItems {
    if (selectedCategoryId == null) {
      // All items, grouped by category, sorted by categoryOrder within each group
      final sorted = List<Item>.from(items);
      sorted.sort((a, b) {
        // First sort by categoryId (null/empty categories go last)
        final catA = a.categoryId ?? '';
        final catB = b.categoryId ?? '';
        if (catA != catB) {
          if (catA.isEmpty) return 1; // Uncategorized last
          if (catB.isEmpty) return -1;
          return catA.compareTo(catB);
        }
        // Within same category, sort by categoryOrder
        return a.categoryOrder.compareTo(b.categoryOrder);
      });
      return sorted;
    } else if (selectedCategoryId == '') {
      // Uncategorized items only, sorted by categoryOrder
      return List<Item>.from(items.where((item) => item.categoryId == null))
        ..sort((a, b) => a.categoryOrder.compareTo(b.categoryOrder));
    } else {
      // Items in specific category, sorted by categoryOrder
      return List<Item>.from(
          items.where((item) => item.categoryId == selectedCategoryId))
        ..sort((a, b) => a.categoryOrder.compareTo(b.categoryOrder));
    }
  }

  /// Returns true if currently viewing a specific category (not "All")
  bool get isFilteredByCategory => selectedCategoryId != null;

  @override
  List<Object?> get props => [items, isWatching, selectedCategoryId];

  /// Create a copy with updated fields.
  ///
  /// Useful for partial state updates without reloading from Firestore.
  ///
  /// Example:
  /// ```dart
  /// // Update only isWatching flag
  /// final newState = currentState.copyWith(isWatching: false);
  ///
  /// // Update items list
  /// final newState = currentState.copyWith(items: updatedItems);
  ///
  /// // Filter by category
  /// final newState = currentState.copyWith(selectedCategoryId: 'cat_123');
  /// ```
  ItemsLoaded copyWith({
    List<Item>? items,
    bool? isWatching,
    String? selectedCategoryId,
    bool clearCategoryFilter = false,
  }) {
    return ItemsLoaded(
      items ?? this.items,
      isWatching: isWatching ?? this.isWatching,
      selectedCategoryId:
          clearCategoryFilter ? null : (selectedCategoryId ?? this.selectedCategoryId),
    );
  }
}

/// Error state with failure message.
///
/// Emitted when:
/// - Firestore operation fails (ServerFailure)
/// - Validation fails (ValidationFailure)
/// - Stream emits error
///
/// The UI should display the error message to the user.
class ItemsError extends ItemsState {
  /// Human-readable error message extracted from Failure.message
  final String message;

  const ItemsError(this.message);

  @override
  List<Object?> get props => [message];
}
