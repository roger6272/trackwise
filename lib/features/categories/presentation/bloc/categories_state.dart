import 'package:equatable/equatable.dart';

import '../../domain/entities/category.dart';

/// Base class for all category states.
abstract class CategoriesState extends Equatable {
  const CategoriesState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any action is taken.
class CategoriesInitial extends CategoriesState {
  const CategoriesInitial();
}

/// State while loading categories.
class CategoriesLoading extends CategoriesState {
  const CategoriesLoading();
}

/// State when categories are successfully loaded.
class CategoriesLoaded extends CategoriesState {
  /// List of categories sorted by order.
  final List<Category> categories;

  /// Whether currently watching for real-time updates.
  final bool isWatching;

  const CategoriesLoaded(
    this.categories, {
    this.isWatching = false,
  });

  @override
  List<Object?> get props => [categories, isWatching];

  /// Creates a copy with optional field updates.
  CategoriesLoaded copyWith({
    List<Category>? categories,
    bool? isWatching,
  }) {
    return CategoriesLoaded(
      categories ?? this.categories,
      isWatching: isWatching ?? this.isWatching,
    );
  }
}

/// State when an error occurs.
class CategoriesError extends CategoriesState {
  final String message;

  const CategoriesError(this.message);

  @override
  List<Object?> get props => [message];
}
