import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:injectable/injectable.dart';

import '../../domain/entities/category.dart';
import '../../domain/usecases/create_category_usecase.dart';
import '../../domain/usecases/delete_category_usecase.dart';
import '../../domain/usecases/reorder_categories_usecase.dart';
import '../../domain/usecases/update_category_usecase.dart';
import '../../domain/usecases/watch_categories_usecase.dart';
import 'categories_event.dart';
import 'categories_state.dart';

/// BLoC for managing category state.
@injectable
class CategoriesBloc extends Bloc<CategoriesEvent, CategoriesState> {
  final WatchCategoriesUseCase watchCategoriesUseCase;
  final CreateCategoryUseCase createCategoryUseCase;
  final UpdateCategoryUseCase updateCategoryUseCase;
  final DeleteCategoryUseCase deleteCategoryUseCase;
  final ReorderCategoriesUseCase reorderCategoriesUseCase;

  StreamSubscription? _categoriesSubscription;

  CategoriesBloc({
    required this.watchCategoriesUseCase,
    required this.createCategoryUseCase,
    required this.updateCategoryUseCase,
    required this.deleteCategoryUseCase,
    required this.reorderCategoriesUseCase,
  }) : super(const CategoriesInitial()) {
    on<WatchCategoriesEvent>(_onWatchCategories);
    on<StopWatchingCategoriesEvent>(_onStopWatchingCategories);
    on<CategoriesUpdatedEvent>(_onCategoriesUpdated);
    on<CreateCategoryEvent>(_onCreateCategory);
    on<UpdateCategoryEvent>(_onUpdateCategory);
    on<DeleteCategoryEvent>(_onDeleteCategory);
    on<ReorderCategoriesEvent>(_onReorderCategories);
  }

  Future<void> _onWatchCategories(
    WatchCategoriesEvent event,
    Emitter<CategoriesState> emit,
  ) async {
    if (kDebugMode) print('🔵 CategoriesBloc: Starting to watch categories for user ${event.userId}');
    emit(const CategoriesLoading());

    await _categoriesSubscription?.cancel();

    _categoriesSubscription = watchCategoriesUseCase(
      WatchCategoriesParams(event.userId),
    ).listen(
      (result) {
        if (kDebugMode) print('🟢 CategoriesBloc: Received stream update');
        result.fold(
          (failure) {
            if (kDebugMode) print('🔴 CategoriesBloc: Stream failure - ${failure.message}');
            add(CategoriesUpdatedEvent(const []));
          },
          (categories) {
            if (kDebugMode) print('🟢 CategoriesBloc: Loaded ${categories.length} categories');
            add(CategoriesUpdatedEvent(categories));
          },
        );
      },
      onError: (error, stackTrace) {
        // Emit empty list on stream error to show empty state
        if (kDebugMode) print('❌ CategoriesBloc: Stream error - $error');
        if (kDebugMode) print('Stack trace: $stackTrace');
        add(CategoriesUpdatedEvent(const []));
      },
    );
  }

  Future<void> _onStopWatchingCategories(
    StopWatchingCategoriesEvent event,
    Emitter<CategoriesState> emit,
  ) async {
    await _categoriesSubscription?.cancel();
    _categoriesSubscription = null;

    final currentState = state;
    if (currentState is CategoriesLoaded) {
      emit(currentState.copyWith(isWatching: false));
    }
  }

  void _onCategoriesUpdated(
    CategoriesUpdatedEvent event,
    Emitter<CategoriesState> emit,
  ) {
    emit(CategoriesLoaded(
      event.categories,
      isWatching: true,
    ));
  }

  Future<void> _onCreateCategory(
    CreateCategoryEvent event,
    Emitter<CategoriesState> emit,
  ) async {
    final result = await createCategoryUseCase(
      CreateCategoryParams(
        name: event.name,
        userId: event.userId,
      ),
    );

    result.fold(
      (failure) {
        // Emit error state briefly, then return to loaded state
        final currentState = state;
        emit(CategoriesError(failure.message));
        if (currentState is CategoriesLoaded) {
          emit(currentState);
        }
      },
      (category) {
        // Category will be added via stream update
      },
    );
  }

  Future<void> _onUpdateCategory(
    UpdateCategoryEvent event,
    Emitter<CategoriesState> emit,
  ) async {
    final result = await updateCategoryUseCase(
      UpdateCategoryParams(event.category),
    );

    result.fold(
      (failure) {
        final currentState = state;
        emit(CategoriesError(failure.message));
        if (currentState is CategoriesLoaded) {
          emit(currentState);
        }
      },
      (category) {
        // Category will be updated via stream
      },
    );
  }

  Future<void> _onDeleteCategory(
    DeleteCategoryEvent event,
    Emitter<CategoriesState> emit,
  ) async {
    final result = await deleteCategoryUseCase(
      DeleteCategoryParams(event.categoryId),
    );

    result.fold(
      (failure) {
        final currentState = state;
        emit(CategoriesError(failure.message));
        if (currentState is CategoriesLoaded) {
          emit(currentState);
        }
      },
      (_) {
        // Category will be removed via stream
      },
    );
  }

  Future<void> _onReorderCategories(
    ReorderCategoriesEvent event,
    Emitter<CategoriesState> emit,
  ) async {
    final currentState = state;
    if (currentState is! CategoriesLoaded) return;

    // Calculate new index (Flutter's ReorderableListView behavior)
    int newIndex = event.newIndex;
    if (event.oldIndex < newIndex) {
      newIndex -= 1;
    }

    // Skip if no actual change
    if (event.oldIndex == newIndex) return;

    // Optimistic reorder
    final reorderedCategories = List<Category>.from(currentState.categories);
    final movedCategory = reorderedCategories.removeAt(event.oldIndex);
    reorderedCategories.insert(newIndex, movedCategory);

    // Update order field for each category
    final updatedCategories = reorderedCategories.asMap().entries.map((entry) {
      return entry.value.copyWith(order: entry.key);
    }).toList();

    emit(currentState.copyWith(categories: updatedCategories));

    // Persist to Firestore
    final result = await reorderCategoriesUseCase(
      ReorderCategoriesParams(updatedCategories),
    );

    result.fold(
      (failure) {
        // Revert on failure
        emit(currentState);
        emit(CategoriesError(failure.message));
        emit(currentState);
      },
      (_) {
        // Success - stream will confirm
      },
    );
  }

  @override
  Future<void> close() {
    _categoriesSubscription?.cancel();
    return super.close();
  }
}
