import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:trackwise/core/error/failures.dart';
import 'package:trackwise/features/items/domain/entities/item.dart';
import 'package:trackwise/features/items/domain/usecases/get_items_usecase.dart';
import 'package:trackwise/features/items/domain/usecases/create_item_usecase.dart';
import 'package:trackwise/features/items/domain/usecases/update_item_usecase.dart';
import 'package:trackwise/features/items/domain/usecases/delete_item_usecase.dart';
import 'package:trackwise/features/items/domain/usecases/increment_item_usecase.dart';
import 'package:trackwise/features/items/presentation/bloc/items_bloc.dart';
import 'package:trackwise/features/items/presentation/bloc/items_event.dart';
import 'package:trackwise/features/items/presentation/bloc/items_state.dart';

import '../../helpers/test_helper.dart';
import '../../helpers/test_fixtures.dart';

void main() {
  late MockGetItemsUseCase mockGetItems;
  late MockWatchItemsUseCase mockWatchItems;
  late MockCreateItemUseCase mockCreateItem;
  late MockUpdateItemUseCase mockUpdateItem;
  late MockDeleteItemUseCase mockDeleteItem;
  late MockIncrementItemUseCase mockIncrementItem;
  late MockItemRepository mockItemRepository;

  setUpAll(() {
    // Register fallback values for mocktail (only once)
    registerFallbackValue(GetItemsParams(''));
    registerFallbackValue(CreateItemParams(
      name: '',
      incrementBy: 1,
      reminder: ReminderType.none,
      reminderValue: 0,
      userId: '',
    ));
    registerFallbackValue(UpdateItemParams(testItem));
    registerFallbackValue(DeleteItemParams(''));
    registerFallbackValue(IncrementItemParams(itemId: '', amount: 1));
  });

  setUp(() {
    mockGetItems = MockGetItemsUseCase();
    mockWatchItems = MockWatchItemsUseCase();
    mockCreateItem = MockCreateItemUseCase();
    mockUpdateItem = MockUpdateItemUseCase();
    mockDeleteItem = MockDeleteItemUseCase();
    mockIncrementItem = MockIncrementItemUseCase();
    mockItemRepository = MockItemRepository();
  });

  test('initial state should be ItemsInitial', () {
    // Create bloc for this test
    final bloc = ItemsBloc(
      getItemsUseCase: mockGetItems,
      watchItemsUseCase: mockWatchItems,
      createItemUseCase: mockCreateItem,
      updateItemUseCase: mockUpdateItem,
      deleteItemUseCase: mockDeleteItem,
      incrementItemUseCase: mockIncrementItem,
      itemRepository: mockItemRepository,
    );

    // Assert
    expect(bloc.state, ItemsInitial());

    // Clean up
    bloc.close();
  });

  group('LoadItemsEvent', () {
    const userId = 'user_123';

    blocTest<ItemsBloc, ItemsState>(
      'emits [ItemsLoading, ItemsLoaded] when successful',
      build: () {
        when(() => mockGetItems(any()))
            .thenAnswer((_) async => Right(testItems));
        return ItemsBloc(
          getItemsUseCase: mockGetItems,
          watchItemsUseCase: mockWatchItems,
          createItemUseCase: mockCreateItem,
          updateItemUseCase: mockUpdateItem,
          deleteItemUseCase: mockDeleteItem,
          incrementItemUseCase: mockIncrementItem,
          itemRepository: mockItemRepository,
        );
      },
      act: (bloc) => bloc.add(LoadItemsEvent(userId)),
      expect: () => [
        ItemsLoading(),
        ItemsLoaded(testItems),
      ],
      verify: (_) {
        verify(() => mockGetItems(GetItemsParams(userId))).called(1);
      },
    );

    blocTest<ItemsBloc, ItemsState>(
      'emits [ItemsLoading, ItemsError] when fails',
      build: () {
        when(() => mockGetItems(any()))
            .thenAnswer((_) async => const Left(ServerFailure('Error')));
        return ItemsBloc(
          getItemsUseCase: mockGetItems,
          watchItemsUseCase: mockWatchItems,
          createItemUseCase: mockCreateItem,
          updateItemUseCase: mockUpdateItem,
          deleteItemUseCase: mockDeleteItem,
          incrementItemUseCase: mockIncrementItem,
          itemRepository: mockItemRepository,
        );
      },
      act: (bloc) => bloc.add(LoadItemsEvent(userId)),
      expect: () => [
        ItemsLoading(),
        const ItemsError('Error'),
      ],
    );

    blocTest<ItemsBloc, ItemsState>(
      'emits [ItemsLoading, ItemsLoaded] with empty list',
      build: () {
        when(() => mockGetItems(any()))
            .thenAnswer((_) async => const Right([]));
        return ItemsBloc(
          getItemsUseCase: mockGetItems,
          watchItemsUseCase: mockWatchItems,
          createItemUseCase: mockCreateItem,
          updateItemUseCase: mockUpdateItem,
          deleteItemUseCase: mockDeleteItem,
          incrementItemUseCase: mockIncrementItem,
          itemRepository: mockItemRepository,
        );
      },
      act: (bloc) => bloc.add(LoadItemsEvent(userId)),
      expect: () => [
        ItemsLoading(),
        const ItemsLoaded([]),
      ],
    );
  });

  group('WatchItemsEvent', () {
    const userId = 'user_123';

    blocTest<ItemsBloc, ItemsState>(
      'emits [ItemsLoading, ItemsLoaded(isWatching: true)] when successful',
      build: () {
        when(() => mockWatchItems(any())).thenAnswer(
          (_) => Stream.value(Right(testItems)),
        );
        return ItemsBloc(
          getItemsUseCase: mockGetItems,
          watchItemsUseCase: mockWatchItems,
          createItemUseCase: mockCreateItem,
          updateItemUseCase: mockUpdateItem,
          deleteItemUseCase: mockDeleteItem,
          incrementItemUseCase: mockIncrementItem,
          itemRepository: mockItemRepository,
        );
      },
      act: (bloc) => bloc.add(WatchItemsEvent(userId)),
      expect: () => [
        ItemsLoading(),
        ItemsLoaded(testItems, isWatching: true),
      ],
    );

    blocTest<ItemsBloc, ItemsState>(
      'emits [ItemsLoading, ItemsError] when stream fails',
      build: () {
        when(() => mockWatchItems(any())).thenAnswer(
          (_) => Stream.value(const Left(ServerFailure('Stream error'))),
        );
        return ItemsBloc(
          getItemsUseCase: mockGetItems,
          watchItemsUseCase: mockWatchItems,
          createItemUseCase: mockCreateItem,
          updateItemUseCase: mockUpdateItem,
          deleteItemUseCase: mockDeleteItem,
          incrementItemUseCase: mockIncrementItem,
          itemRepository: mockItemRepository,
        );
      },
      act: (bloc) => bloc.add(WatchItemsEvent(userId)),
      expect: () => [
        ItemsLoading(),
        const ItemsError('Stream error'),
      ],
    );

    blocTest<ItemsBloc, ItemsState>(
      'emits multiple states from stream updates',
      build: () {
        when(() => mockWatchItems(any())).thenAnswer(
          (_) => Stream.fromIterable([
            Right(testItems),
            Right([testItem]),
          ]),
        );
        return ItemsBloc(
          getItemsUseCase: mockGetItems,
          watchItemsUseCase: mockWatchItems,
          createItemUseCase: mockCreateItem,
          updateItemUseCase: mockUpdateItem,
          deleteItemUseCase: mockDeleteItem,
          incrementItemUseCase: mockIncrementItem,
          itemRepository: mockItemRepository,
        );
      },
      act: (bloc) => bloc.add(WatchItemsEvent(userId)),
      expect: () => [
        ItemsLoading(),
        ItemsLoaded(testItems, isWatching: true),
        ItemsLoaded([testItem], isWatching: true),
      ],
    );

    blocTest<ItemsBloc, ItemsState>(
      'cancels existing subscription before creating new one',
      build: () {
        when(() => mockWatchItems(any())).thenAnswer(
          (_) => Stream.value(Right(testItems)),
        );
        return ItemsBloc(
          getItemsUseCase: mockGetItems,
          watchItemsUseCase: mockWatchItems,
          createItemUseCase: mockCreateItem,
          updateItemUseCase: mockUpdateItem,
          deleteItemUseCase: mockDeleteItem,
          incrementItemUseCase: mockIncrementItem,
          itemRepository: mockItemRepository,
        );
      },
      act: (bloc) {
        bloc.add(WatchItemsEvent(userId));
        bloc.add(WatchItemsEvent(userId));
      },
      expect: () => [
        ItemsLoading(),
        ItemsLoaded(testItems, isWatching: true),
        ItemsLoading(),
        ItemsLoaded(testItems, isWatching: true),
      ],
    );
  });

  group('StopWatchingItemsEvent', () {
    blocTest<ItemsBloc, ItemsState>(
      'updates isWatching to false while keeping items',
      build: () => ItemsBloc(
        getItemsUseCase: mockGetItems,
        watchItemsUseCase: mockWatchItems,
        createItemUseCase: mockCreateItem,
        updateItemUseCase: mockUpdateItem,
        deleteItemUseCase: mockDeleteItem,
        incrementItemUseCase: mockIncrementItem,
        itemRepository: mockItemRepository,
      ),
      seed: () => ItemsLoaded(testItems, isWatching: true),
      act: (bloc) => bloc.add(StopWatchingItemsEvent()),
      expect: () => [
        ItemsLoaded(testItems, isWatching: false),
      ],
    );

    blocTest<ItemsBloc, ItemsState>(
      'does nothing if not in ItemsLoaded state',
      build: () => ItemsBloc(
        getItemsUseCase: mockGetItems,
        watchItemsUseCase: mockWatchItems,
        createItemUseCase: mockCreateItem,
        updateItemUseCase: mockUpdateItem,
        deleteItemUseCase: mockDeleteItem,
        incrementItemUseCase: mockIncrementItem,
        itemRepository: mockItemRepository,
      ),
      act: (bloc) => bloc.add(StopWatchingItemsEvent()),
      expect: () => [],
    );
  });

  group('CreateItemEvent', () {
    const userId = 'user_123';

    blocTest<ItemsBloc, ItemsState>(
      'emits ItemsLoading when not watching',
      build: () {
        when(() => mockCreateItem(any()))
            .thenAnswer((_) async => Right(testItem));
        when(() => mockGetItems(any()))
            .thenAnswer((_) async => Right(testItems));
        return ItemsBloc(
          getItemsUseCase: mockGetItems,
          watchItemsUseCase: mockWatchItems,
          createItemUseCase: mockCreateItem,
          updateItemUseCase: mockUpdateItem,
          deleteItemUseCase: mockDeleteItem,
          incrementItemUseCase: mockIncrementItem,
          itemRepository: mockItemRepository,
        );
      },
      seed: () => const ItemsLoaded([]),
      act: (bloc) => bloc.add(CreateItemEvent(
        name: 'Coffee',
        incrementBy: 1,
        reminder: ReminderType.target,
        reminderValue: 20,
        userId: userId,
      )),
      expect: () => [
        ItemsLoading(),
        ItemsLoaded(testItems),
      ],
    );

    blocTest<ItemsBloc, ItemsState>(
      'emits ItemsError when creation fails',
      build: () {
        when(() => mockCreateItem(any()))
            .thenAnswer((_) async => const Left(ServerFailure('Failed to create')));
        return ItemsBloc(
          getItemsUseCase: mockGetItems,
          watchItemsUseCase: mockWatchItems,
          createItemUseCase: mockCreateItem,
          updateItemUseCase: mockUpdateItem,
          deleteItemUseCase: mockDeleteItem,
          incrementItemUseCase: mockIncrementItem,
          itemRepository: mockItemRepository,
        );
      },
      act: (bloc) => bloc.add(CreateItemEvent(
        name: 'Coffee',
        incrementBy: 1,
        reminder: ReminderType.none,
        reminderValue: 0,
        userId: userId,
      )),
      expect: () => [
        ItemsLoading(),
        const ItemsError('Failed to create'),
      ],
    );

    blocTest<ItemsBloc, ItemsState>(
      'keeps loading state when watching (stream will update)',
      build: () {
        when(() => mockCreateItem(any()))
            .thenAnswer((_) async => Right(testItem));
        return ItemsBloc(
          getItemsUseCase: mockGetItems,
          watchItemsUseCase: mockWatchItems,
          createItemUseCase: mockCreateItem,
          updateItemUseCase: mockUpdateItem,
          deleteItemUseCase: mockDeleteItem,
          incrementItemUseCase: mockIncrementItem,
          itemRepository: mockItemRepository,
        );
      },
      seed: () => ItemsLoaded(testItems, isWatching: true),
      act: (bloc) => bloc.add(CreateItemEvent(
        name: 'Coffee',
        incrementBy: 1,
        reminder: ReminderType.none,
        reminderValue: 0,
        userId: userId,
      )),
      expect: () => [
        ItemsLoading(),
      ],
    );
  });

  group('UpdateItemEvent', () {
    blocTest<ItemsBloc, ItemsState>(
      'shows optimistic update immediately',
      build: () {
        when(() => mockUpdateItem(any()))
            .thenAnswer((_) async => Right(testItem));
        return ItemsBloc(
          getItemsUseCase: mockGetItems,
          watchItemsUseCase: mockWatchItems,
          createItemUseCase: mockCreateItem,
          updateItemUseCase: mockUpdateItem,
          deleteItemUseCase: mockDeleteItem,
          incrementItemUseCase: mockIncrementItem,
          itemRepository: mockItemRepository,
        );
      },
      seed: () => ItemsLoaded([testItem.copyWith(name: 'Old Name')]),
      act: (bloc) => bloc.add(UpdateItemEvent(testItem)),
      expect: () => [
        ItemsLoaded([testItem], isWatching: false),
      ],
      verify: (_) {
        verify(() => mockUpdateItem(any())).called(1);
      },
    );

    blocTest<ItemsBloc, ItemsState>(
      'keeps optimistic update if not watching and succeeds',
      build: () {
        when(() => mockUpdateItem(any()))
            .thenAnswer((_) async => Right(testItem));
        return ItemsBloc(
          getItemsUseCase: mockGetItems,
          watchItemsUseCase: mockWatchItems,
          createItemUseCase: mockCreateItem,
          updateItemUseCase: mockUpdateItem,
          deleteItemUseCase: mockDeleteItem,
          incrementItemUseCase: mockIncrementItem,
          itemRepository: mockItemRepository,
        );
      },
      seed: () => ItemsLoaded([testItem.copyWith(name: 'Old Name')], isWatching: false),
      act: (bloc) => bloc.add(UpdateItemEvent(testItem)),
      expect: () => [
        ItemsLoaded([testItem], isWatching: false),
      ],
    );

    blocTest<ItemsBloc, ItemsState>(
      'reverts to previous state on failure',
      build: () {
        when(() => mockUpdateItem(any()))
            .thenAnswer((_) async => const Left(ServerFailure('Update failed')));
        return ItemsBloc(
          getItemsUseCase: mockGetItems,
          watchItemsUseCase: mockWatchItems,
          createItemUseCase: mockCreateItem,
          updateItemUseCase: mockUpdateItem,
          deleteItemUseCase: mockDeleteItem,
          incrementItemUseCase: mockIncrementItem,
          itemRepository: mockItemRepository,
        );
      },
      seed: () => ItemsLoaded([testItem.copyWith(name: 'Old Name')]),
      act: (bloc) => bloc.add(UpdateItemEvent(testItem)),
      expect: () => [
        ItemsLoaded([testItem], isWatching: false), // Optimistic
        ItemsLoaded([testItem.copyWith(name: 'Old Name')], isWatching: false), // Reverted
        const ItemsError('Update failed'),
      ],
    );

    blocTest<ItemsBloc, ItemsState>(
      'does nothing if not in ItemsLoaded state',
      build: () => ItemsBloc(
        getItemsUseCase: mockGetItems,
        watchItemsUseCase: mockWatchItems,
        createItemUseCase: mockCreateItem,
        updateItemUseCase: mockUpdateItem,
        deleteItemUseCase: mockDeleteItem,
        incrementItemUseCase: mockIncrementItem,
        itemRepository: mockItemRepository,
      ),
      act: (bloc) => bloc.add(UpdateItemEvent(testItem)),
      expect: () => [],
    );
  });

  group('DeleteItemEvent', () {
    const itemId = 'test_item_1';

    blocTest<ItemsBloc, ItemsState>(
      'shows optimistic delete immediately',
      build: () {
        when(() => mockDeleteItem(any()))
            .thenAnswer((_) async => const Right(null));
        return ItemsBloc(
          getItemsUseCase: mockGetItems,
          watchItemsUseCase: mockWatchItems,
          createItemUseCase: mockCreateItem,
          updateItemUseCase: mockUpdateItem,
          deleteItemUseCase: mockDeleteItem,
          incrementItemUseCase: mockIncrementItem,
          itemRepository: mockItemRepository,
        );
      },
      seed: () => ItemsLoaded(testItems),
      act: (bloc) => bloc.add(DeleteItemEvent(itemId)),
      expect: () => [
        ItemsLoaded([testItem2], isWatching: false),
      ],
      verify: (_) {
        verify(() => mockDeleteItem(any())).called(1);
      },
    );

    blocTest<ItemsBloc, ItemsState>(
      'keeps optimistic delete if not watching and succeeds',
      build: () {
        when(() => mockDeleteItem(any()))
            .thenAnswer((_) async => const Right(null));
        return ItemsBloc(
          getItemsUseCase: mockGetItems,
          watchItemsUseCase: mockWatchItems,
          createItemUseCase: mockCreateItem,
          updateItemUseCase: mockUpdateItem,
          deleteItemUseCase: mockDeleteItem,
          incrementItemUseCase: mockIncrementItem,
          itemRepository: mockItemRepository,
        );
      },
      seed: () => ItemsLoaded(testItems, isWatching: false),
      act: (bloc) => bloc.add(DeleteItemEvent(itemId)),
      expect: () => [
        ItemsLoaded([testItem2], isWatching: false),
      ],
    );

    blocTest<ItemsBloc, ItemsState>(
      'reverts to previous state on failure',
      build: () {
        when(() => mockDeleteItem(any()))
            .thenAnswer((_) async => const Left(ServerFailure('Delete failed')));
        return ItemsBloc(
          getItemsUseCase: mockGetItems,
          watchItemsUseCase: mockWatchItems,
          createItemUseCase: mockCreateItem,
          updateItemUseCase: mockUpdateItem,
          deleteItemUseCase: mockDeleteItem,
          incrementItemUseCase: mockIncrementItem,
          itemRepository: mockItemRepository,
        );
      },
      seed: () => ItemsLoaded(testItems),
      act: (bloc) => bloc.add(DeleteItemEvent(itemId)),
      expect: () => [
        ItemsLoaded([testItem2], isWatching: false), // Optimistic
        ItemsLoaded(testItems, isWatching: false), // Reverted
        const ItemsError('Delete failed'),
      ],
    );

    blocTest<ItemsBloc, ItemsState>(
      'does nothing if not in ItemsLoaded state',
      build: () => ItemsBloc(
        getItemsUseCase: mockGetItems,
        watchItemsUseCase: mockWatchItems,
        createItemUseCase: mockCreateItem,
        updateItemUseCase: mockUpdateItem,
        deleteItemUseCase: mockDeleteItem,
        incrementItemUseCase: mockIncrementItem,
        itemRepository: mockItemRepository,
      ),
      act: (bloc) => bloc.add(DeleteItemEvent(itemId)),
      expect: () => [],
    );
  });

  group('IncrementItemEvent', () {
    const itemId = 'test_item_1';
    const amount = 5;

    blocTest<ItemsBloc, ItemsState>(
      'shows optimistic increment immediately',
      build: () {
        when(() => mockIncrementItem(any()))
            .thenAnswer((_) async => Right(testItem));
        return ItemsBloc(
          getItemsUseCase: mockGetItems,
          watchItemsUseCase: mockWatchItems,
          createItemUseCase: mockCreateItem,
          updateItemUseCase: mockUpdateItem,
          deleteItemUseCase: mockDeleteItem,
          incrementItemUseCase: mockIncrementItem,
          itemRepository: mockItemRepository,
        );
      },
      seed: () => ItemsLoaded(testItems),
      act: (bloc) => bloc.add(IncrementItemEvent(itemId: itemId, amount: amount)),
      expect: () => [
        predicate<ItemsLoaded>((state) =>
          state.items[0].count == testItem.count + amount &&
          state.items[0].todayCount == testItem.todayCount + amount),
        predicate<ItemsLoaded>((state) =>
          state.items[0].count == testItem.count &&
          state.items[0].todayCount == testItem.todayCount),
      ],
      verify: (_) {
        verify(() => mockIncrementItem(any())).called(1);
      },
    );

    blocTest<ItemsBloc, ItemsState>(
      'uses server data if not watching and succeeds',
      build: () {
        final incrementedItem = testItem.copyWith(count: 100, todayCount: 50);
        when(() => mockIncrementItem(any()))
            .thenAnswer((_) async => Right(incrementedItem));
        return ItemsBloc(
          getItemsUseCase: mockGetItems,
          watchItemsUseCase: mockWatchItems,
          createItemUseCase: mockCreateItem,
          updateItemUseCase: mockUpdateItem,
          deleteItemUseCase: mockDeleteItem,
          incrementItemUseCase: mockIncrementItem,
          itemRepository: mockItemRepository,
        );
      },
      seed: () => ItemsLoaded(testItems, isWatching: false),
      act: (bloc) => bloc.add(IncrementItemEvent(itemId: itemId)),
      expect: () => [
        predicate<ItemsLoaded>((state) => state.items[0].count == 11), // Optimistic
        predicate<ItemsLoaded>((state) => state.items[0].count == 100), // Server data
      ],
    );

    blocTest<ItemsBloc, ItemsState>(
      'reverts to previous state on failure',
      build: () {
        when(() => mockIncrementItem(any()))
            .thenAnswer((_) async => const Left(ServerFailure('Increment failed')));
        return ItemsBloc(
          getItemsUseCase: mockGetItems,
          watchItemsUseCase: mockWatchItems,
          createItemUseCase: mockCreateItem,
          updateItemUseCase: mockUpdateItem,
          deleteItemUseCase: mockDeleteItem,
          incrementItemUseCase: mockIncrementItem,
          itemRepository: mockItemRepository,
        );
      },
      seed: () => ItemsLoaded(testItems),
      act: (bloc) => bloc.add(IncrementItemEvent(itemId: itemId)),
      expect: () => [
        predicate<ItemsLoaded>((state) => state.items[0].count == 11), // Optimistic
        ItemsLoaded(testItems, isWatching: false), // Reverted
        const ItemsError('Increment failed'),
      ],
    );

    blocTest<ItemsBloc, ItemsState>(
      'handles custom increment amount',
      build: () {
        when(() => mockIncrementItem(any()))
            .thenAnswer((_) async => Right(testItem));
        return ItemsBloc(
          getItemsUseCase: mockGetItems,
          watchItemsUseCase: mockWatchItems,
          createItemUseCase: mockCreateItem,
          updateItemUseCase: mockUpdateItem,
          deleteItemUseCase: mockDeleteItem,
          incrementItemUseCase: mockIncrementItem,
          itemRepository: mockItemRepository,
        );
      },
      seed: () => ItemsLoaded(testItems),
      act: (bloc) => bloc.add(IncrementItemEvent(itemId: itemId, amount: 3)),
      expect: () => [
        predicate<ItemsLoaded>((state) =>
          state.items[0].count == testItem.count + 3),
        predicate<ItemsLoaded>((state) =>
          state.items[0].count == testItem.count),
      ],
    );

    blocTest<ItemsBloc, ItemsState>(
      'does nothing if not in ItemsLoaded state',
      build: () => ItemsBloc(
        getItemsUseCase: mockGetItems,
        watchItemsUseCase: mockWatchItems,
        createItemUseCase: mockCreateItem,
        updateItemUseCase: mockUpdateItem,
        deleteItemUseCase: mockDeleteItem,
        incrementItemUseCase: mockIncrementItem,
        itemRepository: mockItemRepository,
      ),
      act: (bloc) => bloc.add(IncrementItemEvent(itemId: itemId)),
      expect: () => [],
    );
  });
}
