import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:traxelos/core/error/failures.dart';
import 'package:traxelos/features/categories/domain/entities/category.dart';
import 'package:traxelos/features/categories/domain/usecases/create_category_usecase.dart';
import 'package:traxelos/features/categories/domain/usecases/delete_category_usecase.dart';
import 'package:traxelos/features/categories/domain/usecases/reorder_categories_usecase.dart';
import 'package:traxelos/features/categories/domain/usecases/update_category_usecase.dart';
import 'package:traxelos/features/categories/domain/usecases/watch_categories_usecase.dart';
import 'package:traxelos/features/categories/presentation/bloc/categories_bloc.dart';
import 'package:traxelos/features/categories/presentation/bloc/categories_event.dart';
import 'package:traxelos/features/categories/presentation/bloc/categories_state.dart';

import '../../helpers/test_helper.dart';
import '../../helpers/test_fixtures.dart';

void main() {
  late MockWatchCategoriesUseCase mockWatchCategories;
  late MockCreateCategoryUseCase mockCreateCategory;
  late MockUpdateCategoryUseCase mockUpdateCategory;
  late MockDeleteCategoryUseCase mockDeleteCategory;
  late MockReorderCategoriesUseCase mockReorderCategories;

  setUpAll(() {
    registerFallbackValue(const WatchCategoriesParams(''));
    registerFallbackValue(const CreateCategoryParams(name: '', userId: ''));
    registerFallbackValue(UpdateCategoryParams(testCategory));
    registerFallbackValue(const DeleteCategoryParams(''));
    registerFallbackValue(ReorderCategoriesParams(const []));
  });

  setUp(() {
    mockWatchCategories = MockWatchCategoriesUseCase();
    mockCreateCategory = MockCreateCategoryUseCase();
    mockUpdateCategory = MockUpdateCategoryUseCase();
    mockDeleteCategory = MockDeleteCategoryUseCase();
    mockReorderCategories = MockReorderCategoriesUseCase();
  });

  CategoriesBloc buildBloc() => CategoriesBloc(
        watchCategoriesUseCase: mockWatchCategories,
        createCategoryUseCase: mockCreateCategory,
        updateCategoryUseCase: mockUpdateCategory,
        deleteCategoryUseCase: mockDeleteCategory,
        reorderCategoriesUseCase: mockReorderCategories,
      );

  test('initial state should be CategoriesInitial', () {
    final bloc = buildBloc();
    expect(bloc.state, const CategoriesInitial());
    bloc.close();
  });

  group('WatchCategoriesEvent', () {
    const userId = 'user_123';

    blocTest<CategoriesBloc, CategoriesState>(
      'emits [CategoriesLoading, CategoriesLoaded(isWatching: true)] when successful',
      build: () {
        when(() => mockWatchCategories(any())).thenAnswer(
          (_) => Stream.value(Right(testCategories)),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(const WatchCategoriesEvent(userId)),
      wait: const Duration(milliseconds: 50),
      expect: () => [
        const CategoriesLoading(),
        CategoriesLoaded(testCategories, isWatching: true),
      ],
    );

    blocTest<CategoriesBloc, CategoriesState>(
      'emits [CategoriesLoading, CategoriesLoaded(empty)] when stream has failure',
      build: () {
        when(() => mockWatchCategories(any())).thenAnswer(
          (_) => Stream.value(
              const Left(ServerFailure('Stream error'))),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(const WatchCategoriesEvent(userId)),
      wait: const Duration(milliseconds: 50),
      expect: () => [
        const CategoriesLoading(),
        const CategoriesLoaded([], isWatching: true),
      ],
    );

    blocTest<CategoriesBloc, CategoriesState>(
      'emits multiple states from stream updates',
      build: () {
        when(() => mockWatchCategories(any())).thenAnswer(
          (_) => Stream.fromIterable([
            Right(testCategories),
            Right([testCategory]),
          ]),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(const WatchCategoriesEvent(userId)),
      wait: const Duration(milliseconds: 50),
      expect: () => [
        const CategoriesLoading(),
        CategoriesLoaded(testCategories, isWatching: true),
        CategoriesLoaded([testCategory], isWatching: true),
      ],
    );
  });

  group('StopWatchingCategoriesEvent', () {
    blocTest<CategoriesBloc, CategoriesState>(
      'updates isWatching to false while keeping categories',
      build: () => buildBloc(),
      seed: () => CategoriesLoaded(testCategories, isWatching: true),
      act: (bloc) => bloc.add(const StopWatchingCategoriesEvent()),
      expect: () => [
        CategoriesLoaded(testCategories, isWatching: false),
      ],
    );

    blocTest<CategoriesBloc, CategoriesState>(
      'does nothing if not in CategoriesLoaded state',
      build: () => buildBloc(),
      act: (bloc) => bloc.add(const StopWatchingCategoriesEvent()),
      expect: () => [],
    );
  });

  group('CategoriesUpdatedEvent', () {
    blocTest<CategoriesBloc, CategoriesState>(
      'emits CategoriesLoaded with isWatching true',
      build: () => buildBloc(),
      act: (bloc) => bloc.add(CategoriesUpdatedEvent(testCategories)),
      expect: () => [
        CategoriesLoaded(testCategories, isWatching: true),
      ],
    );
  });

  group('CreateCategoryEvent', () {
    const userId = 'user_123';

    blocTest<CategoriesBloc, CategoriesState>(
      'no error state emitted on success (stream will update)',
      build: () {
        when(() => mockCreateCategory(any()))
            .thenAnswer((_) async => Right(testCategory));
        return buildBloc();
      },
      seed: () => CategoriesLoaded(testCategories, isWatching: true),
      act: (bloc) => bloc.add(const CreateCategoryEvent(
        name: 'Electronics',
        userId: userId,
      )),
      expect: () => [],
    );

    blocTest<CategoriesBloc, CategoriesState>(
      'emits [CategoriesError, restored CategoriesLoaded] on failure',
      build: () {
        when(() => mockCreateCategory(any())).thenAnswer(
            (_) async => const Left(ServerFailure('Failed to create')));
        return buildBloc();
      },
      seed: () => CategoriesLoaded(testCategories, isWatching: true),
      act: (bloc) => bloc.add(const CreateCategoryEvent(
        name: 'Electronics',
        userId: userId,
      )),
      expect: () => [
        const CategoriesError('Failed to create'),
        CategoriesLoaded(testCategories, isWatching: true),
      ],
    );
  });

  group('UpdateCategoryEvent', () {
    blocTest<CategoriesBloc, CategoriesState>(
      'no error state emitted on success (stream will update)',
      build: () {
        when(() => mockUpdateCategory(any()))
            .thenAnswer((_) async => Right(testCategory));
        return buildBloc();
      },
      seed: () => CategoriesLoaded(testCategories, isWatching: true),
      act: (bloc) => bloc.add(UpdateCategoryEvent(testCategory)),
      expect: () => [],
    );

    blocTest<CategoriesBloc, CategoriesState>(
      'emits [CategoriesError, restored CategoriesLoaded] on failure',
      build: () {
        when(() => mockUpdateCategory(any())).thenAnswer(
            (_) async => const Left(ServerFailure('Failed to update')));
        return buildBloc();
      },
      seed: () => CategoriesLoaded(testCategories, isWatching: true),
      act: (bloc) => bloc.add(UpdateCategoryEvent(testCategory)),
      expect: () => [
        const CategoriesError('Failed to update'),
        CategoriesLoaded(testCategories, isWatching: true),
      ],
    );
  });

  group('DeleteCategoryEvent', () {
    const categoryId = 'test_category_1';

    blocTest<CategoriesBloc, CategoriesState>(
      'no error state emitted on success (stream will update)',
      build: () {
        when(() => mockDeleteCategory(any()))
            .thenAnswer((_) async => const Right(null));
        return buildBloc();
      },
      seed: () => CategoriesLoaded(testCategories, isWatching: true),
      act: (bloc) => bloc.add(const DeleteCategoryEvent(categoryId)),
      expect: () => [],
    );

    blocTest<CategoriesBloc, CategoriesState>(
      'emits [CategoriesError, restored CategoriesLoaded] on failure',
      build: () {
        when(() => mockDeleteCategory(any())).thenAnswer(
            (_) async => const Left(ServerFailure('Failed to delete')));
        return buildBloc();
      },
      seed: () => CategoriesLoaded(testCategories, isWatching: true),
      act: (bloc) => bloc.add(const DeleteCategoryEvent(categoryId)),
      expect: () => [
        const CategoriesError('Failed to delete'),
        CategoriesLoaded(testCategories, isWatching: true),
      ],
    );
  });

  group('ReorderCategoriesEvent', () {
    blocTest<CategoriesBloc, CategoriesState>(
      'emits optimistic reorder on success',
      build: () {
        when(() => mockReorderCategories(any()))
            .thenAnswer((_) async => const Right(null));
        return buildBloc();
      },
      seed: () => CategoriesLoaded(testCategories, isWatching: true),
      act: (bloc) => bloc.add(const ReorderCategoriesEvent(
        oldIndex: 0,
        newIndex: 2,
      )),
      expect: () => [
        // After reorder: testCategory2 at index 0 (order=0), testCategory at index 1 (order=1)
        predicate<CategoriesLoaded>((state) =>
            state.categories.length == 2 &&
            state.categories[0].id == testCategory2.id &&
            state.categories[0].order == 0 &&
            state.categories[1].id == testCategory.id &&
            state.categories[1].order == 1),
      ],
      verify: (_) {
        verify(() => mockReorderCategories(any())).called(1);
      },
    );

    blocTest<CategoriesBloc, CategoriesState>(
      'reverts to previous state on failure',
      build: () {
        when(() => mockReorderCategories(any())).thenAnswer(
            (_) async => const Left(ServerFailure('Reorder failed')));
        return buildBloc();
      },
      seed: () => CategoriesLoaded(testCategories, isWatching: true),
      act: (bloc) => bloc.add(const ReorderCategoriesEvent(
        oldIndex: 0,
        newIndex: 2,
      )),
      expect: () => [
        // Optimistic reorder
        predicate<CategoriesLoaded>((state) =>
            state.categories[0].id == testCategory2.id),
        // Revert to original
        CategoriesLoaded(testCategories, isWatching: true),
        const CategoriesError('Reorder failed'),
        CategoriesLoaded(testCategories, isWatching: true),
      ],
    );

    blocTest<CategoriesBloc, CategoriesState>(
      'no-op when oldIndex equals adjusted newIndex',
      build: () => buildBloc(),
      seed: () => CategoriesLoaded(testCategories, isWatching: true),
      act: (bloc) => bloc.add(const ReorderCategoriesEvent(
        oldIndex: 0,
        newIndex: 0,
      )),
      expect: () => [],
    );

    blocTest<CategoriesBloc, CategoriesState>(
      'no-op when oldIndex equals newIndex after adjustment',
      build: () => buildBloc(),
      seed: () => CategoriesLoaded(testCategories, isWatching: true),
      act: (bloc) => bloc.add(const ReorderCategoriesEvent(
        oldIndex: 0,
        newIndex: 1,
      )),
      expect: () => [],
    );

    blocTest<CategoriesBloc, CategoriesState>(
      'does nothing if not in CategoriesLoaded state',
      build: () => buildBloc(),
      act: (bloc) => bloc.add(const ReorderCategoriesEvent(
        oldIndex: 0,
        newIndex: 2,
      )),
      expect: () => [],
    );
  });
}
