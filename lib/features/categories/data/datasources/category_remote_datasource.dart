import '../models/category_model.dart';

/// Remote data source interface for category operations.
///
/// Defines the contract for Firestore interactions.
/// Throws [ServerException] on errors.
abstract class CategoryRemoteDataSource {
  /// Fetches all categories for a user.
  Future<List<CategoryModel>> getCategories(String userId);

  /// Watches categories for real-time updates.
  Stream<List<CategoryModel>> watchCategories(String userId);

  /// Creates a new category and returns the created model with ID.
  Future<CategoryModel> createCategory(CategoryModel category);

  /// Updates an existing category.
  Future<CategoryModel> updateCategory(CategoryModel category);

  /// Soft-deletes a category by setting deletedAt.
  Future<void> deleteCategory(String categoryId);

  /// Updates the order of multiple categories in a batch.
  Future<void> reorderCategories(List<CategoryModel> categories);

  /// Checks if a category name exists for a user.
  Future<bool> categoryNameExists(String userId, String name, {String? excludeId});

  /// Gets the count of items in a category.
  Future<int> getItemCountForCategory(String? categoryId, String userId);

  /// Gets the next order value for a new category.
  Future<int> getNextOrderValue(String userId);
}
