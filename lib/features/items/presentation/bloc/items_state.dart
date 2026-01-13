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
  /// List of items for the current user
  final List<Item> items;

  /// True if subscribed to Firestore real-time updates via WatchItemsUseCase
  final bool isWatching;

  const ItemsLoaded(this.items, {this.isWatching = false});

  @override
  List<Object?> get props => [items, isWatching];

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
  /// ```
  ItemsLoaded copyWith({
    List<Item>? items,
    bool? isWatching,
  }) {
    return ItemsLoaded(
      items ?? this.items,
      isWatching: isWatching ?? this.isWatching,
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
