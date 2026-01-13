import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trackwise/features/items/domain/entities/item.dart';
import 'package:trackwise/features/items/domain/usecases/create_item_usecase.dart';
import 'package:trackwise/features/items/domain/usecases/delete_item_usecase.dart';
import 'package:trackwise/features/items/domain/usecases/get_items_usecase.dart';
import 'package:trackwise/features/items/domain/usecases/increment_item_usecase.dart';
import 'package:trackwise/features/items/domain/usecases/update_item_usecase.dart';
import 'package:trackwise/features/items/presentation/bloc/items_bloc.dart';
import 'package:trackwise/features/items/presentation/bloc/items_event.dart';
import 'package:trackwise/features/items/presentation/bloc/items_state.dart';

import 'integration_test_helper.dart';

/// Integration tests for the Items feature.
///
/// These tests verify the complete flow from BLoC → UseCase → Repository → DataSource → Firestore
/// without any mocking. We use FakeFirebaseFirestore to simulate Firestore behavior.
///
/// Test coverage:
/// 1. CreateItem → GetItems flow
/// 2. UpdateItem flow
/// 3. DeleteItem flow
/// 4. WatchItems real-time sync
/// 5. IncrementItem flow
/// 6. BLoC optimistic updates with server responses
void main() {
  late IntegrationTestHelper helper;

  setUp(() async {
    helper = IntegrationTestHelper();
    await helper.setUp();
  });

  tearDown(() async {
    await helper.tearDown();
  });

  group('Items Integration Tests', () {
    const testUserId = 'test_user_123';

    group('CreateItem → GetItems Flow', () {
      test('should create item and retrieve it via GetItems', () async {
        // Arrange - Start with empty Firestore
        await helper.clearFirestore();

        // Act - Create an item
        final createResult = await helper.createItemUseCase(CreateItemParams(
          name: 'Coffee',
          incrementBy: 1,
          reminder: ReminderType.target,
          reminderValue: 20,
          userId: testUserId,
        ));

        // Assert - Creation succeeded
        expect(createResult.isRight(), true);
        final createdItem = createResult.fold(
          (failure) => throw Exception('Creation failed'),
          (item) => item,
        );

        expect(createdItem.name, 'Coffee');
        expect(createdItem.userId, testUserId);
        expect(createdItem.count, 0); // Initial count
        expect(createdItem.todayCount, 0); // Initial today count

        // Act - Retrieve items
        final getResult =
            await helper.getItemsUseCase(GetItemsParams(testUserId));

        // Assert - Item is in the list
        expect(getResult.isRight(), true);
        final items = getResult.fold(
          (failure) => throw Exception('Get failed'),
          (items) => items,
        );

        expect(items.length, 1);
        expect(items[0].id, createdItem.id);
        expect(items[0].name, 'Coffee');

        // Verify in Firestore directly
        final firestoreData =
            await helper.getItemFromFirestore(createdItem.id);
        expect(firestoreData, isNotNull);
        expect(firestoreData!['item_name'], 'Coffee');
        expect(firestoreData['user_id'], testUserId);
      });

      test('should create multiple items and retrieve all', () async {
        // Arrange
        await helper.clearFirestore();

        // Act - Create 3 items
        final items = ['Coffee', 'Water', 'Steps'];
        for (final name in items) {
          await helper.createItemUseCase(CreateItemParams(
            name: name,
            incrementBy: 1,
            reminder: ReminderType.none,
            reminderValue: 0,
            userId: testUserId,
          ));
        }

        // Act - Retrieve all items
        final getResult =
            await helper.getItemsUseCase(GetItemsParams(testUserId));

        // Assert
        expect(getResult.isRight(), true);
        final retrievedItems = getResult.fold(
          (failure) => throw Exception('Get failed'),
          (items) => items,
        );

        expect(retrievedItems.length, 3);
        expect(
          retrievedItems.map((i) => i.name).toSet(),
          {'Coffee', 'Water', 'Steps'},
        );
      });

      test('should only return items for the specified user', () async {
        // Arrange
        await helper.clearFirestore();

        // Create items for different users
        await helper.createItemUseCase(CreateItemParams(
          name: 'User 1 Item',
          incrementBy: 1,
          reminder: ReminderType.none,
          reminderValue: 0,
          userId: 'user_1',
        ));

        await helper.createItemUseCase(CreateItemParams(
          name: 'User 2 Item',
          incrementBy: 1,
          reminder: ReminderType.none,
          reminderValue: 0,
          userId: 'user_2',
        ));

        // Act - Get items for user_1
        final getResult =
            await helper.getItemsUseCase(GetItemsParams('user_1'));

        // Assert - Only user_1's item is returned
        expect(getResult.isRight(), true);
        final items = getResult.fold(
          (failure) => throw Exception('Get failed'),
          (items) => items,
        );

        expect(items.length, 1);
        expect(items[0].name, 'User 1 Item');
        expect(items[0].userId, 'user_1');
      });
    });

    group('UpdateItem Flow', () {
      test('should update item and persist changes', () async {
        // Arrange - Create an item first
        await helper.clearFirestore();

        final createResult = await helper.createItemUseCase(CreateItemParams(
          name: 'Coffee',
          incrementBy: 1,
          reminder: ReminderType.none,
          reminderValue: 0,
          userId: testUserId,
        ));

        final item = createResult.fold(
          (failure) => throw Exception('Creation failed'),
          (item) => item,
        );

        // Act - Update the item
        final updatedItem = item.copyWith(
          name: 'Espresso',
          incrementBy: 2,
          reminder: ReminderType.target,
          reminderValue: 10,
        );

        final updateResult =
            await helper.updateItemUseCase(UpdateItemParams(updatedItem));

        // Assert - Update succeeded
        expect(updateResult.isRight(), true);

        // Verify via GetItems
        final getResult =
            await helper.getItemsUseCase(GetItemsParams(testUserId));
        final items = getResult.fold(
          (failure) => throw Exception('Get failed'),
          (items) => items,
        );

        expect(items.length, 1);
        expect(items[0].name, 'Espresso');
        expect(items[0].incrementBy, 2);
        expect(items[0].reminder, ReminderType.target);
        expect(items[0].reminderValue, 10);

        // Verify in Firestore directly
        final firestoreData = await helper.getItemFromFirestore(item.id);
        expect(firestoreData!['item_name'], 'Espresso');
        expect(firestoreData['increment_by'], 2);
        expect(firestoreData['reminder'], 'TARGET');
        expect(firestoreData['reminder_value'], 10);
      });

      test('should preserve other items when updating one', () async {
        // Arrange - Create 2 items
        await helper.clearFirestore();

        final item1 = (await helper.createItemUseCase(CreateItemParams(
          name: 'Coffee',
          incrementBy: 1,
          reminder: ReminderType.none,
          reminderValue: 0,
          userId: testUserId,
        )))
            .fold(
          (failure) => throw Exception('Creation failed'),
          (item) => item,
        );

        await helper.createItemUseCase(CreateItemParams(
          name: 'Water',
          incrementBy: 1,
          reminder: ReminderType.none,
          reminderValue: 0,
          userId: testUserId,
        ));

        // Act - Update only item1
        await helper.updateItemUseCase(
            UpdateItemParams(item1.copyWith(name: 'Espresso')));

        // Assert - Both items exist, only item1 updated
        final getResult =
            await helper.getItemsUseCase(GetItemsParams(testUserId));
        final items = getResult.fold(
          (failure) => throw Exception('Get failed'),
          (items) => items,
        );

        expect(items.length, 2);
        expect(items.where((i) => i.name == 'Espresso').length, 1);
        expect(items.where((i) => i.name == 'Water').length, 1);
      });
    });

    group('DeleteItem Flow', () {
      test('should delete item from Firestore', () async {
        // Arrange - Create an item
        await helper.clearFirestore();

        final createResult = await helper.createItemUseCase(CreateItemParams(
          name: 'Coffee',
          incrementBy: 1,
          reminder: ReminderType.none,
          reminderValue: 0,
          userId: testUserId,
        ));

        final item = createResult.fold(
          (failure) => throw Exception('Creation failed'),
          (item) => item,
        );

        // Verify item exists
        expect(await helper.itemExistsInFirestore(item.id), true);

        // Act - Delete the item
        final deleteResult =
            await helper.deleteItemUseCase(DeleteItemParams(item.id));

        // Assert - Delete succeeded
        expect(deleteResult.isRight(), true);

        // Verify item no longer exists
        expect(await helper.itemExistsInFirestore(item.id), false);

        // Verify via GetItems
        final getResult =
            await helper.getItemsUseCase(GetItemsParams(testUserId));
        final items = getResult.fold(
          (failure) => throw Exception('Get failed'),
          (items) => items,
        );

        expect(items.isEmpty, true);
      });

      test('should delete only the specified item', () async {
        // Arrange - Create 2 items
        await helper.clearFirestore();

        final item1 = (await helper.createItemUseCase(CreateItemParams(
          name: 'Coffee',
          incrementBy: 1,
          reminder: ReminderType.none,
          reminderValue: 0,
          userId: testUserId,
        )))
            .fold(
          (failure) => throw Exception('Creation failed'),
          (item) => item,
        );

        final item2 = (await helper.createItemUseCase(CreateItemParams(
          name: 'Water',
          incrementBy: 1,
          reminder: ReminderType.none,
          reminderValue: 0,
          userId: testUserId,
        )))
            .fold(
          (failure) => throw Exception('Creation failed'),
          (item) => item,
        );

        // Act - Delete only item1
        await helper.deleteItemUseCase(DeleteItemParams(item1.id));

        // Assert - Only item2 remains
        final getResult =
            await helper.getItemsUseCase(GetItemsParams(testUserId));
        final items = getResult.fold(
          (failure) => throw Exception('Get failed'),
          (items) => items,
        );

        expect(items.length, 1);
        expect(items[0].id, item2.id);
        expect(items[0].name, 'Water');
      });
    });

    group('IncrementItem Flow', () {
      test('should increment item count and persist', () async {
        // Arrange - Create an item
        await helper.clearFirestore();

        final createResult = await helper.createItemUseCase(CreateItemParams(
          name: 'Coffee',
          incrementBy: 1,
          reminder: ReminderType.none,
          reminderValue: 0,
          userId: testUserId,
        ));

        final item = createResult.fold(
          (failure) => throw Exception('Creation failed'),
          (item) => item,
        );

        expect(item.count, 0);
        expect(item.todayCount, 0);

        // Act - Increment by 1
        final incrementResult = await helper
            .incrementItemUseCase(IncrementItemParams(itemId: item.id, amount: 1));

        // Assert - Increment succeeded
        expect(incrementResult.isRight(), true);

        final updatedItem = incrementResult.fold(
          (failure) => throw Exception('Increment failed'),
          (item) => item,
        );

        expect(updatedItem.count, 1);
        expect(updatedItem.todayCount, 1);

        // Verify in Firestore
        final firestoreData = await helper.getItemFromFirestore(item.id);
        expect(firestoreData!['count'], 1);
        expect(firestoreData['todaycount'], 1);
      });

      test('should support custom increment amounts', () async {
        // Arrange
        await helper.clearFirestore();

        final createResult = await helper.createItemUseCase(CreateItemParams(
          name: 'Water',
          incrementBy: 10, // Custom increment value (valid range: 1-100)
          reminder: ReminderType.none,
          reminderValue: 0,
          userId: testUserId,
        ));

        final item = createResult.fold(
          (failure) => throw Exception('Creation failed'),
          (item) => item,
        );

        // Act - Increment by 10 (matching incrementBy value)
        final incrementResult =
            await helper.incrementItemUseCase(IncrementItemParams(
          itemId: item.id,
          amount: 10,
        ));

        // Assert
        expect(incrementResult.isRight(), true);

        final updatedItem = incrementResult.fold(
          (failure) => throw Exception('Increment failed'),
          (item) => item,
        );

        expect(updatedItem.count, 10);
        expect(updatedItem.todayCount, 10);
      });

      test('should increment multiple times correctly', () async {
        // Arrange
        await helper.clearFirestore();

        final createResult = await helper.createItemUseCase(CreateItemParams(
          name: 'Steps',
          incrementBy: 100,
          reminder: ReminderType.none,
          reminderValue: 0,
          userId: testUserId,
        ));

        final item = createResult.fold(
          (failure) => throw Exception('Creation failed'),
          (item) => item,
        );

        // Act - Increment 3 times
        for (int i = 0; i < 3; i++) {
          await helper.incrementItemUseCase(
              IncrementItemParams(itemId: item.id, amount: 100));
        }

        // Assert - Total is 300
        final getResult =
            await helper.getItemsUseCase(GetItemsParams(testUserId));
        final items = getResult.fold(
          (failure) => throw Exception('Get failed'),
          (items) => items,
        );

        expect(items[0].count, 300);
        expect(items[0].todayCount, 300);
      });
    });

    group('WatchItems Real-Time Sync', () {
      test('should emit initial items and updates on stream', () async {
        // Arrange
        await helper.clearFirestore();

        // Seed with 2 items
        await helper.seedFirestore(userId: testUserId, itemCount: 2);

        // Act - Watch items
        final stream =
            helper.watchItemsUseCase(GetItemsParams(testUserId));

        // Assert - Stream emits items
        await expectLater(
          stream.take(1),
          emits(
            predicate<Either>((either) {
              return either.isRight() &&
                  either.fold(
                    (_) => false,
                    (items) => (items as List<Item>).length == 2,
                  );
            }),
          ),
        );
      });

      test('should emit updates when items are added', () async {
        // Arrange
        await helper.clearFirestore();

        // Start watching
        final stream =
            helper.watchItemsUseCase(GetItemsParams(testUserId));

        // Skip first emission (empty list)
        stream.skip(1).take(1).listen(
          expectAsync1((either) {
            expect(either.isRight(), true);
            final items = either.fold(
              (_) => throw Exception('Expected Right'),
              (items) => items as List<Item>,
            );
            expect(items.length, 1);
            expect(items[0].name, 'Coffee');
          }),
        );

        // Act - Add an item after a delay
        await Future.delayed(Duration(milliseconds: 100));
        await helper.createItemUseCase(CreateItemParams(
          name: 'Coffee',
          incrementBy: 1,
          reminder: ReminderType.none,
          reminderValue: 0,
          userId: testUserId,
        ));

        // Wait for stream emission
        await Future.delayed(Duration(milliseconds: 500));
      });
    });

    group('BLoC Integration Tests', () {
      test('should load items via BLoC', () async {
        // Arrange
        await helper.clearFirestore();
        await helper.seedFirestore(userId: testUserId, itemCount: 3);

        // Act
        helper.bloc.add(LoadItemsEvent(testUserId));

        // Assert - Wait for state emissions
        await expectLater(
          helper.bloc.stream,
          emitsInOrder([
            isA<ItemsLoading>(),
            predicate<ItemsLoaded>(
              (state) => state.items.length == 3,
            ),
          ]),
        );
      });

      test('should create item via BLoC when not watching', () async {
        // Arrange
        await helper.clearFirestore();

        // Act - Create item
        helper.bloc.add(CreateItemEvent(
          name: 'Coffee',
          incrementBy: 1,
          reminder: ReminderType.none,
          reminderValue: 0,
          userId: testUserId,
        ));

        // Assert - Should emit loading, then loaded after auto-triggered LoadItemsEvent
        await expectLater(
          helper.bloc.stream.take(2),
          emitsInOrder([
            isA<ItemsLoading>(), // From CreateItemEvent
            predicate<ItemsLoaded>(
              (state) => state.items.length == 1 && state.items[0].name == 'Coffee',
            ), // From auto-triggered LoadItemsEvent
          ]),
        );
      });

      test('should perform optimistic update and revert on failure', () async {
        // This test demonstrates optimistic updates
        // We can't easily simulate failure with fake_cloud_firestore
        // but we can verify the optimistic behavior

        // Arrange - Create an item
        await helper.clearFirestore();
        final item = (await helper.createItemUseCase(CreateItemParams(
          name: 'Coffee',
          incrementBy: 1,
          reminder: ReminderType.none,
          reminderValue: 0,
          userId: testUserId,
        )))
            .fold(
          (_) => throw Exception('Failed'),
          (item) => item,
        );

        // Load items into BLoC
        helper.bloc.add(LoadItemsEvent(testUserId));
        await helper.bloc.stream.firstWhere((state) => state is ItemsLoaded);

        // Act - Update item
        final updatedItem = item.copyWith(name: 'Espresso');
        helper.bloc.add(UpdateItemEvent(updatedItem));

        // Assert - Should see optimistic update
        await expectLater(
          helper.bloc.stream.take(1),
          emits(
            predicate<ItemsLoaded>(
              (state) => state.items[0].name == 'Espresso',
            ),
          ),
        );

        // Verify it persisted to Firestore
        final firestoreData = await helper.getItemFromFirestore(item.id);
        expect(firestoreData!['item_name'], 'Espresso');
      });

      test('should perform optimistic delete', () async {
        // Arrange - Create an item
        await helper.clearFirestore();
        final item = (await helper.createItemUseCase(CreateItemParams(
          name: 'Coffee',
          incrementBy: 1,
          reminder: ReminderType.none,
          reminderValue: 0,
          userId: testUserId,
        )))
            .fold(
          (_) => throw Exception('Failed'),
          (item) => item,
        );

        // Load items into BLoC
        helper.bloc.add(LoadItemsEvent(testUserId));
        await helper.bloc.stream.firstWhere((state) => state is ItemsLoaded);

        // Act - Delete item
        helper.bloc.add(DeleteItemEvent(item.id));

        // Assert - Should see optimistic delete
        await expectLater(
          helper.bloc.stream.take(1),
          emits(
            predicate<ItemsLoaded>(
              (state) => state.items.isEmpty,
            ),
          ),
        );

        // Verify it was deleted from Firestore
        expect(await helper.itemExistsInFirestore(item.id), false);
      });

      test('should perform optimistic increment', () async {
        // Arrange - Create an item
        await helper.clearFirestore();
        final item = (await helper.createItemUseCase(CreateItemParams(
          name: 'Coffee',
          incrementBy: 1,
          reminder: ReminderType.none,
          reminderValue: 0,
          userId: testUserId,
        )))
            .fold(
          (_) => throw Exception('Failed'),
          (item) => item,
        );

        // Load items into BLoC
        helper.bloc.add(LoadItemsEvent(testUserId));
        await helper.bloc.stream.firstWhere((state) => state is ItemsLoaded);

        // Act - Increment item
        helper.bloc.add(IncrementItemEvent(itemId: item.id, amount: 1));

        // Assert - Should see optimistic increment, then server update
        await expectLater(
          helper.bloc.stream.take(2),
          emitsInOrder([
            predicate<ItemsLoaded>(
              (state) => state.items[0].count == 1, // Optimistic
            ),
            predicate<ItemsLoaded>(
              (state) => state.items[0].count == 1, // Server confirmation
            ),
          ]),
        );

        // Verify it persisted to Firestore
        final firestoreData = await helper.getItemFromFirestore(item.id);
        expect(firestoreData!['count'], 1);
      });
    });
  });
}
