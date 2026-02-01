import 'package:mocktail/mocktail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:traxelos/features/categories/domain/repositories/category_repository.dart';
import 'package:traxelos/features/categories/domain/usecases/create_category_usecase.dart';
import 'package:traxelos/features/categories/domain/usecases/update_category_usecase.dart';
import 'package:traxelos/features/categories/domain/usecases/delete_category_usecase.dart';
import 'package:traxelos/features/categories/domain/usecases/reorder_categories_usecase.dart';
import 'package:traxelos/features/categories/domain/usecases/watch_categories_usecase.dart';
import 'package:traxelos/features/categories/data/datasources/category_remote_datasource.dart';

// Domain mocks
class MockCategoryRepository extends Mock implements CategoryRepository {}

class MockCreateCategoryUseCase extends Mock implements CreateCategoryUseCase {}

class MockUpdateCategoryUseCase extends Mock implements UpdateCategoryUseCase {}

class MockDeleteCategoryUseCase extends Mock implements DeleteCategoryUseCase {}

class MockReorderCategoriesUseCase extends Mock
    implements ReorderCategoriesUseCase {}

class MockWatchCategoriesUseCase extends Mock
    implements WatchCategoriesUseCase {}

// Data mocks
class MockCategoryRemoteDataSource extends Mock
    implements CategoryRemoteDataSource {}

class MockDocumentSnapshot<T> extends Mock implements DocumentSnapshot<T> {}

class MockDocumentReference<T> extends Mock implements DocumentReference<T> {}
