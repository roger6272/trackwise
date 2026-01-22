import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/item.dart';
import '../../domain/repositories/item_repository.dart';
import 'deleted_items_event.dart';
import 'deleted_items_state.dart';

/// BLoC for managing soft-deleted items.
@injectable
class DeletedItemsBloc extends Bloc<DeletedItemsEvent, DeletedItemsState> {
  final ItemRepository _repository;
  List<Item> _currentItems = [];

  DeletedItemsBloc(this._repository) : super(const DeletedItemsInitial()) {
    on<LoadDeletedItems>(_onLoadDeletedItems);
    on<RestoreDeletedItem>(_onRestoreDeletedItem);
  }

  Future<void> _onLoadDeletedItems(
    LoadDeletedItems event,
    Emitter<DeletedItemsState> emit,
  ) async {
    debugPrint('🗑️ DeletedItemsBloc: Loading deleted items for user ${event.userId}');
    emit(const DeletedItemsLoading());

    final result = await _repository.getDeletedItems(event.userId);

    result.fold(
      (failure) {
        debugPrint('🗑️ DeletedItemsBloc: Error - ${failure.message}');
        emit(DeletedItemsError(message: failure.message));
      },
      (items) {
        debugPrint('🗑️ DeletedItemsBloc: Loaded ${items.length} deleted items');
        // Sort by deletedAt descending (most recently deleted first)
        items.sort((a, b) {
          final aDeleted = a.deletedAt ?? DateTime(1970);
          final bDeleted = b.deletedAt ?? DateTime(1970);
          return bDeleted.compareTo(aDeleted);
        });
        _currentItems = items;
        emit(DeletedItemsLoaded(items: items));
      },
    );
  }

  Future<void> _onRestoreDeletedItem(
    RestoreDeletedItem event,
    Emitter<DeletedItemsState> emit,
  ) async {
    debugPrint('🗑️ DeletedItemsBloc: Restoring item ${event.itemId}');
    emit(ItemRestoring(itemId: event.itemId, items: _currentItems));

    try {
      final result = await _repository.restoreItem(event.itemId);

      result.fold(
        (failure) {
          debugPrint('🗑️ DeletedItemsBloc: Restore failed - ${failure.message}');
          emit(DeletedItemsError(message: failure.message));
          // Re-emit loaded state so UI doesn't stay in error state
          emit(DeletedItemsLoaded(items: _currentItems));
        },
        (_) {
          debugPrint('🗑️ DeletedItemsBloc: Item restored successfully');
          // Remove the restored item from the list
          _currentItems = _currentItems
              .where((item) => item.id != event.itemId)
              .toList();
          emit(ItemRestored(itemId: event.itemId, remainingItems: _currentItems));
          // Re-emit loaded state so UI properly transitions out of restoring state
          emit(DeletedItemsLoaded(items: _currentItems));
        },
      );
    } catch (e, stackTrace) {
      debugPrint('🗑️ DeletedItemsBloc: Unexpected error - $e');
      debugPrint('🗑️ StackTrace: $stackTrace');
      emit(DeletedItemsError(message: 'Failed to restore item: $e'));
      // Re-emit loaded state so UI doesn't stay in error/loading state
      emit(DeletedItemsLoaded(items: _currentItems));
    }
  }
}
