import 'package:equatable/equatable.dart';

/// Events for the DeletedItemsBloc.
abstract class DeletedItemsEvent extends Equatable {
  const DeletedItemsEvent();

  @override
  List<Object?> get props => [];
}

/// Load all soft-deleted items for the current user.
class LoadDeletedItems extends DeletedItemsEvent {
  final String userId;

  const LoadDeletedItems({required this.userId});

  @override
  List<Object?> get props => [userId];
}

/// Restore a soft-deleted item.
class RestoreDeletedItem extends DeletedItemsEvent {
  final String itemId;
  final String userId;

  const RestoreDeletedItem({required this.itemId, required this.userId});

  @override
  List<Object?> get props => [itemId, userId];
}
