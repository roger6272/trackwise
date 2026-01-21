import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/category.dart';

/// Repository interface for category operations.
///
/// Defines the contract for category data access, following the repository pattern.
/// Implementations handle the actual data source interactions (Firestore, etc.).
abstract class CategoryRepository {
  /// Fetches all categories for a user (one-time fetch).
  ///
  /// Returns categories sorted by [order] field.
  /// Excludes soft-deleted categories.
  Future<Either<Failure, List<Category>>> getCategories(String userId);

  /// Watches categories for real-time updates.
  ///
  /// Returns a stream that emits whenever categories change.
  /// Excludes soft-deleted categories.
  Stream<Either<Failure, List<Category>>> watchCategories(String userId);

  /// Creates a new category.
  ///
  /// The [category.id] field is ignored; a new ID is generated.
  /// Sets [order] to be at the end of the list.
  Future<Either<Failure, Category>> createCategory(Category category);

  /// Updates an existing category.
  ///
  /// Updates all fields except [id] and [userId].
  Future<Either<Failure, Category>> updateCategory(Category category);

  /// Soft-deletes a category by setting [deletedAt].
  ///
  /// Items in this category will have their [categoryId] set to null.
  Future<Either<Failure, void>> deleteCategory(String categoryId);

  /// Updates the order of multiple categories.
  ///
  /// Each category in the list should have its [order] field set correctly.
  Future<Either<Failure, void>> reorderCategories(List<Category> categories);

  /// Checks if a category name already exists for a user.
  ///
  /// Used for validation before create/update.
  /// [excludeId] can be provided to exclude a specific category (for updates).
  Future<Either<Failure, bool>> categoryNameExists(
    String userId,
    String name, {
    String? excludeId,
  });

  /// Gets the count of items in a category.
  Future<Either<Failure, int>> getItemCountForCategory(String? categoryId, String userId);
}
