import 'package:equatable/equatable.dart';

import '../../domain/entities/item.dart';

/// States for the DeletedItemsBloc.
abstract class DeletedItemsState extends Equatable {
  const DeletedItemsState();

  @override
  List<Object?> get props => [];
}

/// Initial state before loading.
class DeletedItemsInitial extends DeletedItemsState {
  const DeletedItemsInitial();
}

/// Loading deleted items.
class DeletedItemsLoading extends DeletedItemsState {
  const DeletedItemsLoading();
}

/// Successfully loaded deleted items.
class DeletedItemsLoaded extends DeletedItemsState {
  final List<Item> items;

  const DeletedItemsLoaded({required this.items});

  @override
  List<Object?> get props => [items];
}

/// Error loading deleted items.
class DeletedItemsError extends DeletedItemsState {
  final String message;

  const DeletedItemsError({required this.message});

  @override
  List<Object?> get props => [message];
}

/// Item successfully restored.
class ItemRestored extends DeletedItemsState {
  final String itemId;
  final List<Item> remainingItems;

  const ItemRestored({required this.itemId, required this.remainingItems});

  @override
  List<Object?> get props => [itemId, remainingItems];
}

/// Restoring an item.
class ItemRestoring extends DeletedItemsState {
  final String itemId;
  final List<Item> items;

  const ItemRestoring({required this.itemId, required this.items});

  @override
  List<Object?> get props => [itemId, items];
}
