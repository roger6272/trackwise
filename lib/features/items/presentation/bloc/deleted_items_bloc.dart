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
    emit(const DeletedItemsLoading());

    final result = await _repository.getDeletedItems(event.userId);

    result.fold(
      (failure) => emit(DeletedItemsError(message: failure.message)),
      (items) {
        _currentItems = items;
        emit(DeletedItemsLoaded(items: items));
      },
    );
  }

  Future<void> _onRestoreDeletedItem(
    RestoreDeletedItem event,
    Emitter<DeletedItemsState> emit,
  ) async {
    emit(ItemRestoring(itemId: event.itemId, items: _currentItems));

    final result = await _repository.restoreItem(event.itemId);

    result.fold(
      (failure) => emit(DeletedItemsError(message: failure.message)),
      (_) {
        // Remove the restored item from the list
        _currentItems = _currentItems
            .where((item) => item.id != event.itemId)
            .toList();
        emit(ItemRestored(itemId: event.itemId, remainingItems: _currentItems));
      },
    );
  }
}
