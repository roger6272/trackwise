import 'package:equatable/equatable.dart';

import '../../domain/entities/category.dart';

/// Base class for all category events.
abstract class CategoriesEvent extends Equatable {
  const CategoriesEvent();

  @override
  List<Object?> get props => [];
}

/// Event to start watching categories for real-time updates.
class WatchCategoriesEvent extends CategoriesEvent {
  final String userId;

  const WatchCategoriesEvent(this.userId);

  @override
  List<Object?> get props => [userId];
}

/// Event to stop watching categories.
class StopWatchingCategoriesEvent extends CategoriesEvent {
  const StopWatchingCategoriesEvent();
}

/// Internal event when categories are updated from the stream.
class CategoriesUpdatedEvent extends CategoriesEvent {
  final List<Category> categories;

  const CategoriesUpdatedEvent(this.categories);

  @override
  List<Object?> get props => [categories];
}

/// Event to create a new category.
class CreateCategoryEvent extends CategoriesEvent {
  final String name;
  final String userId;

  const CreateCategoryEvent({
    required this.name,
    required this.userId,
  });

  @override
  List<Object?> get props => [name, userId];
}

/// Event to update an existing category.
class UpdateCategoryEvent extends CategoriesEvent {
  final Category category;

  const UpdateCategoryEvent(this.category);

  @override
  List<Object?> get props => [category];
}

/// Event to delete a category.
class DeleteCategoryEvent extends CategoriesEvent {
  final String categoryId;

  const DeleteCategoryEvent(this.categoryId);

  @override
  List<Object?> get props => [categoryId];
}

/// Event to reorder categories.
class ReorderCategoriesEvent extends CategoriesEvent {
  final int oldIndex;
  final int newIndex;

  const ReorderCategoriesEvent({
    required this.oldIndex,
    required this.newIndex,
  });

  @override
  List<Object?> get props => [oldIndex, newIndex];
}
