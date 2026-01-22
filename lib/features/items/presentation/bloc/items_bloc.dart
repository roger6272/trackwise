import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/item.dart';
import '../../domain/repositories/item_repository.dart';
import '../../domain/usecases/create_item_usecase.dart';
import '../../domain/usecases/delete_item_usecase.dart';
import '../../domain/usecases/get_items_usecase.dart';
import '../../domain/usecases/increment_item_usecase.dart';
import '../../domain/usecases/update_item_usecase.dart';
import '../../domain/usecases/watch_items_usecase.dart';
import 'items_event.dart';
import 'items_state.dart';

/// BLoC for managing Items feature state.
///
/// Handles all item-related user actions (events) and emits appropriate states.
/// Uses domain layer use cases to interact with the repository.
///
/// Features:
/// - Load items once or watch for real-time updates
/// - Create, update, delete items
/// - Increment item counts
/// - Optimistic updates for better UX
/// - Stream subscription management
///
/// Registered as factory in GetIt so each screen gets its own instance.
@injectable
class ItemsBloc extends Bloc<ItemsEvent, ItemsState> {
  final GetItemsUseCase getItemsUseCase;
  final WatchItemsUseCase watchItemsUseCase;
  final CreateItemUseCase createItemUseCase;
  final UpdateItemUseCase updateItemUseCase;
  final DeleteItemUseCase deleteItemUseCase;
  final IncrementItemUseCase incrementItemUseCase;
  final ItemRepository itemRepository;

  StreamSubscription? _itemsSubscription;

  ItemsBloc({
    required this.getItemsUseCase,
    required this.watchItemsUseCase,
    required this.createItemUseCase,
    required this.updateItemUseCase,
    required this.deleteItemUseCase,
    required this.incrementItemUseCase,
    required this.itemRepository,
  }) : super(ItemsInitial()) {
    on<LoadItemsEvent>(_onLoadItems);
    on<WatchItemsEvent>(_onWatchItems);
    on<StopWatchingItemsEvent>(_onStopWatchingItems);
    on<CreateItemEvent>(_onCreateItem);
    on<UpdateItemEvent>(_onUpdateItem);
    on<DeleteItemEvent>(_onDeleteItem);
    on<IncrementItemEvent>(_onIncrementItem);
    on<ReorderItemsEvent>(_onReorderItems);
    on<FilterByCategoryEvent>(_onFilterByCategory);
    on<ReorderItemsInCategoryEvent>(_onReorderItemsInCategory);
  }

  /// Handle LoadItemsEvent - fetch items once.
  ///
  /// Emits:
  /// 1. ItemsLoading - while fetching
  /// 2. ItemsLoaded - on success
  /// 3. ItemsError - on failure
  Future<void> _onLoadItems(
    LoadItemsEvent event,
    Emitter<ItemsState> emit,
  ) async {
    emit(ItemsLoading());

    final result = await getItemsUseCase(GetItemsParams(event.userId));

    result.fold(
      (failure) => emit(ItemsError(failure.message)),
      (items) => emit(ItemsLoaded(items)),
    );
  }

  /// Handle WatchItemsEvent - subscribe to real-time updates.
  ///
  /// Cancels any existing subscription before creating a new one.
  /// The stream will emit ItemsLoaded whenever Firestore data changes.
  /// Preserves the current category filter when items update.
  ///
  /// If [event.initialCategoryId] is provided, it will be used as the initial
  /// category filter (useful for restoring state after navigation).
  ///
  /// Emits:
  /// 1. ItemsLoading - while setting up subscription
  /// 2. ItemsLoaded(isWatching: true) - on each stream update
  /// 3. ItemsError - on stream error
  Future<void> _onWatchItems(
    WatchItemsEvent event,
    Emitter<ItemsState> emit,
  ) async {
    // Cancel existing subscription if any
    await _itemsSubscription?.cancel();

    // Use event's initialCategoryId if provided, otherwise preserve current filter
    final initialCategoryId = event.initialCategoryId ??
        (state is ItemsLoaded ? (state as ItemsLoaded).selectedCategoryId : null);

    emit(ItemsLoading());

    // Subscribe to the stream using emit.onEach (non-blocking)
    await emit.onEach<Either<Failure, List<Item>>>(
      watchItemsUseCase(GetItemsParams(event.userId)),
      onData: (Either<Failure, List<Item>> either) {
        // Get current category filter from state (may have changed since watch started)
        final currentCategoryId = state is ItemsLoaded
            ? (state as ItemsLoaded).selectedCategoryId
            : initialCategoryId;

        either.fold(
          (failure) => emit(ItemsError(failure.message)),
          (items) => emit(ItemsLoaded(
            items,
            isWatching: true,
            selectedCategoryId: currentCategoryId,
          )),
        );
      },
    );
  }

  /// Handle StopWatchingItemsEvent - unsubscribe from real-time updates.
  ///
  /// Cancels the stream subscription and updates isWatching flag to false.
  /// Items remain in the loaded state.
  Future<void> _onStopWatchingItems(
    StopWatchingItemsEvent event,
    Emitter<ItemsState> emit,
  ) async {
    await _itemsSubscription?.cancel();
    _itemsSubscription = null;

    // Keep current items but mark as not watching
    final currentState = state;
    if (currentState is ItemsLoaded) {
      emit(currentState.copyWith(isWatching: false));
    }
  }

  /// Handle CreateItemEvent - create new item.
  ///
  /// Uses CreateItemUseCase which validates and creates the item in Firestore.
  /// The repository generates the item ID and sets initial counts to 0.
  ///
  /// Reload behavior:
  /// - If watching: Stream will automatically update (no manual reload)
  /// - If not watching: Manually reloads items with LoadItemsEvent
  ///
  /// Emits:
  /// 1. ItemsLoading - while creating
  /// 2. Triggers LoadItemsEvent on success (if not watching)
  /// 3. ItemsError - on failure
  Future<void> _onCreateItem(
    CreateItemEvent event,
    Emitter<ItemsState> emit,
  ) async {
    final currentState = state;

    // Show loading
    emit(ItemsLoading());

    final result = await createItemUseCase(CreateItemParams(
      name: event.name,
      initialValue: event.initialValue,
      incrementBy: event.incrementBy,
      reminder: event.reminder,
      reminderValue: event.reminderValue,
      userId: event.userId,
    ));

    result.fold(
      (failure) => emit(ItemsError(failure.message)),
      (createdItem) {
        // If we were watching, the stream will update automatically
        // If not, reload manually
        if (currentState is ItemsLoaded && currentState.isWatching) {
          // Stream will handle update, keep loading state briefly
          // The stream subscription will emit ItemsLoaded with updated items
        } else {
          // Reload items manually
          add(LoadItemsEvent(event.userId));
        }
      },
    );
  }

  /// Handle UpdateItemEvent - update existing item.
  ///
  /// Uses optimistic update: Shows the change immediately in the UI
  /// and reverts if the operation fails. This provides better UX.
  ///
  /// Update strategy:
  /// - If watching: Stream will provide authoritative update from server
  /// - If not watching: Keep optimistic update
  ///
  /// Emits:
  /// 1. ItemsLoaded with updated item - optimistic update
  /// 2. Previous state + ItemsError - if update fails
  /// 3. ItemsLoaded with updated item - if not watching and success
  Future<void> _onUpdateItem(
    UpdateItemEvent event,
    Emitter<ItemsState> emit,
  ) async {
    final currentState = state;

    if (currentState is ItemsLoaded) {
      // Optimistic update: show updated item immediately
      final updatedItems = currentState.items.map((item) {
        return item.id == event.item.id ? event.item : item;
      }).toList();

      emit(ItemsLoaded(updatedItems, isWatching: currentState.isWatching));

      // Perform actual update
      final result = await updateItemUseCase(UpdateItemParams(event.item));

      result.fold(
        (failure) {
          // Revert on error
          emit(currentState);
          emit(ItemsError(failure.message));
        },
        (_) {
          // If watching, stream will update
          // If not, keep optimistic update
          if (!currentState.isWatching) {
            emit(ItemsLoaded(updatedItems, isWatching: false));
          }
        },
      );
    }
  }

  /// Handle DeleteItemEvent - delete item.
  ///
  /// Uses optimistic delete: Removes the item immediately from the UI
  /// and restores it if the operation fails.
  ///
  /// Also deletes associated EventLog entries in Firestore.
  ///
  /// Delete strategy:
  /// - If watching: Stream will provide authoritative update from server
  /// - If not watching: Keep optimistic delete
  ///
  /// Emits:
  /// 1. ItemsLoaded without deleted item - optimistic delete
  /// 2. Previous state + ItemsError - if delete fails
  /// 3. ItemsLoaded without deleted item - if not watching and success
  Future<void> _onDeleteItem(
    DeleteItemEvent event,
    Emitter<ItemsState> emit,
  ) async {
    final currentState = state;

    if (currentState is ItemsLoaded) {
      // Optimistic delete: remove from list immediately
      final updatedItems = currentState.items
          .where((item) => item.id != event.itemId)
          .toList();

      emit(ItemsLoaded(updatedItems, isWatching: currentState.isWatching));

      // Perform actual delete
      final result = await deleteItemUseCase(DeleteItemParams(event.itemId));

      result.fold(
        (failure) {
          // Revert on error
          emit(currentState);
          emit(ItemsError(failure.message));
        },
        (_) {
          // If watching, stream will update
          // If not, keep optimistic delete
          if (!currentState.isWatching) {
            emit(ItemsLoaded(updatedItems, isWatching: false));
          }
        },
      );
    }
  }

  /// Handle IncrementItemEvent - increment item count.
  ///
  /// Uses optimistic increment: Updates count and todayCount immediately
  /// in the UI and reverts if the operation fails.
  ///
  /// Increment strategy:
  /// - If watching: Stream will provide authoritative update from server
  /// - If not watching: Use the returned item from server (more accurate)
  ///
  /// Emits:
  /// 1. ItemsLoaded with incremented count - optimistic increment
  /// 2. Previous state + ItemsError - if increment fails
  /// 3. ItemsLoaded with server item - if not watching and success
  Future<void> _onIncrementItem(
    IncrementItemEvent event,
    Emitter<ItemsState> emit,
  ) async {
    final currentState = state;

    if (currentState is ItemsLoaded) {
      // Optimistic increment: update count immediately
      final updatedItems = currentState.items.map((item) {
        if (item.id == event.itemId) {
          return item.copyWith(
            count: item.count + event.amount,
            todayCount: item.todayCount + event.amount,
          );
        }
        return item;
      }).toList();

      emit(ItemsLoaded(updatedItems, isWatching: currentState.isWatching));

      // Perform actual increment
      final result = await incrementItemUseCase(IncrementItemParams(
        itemId: event.itemId,
        amount: event.amount,
      ));

      result.fold(
        (failure) {
          // Revert on error
          emit(currentState);
          emit(ItemsError(failure.message));
        },
        (updatedItem) {
          // If watching, stream will update with server data
          // If not, use the returned item from server
          if (!currentState.isWatching) {
            final serverUpdatedItems = currentState.items.map((item) {
              return item.id == updatedItem.id ? updatedItem : item;
            }).toList();
            emit(ItemsLoaded(serverUpdatedItems, isWatching: false));
          }
        },
      );
    }
  }

  /// Handle ReorderItemsEvent - reorder items in the list.
  ///
  /// Uses optimistic reorder: Updates the list immediately in the UI
  /// and reverts if the Firestore operation fails.
  ///
  /// Emits:
  /// 1. ItemsLoaded with reordered list - optimistic reorder
  /// 2. Previous state + ItemsError - if reorder fails
  Future<void> _onReorderItems(
    ReorderItemsEvent event,
    Emitter<ItemsState> emit,
  ) async {
    final currentState = state;

    if (currentState is ItemsLoaded) {
      // Calculate the actual new index (Flutter's ReorderableListView behavior)
      int newIndex = event.newIndex;
      if (event.oldIndex < newIndex) {
        newIndex -= 1;
      }

      // Skip if no actual change
      if (event.oldIndex == newIndex) return;

      // Optimistic reorder: reorder list immediately
      final reorderedItems = List<Item>.from(currentState.items);
      final movedItem = reorderedItems.removeAt(event.oldIndex);
      reorderedItems.insert(newIndex, movedItem);

      // Update order field for each item
      final updatedItems = reorderedItems.asMap().entries.map((entry) {
        return entry.value.copyWith(order: entry.key);
      }).toList();

      emit(ItemsLoaded(updatedItems, isWatching: currentState.isWatching));

      // Persist to Firestore
      final result = await itemRepository.reorderItems(updatedItems);

      result.fold(
        (failure) {
          // Revert on error
          debugPrint('❌ Failed to reorder items: ${failure.message}');
          emit(currentState);
          emit(ItemsError(failure.message));
        },
        (_) {
          debugPrint('✅ Items reordered successfully');
          // If watching, stream will confirm the update
          // If not, keep optimistic reorder
          if (!currentState.isWatching) {
            emit(ItemsLoaded(updatedItems, isWatching: false));
          }
        },
      );
    }
  }

  /// Handle FilterByCategoryEvent - filter items by category.
  ///
  /// Updates the selectedCategoryId in the state.
  /// Filtering is done client-side via ItemsLoaded.filteredItems getter.
  ///
  /// Emits:
  /// ItemsLoaded with updated selectedCategoryId
  void _onFilterByCategory(
    FilterByCategoryEvent event,
    Emitter<ItemsState> emit,
  ) {
    final currentState = state;

    if (currentState is ItemsLoaded) {
      if (event.categoryId == null) {
        emit(currentState.copyWith(clearCategoryFilter: true));
      } else {
        emit(currentState.copyWith(selectedCategoryId: event.categoryId));
      }
    }
  }

  /// Handle ReorderItemsInCategoryEvent - reorder items within a category.
  ///
  /// Updates the categoryOrder field for items in the category.
  /// Uses optimistic update: UI reorders immediately, then persists to Firestore.
  ///
  /// Emits:
  /// 1. ItemsLoaded with reordered items - optimistic reorder
  /// 2. Previous state + ItemsError - if reorder fails
  Future<void> _onReorderItemsInCategory(
    ReorderItemsInCategoryEvent event,
    Emitter<ItemsState> emit,
  ) async {
    final currentState = state;

    if (currentState is ItemsLoaded) {
      // Get items in the current category view
      final categoryItems = currentState.filteredItems;

      // Calculate the actual new index (Flutter's ReorderableListView behavior)
      int newIndex = event.newIndex;
      if (event.oldIndex < newIndex) {
        newIndex -= 1;
      }

      // Skip if no actual change
      if (event.oldIndex == newIndex) return;

      // Optimistic reorder in category
      final reorderedCategoryItems = List<Item>.from(categoryItems);
      final movedItem = reorderedCategoryItems.removeAt(event.oldIndex);
      reorderedCategoryItems.insert(newIndex, movedItem);

      // Update categoryOrder field for each item in the category
      final updatedCategoryItems = reorderedCategoryItems.asMap().entries.map((entry) {
        return entry.value.copyWith(categoryOrder: entry.key);
      }).toList();

      // Update the full items list with the new categoryOrders
      final updatedItems = currentState.items.map((item) {
        final updatedItem = updatedCategoryItems.firstWhere(
          (ui) => ui.id == item.id,
          orElse: () => item,
        );
        return updatedItem.id == item.id ? updatedItem : item;
      }).toList();

      emit(currentState.copyWith(items: updatedItems));

      // Persist to Firestore
      final result = await itemRepository.reorderItemsInCategory(updatedCategoryItems);

      result.fold(
        (failure) {
          // Revert on error
          debugPrint('❌ Failed to reorder items in category: ${failure.message}');
          emit(currentState);
          emit(ItemsError(failure.message));
        },
        (_) {
          debugPrint('✅ Items reordered in category successfully');
          // If watching, stream will confirm the update
          // If not, keep optimistic reorder
          if (!currentState.isWatching) {
            emit(currentState.copyWith(items: updatedItems));
          }
        },
      );
    }
  }

  @override
  Future<void> close() {
    _itemsSubscription?.cancel();
    return super.close();
  }
}
