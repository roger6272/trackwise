import 'package:traxelos/features/categories/domain/entities/category.dart';
import 'package:traxelos/features/categories/data/models/category_model.dart';

final testDateTime = DateTime(2026, 1, 4);

final testCategory = Category(
  id: 'test_category_1',
  name: 'Electronics',
  userId: 'user_123',
  order: 0,
  createdAt: testDateTime,
  lastUpdated: testDateTime,
);

final testCategory2 = Category(
  id: 'test_category_2',
  name: 'Groceries',
  userId: 'user_123',
  order: 1,
  createdAt: testDateTime,
  lastUpdated: testDateTime,
);

final testCategoryModel = CategoryModel(
  id: 'test_category_1',
  name: 'Electronics',
  userId: 'user_123',
  order: 0,
  createdAt: testDateTime,
  lastUpdated: testDateTime,
);

final testCategoryModel2 = CategoryModel(
  id: 'test_category_2',
  name: 'Groceries',
  userId: 'user_123',
  order: 1,
  createdAt: testDateTime,
  lastUpdated: testDateTime,
);

final testCategories = [testCategory, testCategory2];
final testCategoryModels = [testCategoryModel, testCategoryModel2];
