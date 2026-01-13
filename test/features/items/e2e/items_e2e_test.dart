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

import 'e2e_test_helper.dart';

/// End-to-End tests for Items feature with real Firebase emulator.
///
/// These tests use the actual Firebase emulator to test:
/// - Real Firestore behavior (transactions, atomicity)
/// - Real authentication
/// - Real-time sync with multiple clients
/// - Network conditions
/// - Concurrent operations
///
/// Prerequisites:
/// - Firebase emulator must be running: `firebase emulators:start`
/// - Run in project root: cd firebase && firebase emulators:start
///
/// To run these tests:
/// ```bash
/// # Terminal 1: Start emulator
/// cd firebase
/// firebase emulators:start
///
/// # Terminal 2: Run E2E tests
/// flutter test test/features/items/e2e/items_e2e_test.dart
/// ```
void main() {
  late E2ETestHelper helper;

  setUpAll(() async {
    // Check if emulator is running
    final isRunning = await E2ETestHelper.isEmulatorRunning();
    if (!isRunning) {
      print('\n' + '=' * 70);
      print('ERROR: Firebase emulator is not running!');
      print('Please start the emulator first:');
      print('  cd firebase');
      print('  firebase emulators:start');
      print('=' * 70 + '\n');
      throw Exception('Firebase emulator not running. Start it with: firebase emulators:start');
    }
    print('✓ Firebase emulator is running');
  });

  setUp(() async {
    helper = E2ETestHelper();
    await helper.setUp();
  });

  tearDown(() async {
    await helper.tearDown();
  });

  group('E2E: Items with Real Firebase Emulator', () {
    group('Authentication & User Isolation', () {
      test('should create items with authenticated user', () async {
        // Arrange
        await helper.clearFirestore();
        final userId = helper.getTestUserId();

        // Act - Create item
        final result = await helper.createItemUseCase(CreateItemParams(
          name: 'Coffee',
          incrementBy: 1,
          reminder: ReminderType.none,
          reminderValue: 0,
          userId: userId,
        ));

        // Assert
        expect(result.isRight(), true);
        final item = result.fold(
          (failure) => throw Exception('Creation failed'),
          (item) => item,
        );

        // Verify user ID is set
        expect(item.userId, userId);

        // Verify in Firestore
        final firestoreData = await helper.getItemFromFirestore(item.id);
        expect(firestoreData!['user_id'], userId);
      });

      test('should only retrieve items for authenticated user', () async {
        // Arrange
        await helper.clearFirestore();
        final userId = helper.getTestUserId();

        // Create items for current user
        await helper.createItemUseCase(CreateItemParams(
          name: 'User Item 1',
          incrementBy: 1,
          reminder: ReminderType.none,
          reminderValue: 0,
          userId: userId,
        ));

        // Create item for different user (simulated)
        await helper.firestore.collection('Item').add({
          'item_name': 'Other User Item',
          'count': 0,
          'todaycount': 0,
          'increment_by': 1,
          'reminder': 'NONE',
          'reminder_value': 0,
          'lastResetTime': DateTime.now().millisecondsSinceEpoch,
          'lastUpdated': DateTime.now().millisecondsSinceEpoch,
          'user_id': 'different_user_123',
        });

        // Act - Get items for current user
        final result = await helper.getItemsUseCase(GetItemsParams(userId));

        // Assert - Only current user's items returned
        expect(result.isRight(), true);
        final items = result.fold(
          (failure) => throw Exception('Get failed'),
          (items) => items,
        );

        expect(items.length, 1);
        expect(items[0].name, 'User Item 1');
        expect(items[0].userId, userId);
      });
    });

    group('Real Firestore Behavior', () {
      test('should persist data correctly with real Firestore', () async {
        // Arrange
        await helper.clearFirestore();
        final userId = helper.getTestUserId();

        // Act - Create item
        final createResult = await helper.createItemUseCase(CreateItemParams(
          name: 'Water Intake',
          incrementBy: 250,
          reminder: ReminderType.target,
          reminderValue: 2000,
          userId: userId,
        ));

        final item = createResult.fold(
          (failure) => throw Exception('Creation failed'),
          (item) => item,
        );

        // Wait for Firestore to settle
        await helper.simulateNetworkDelay(milliseconds: 100);

        // Act - Read directly from Firestore
        final doc = await helper.firestore.collection('Item').doc(item.id).get();

        // Assert - Verify all fields persisted correctly
        expect(doc.exists, true);
        final data = doc.data()!;
        expect(data['item_name'], 'Water Intake');
        expect(data['increment_by'], 250);
        expect(data['reminder'], 'TARGET');
        expect(data['reminder_value'], 2000);
        expect(data['count'], 0);
        expect(data['todaycount'], 0);
        expect(data['user_id'], userId);
        expect(data['lastResetTime'], isA<int>());
        expect(data['lastUpdated'], isA<int>());
      });

      test('should handle concurrent increments atomically', () async {
        // Arrange
        await helper.clearFirestore();
        final userId = helper.getTestUserId();

        final createResult = await helper.createItemUseCase(CreateItemParams(
          name: 'Counter',
          incrementBy: 1,
          reminder: ReminderType.none,
          reminderValue: 0,
          userId: userId,
        ));

        final item = createResult.fold(
          (failure) => throw Exception('Creation failed'),
          (item) => item,
        );

        // Act - Perform 10 concurrent increments
        final futures = List.generate(
          10,
          (_) => helper.incrementItemUseCase(
            IncrementItemParams(itemId: item.id, amount: 1),
          ),
        );

        final results = await Future.wait(futures);

        // Assert - All increments succeeded
        for (final result in results) {
          expect(result.isRight(), true);
        }

        // Wait for Firestore to settle
        await helper.simulateNetworkDelay(milliseconds: 200);

        // Verify final count is exactly 10
        final getResult = await helper.getItemsUseCase(GetItemsParams(userId));
        final items = getResult.fold(
          (failure) => throw Exception('Get failed'),
          (items) => items,
        );

        expect(items[0].count, 10);
        expect(items[0].todayCount, 10);
      });

      test('should handle delete with cascading EventLog deletion', () async {
        // Arrange
        await helper.clearFirestore();
        final userId = helper.getTestUserId();

        // Create item
        final createResult = await helper.createItemUseCase(CreateItemParams(
          name: 'Test Item',
          incrementBy: 1,
          reminder: ReminderType.none,
          reminderValue: 0,
          userId: userId,
        ));

        final item = createResult.fold(
          (failure) => throw Exception('Creation failed'),
          (item) => item,
        );

        // Add some EventLog entries manually (simulating increments)
        for (int i = 0; i < 3; i++) {
          await helper.firestore.collection('EventLog').add({
            'item_id': item.id,
            'event_name': 'increment',
            'created_time': DateTime.now().millisecondsSinceEpoch,
            'user_id': userId,
          });
        }

        // Verify EventLog entries exist
        final eventsBefore = await helper.firestore
            .collection('EventLog')
            .where('item_id', isEqualTo: item.id)
            .get();
        expect(eventsBefore.docs.length, 3);

        // Act - Delete item
        await helper.deleteItemUseCase(DeleteItemParams(item.id));

        // Wait for Firestore to settle
        await helper.simulateNetworkDelay(milliseconds: 200);

        // Assert - Item deleted
        expect(await helper.itemExistsInFirestore(item.id), false);

        // Assert - EventLog entries also deleted
        final eventsAfter = await helper.firestore
            .collection('EventLog')
            .where('item_id', isEqualTo: item.id)
            .get();
        expect(eventsAfter.docs.length, 0);
      });
    });

    group('Multi-Client Real-Time Sync', () {
      test('should sync updates across multiple BLoC instances', () async {
        // Arrange
        await helper.clearFirestore();
        final userId = helper.getTestUserId();

        // Seed data
        await helper.seedFirestore(userId: userId, itemCount: 2);

        // Create two BLoC instances (simulating two clients)
        final bloc1 = helper.bloc;
        final bloc2 = helper.createSecondBloc();

        // Both BLoCs watch items
        bloc1.add(WatchItemsEvent(userId));
        bloc2.add(WatchItemsEvent(userId));

        // Wait for initial load
        await Future.delayed(Duration(milliseconds: 500));

        // Act - Create item from bloc1
        bloc1.add(CreateItemEvent(
          name: 'New Item from Client 1',
          incrementBy: 1,
          reminder: ReminderType.none,
          reminderValue: 0,
          userId: userId,
        ));

        // Wait for sync
        await Future.delayed(Duration(milliseconds: 800));

        // Assert - bloc2 should receive the update
        expect(bloc2.state, isA<ItemsLoaded>());
        final bloc2State = bloc2.state as ItemsLoaded;
        expect(
          bloc2State.items.any((item) => item.name == 'New Item from Client 1'),
          true,
        );

        // Cleanup
        await bloc2.close();
      });

      test('should sync increments across multiple watchers', () async {
        // Arrange
        await helper.clearFirestore();
        final userId = helper.getTestUserId();

        // Create item
        final createResult = await helper.createItemUseCase(CreateItemParams(
          name: 'Shared Counter',
          incrementBy: 1,
          reminder: ReminderType.none,
          reminderValue: 0,
          userId: userId,
        ));

        final item = createResult.fold(
          (failure) => throw Exception('Creation failed'),
          (item) => item,
        );

        // Create two BLoC instances
        final bloc1 = helper.bloc;
        final bloc2 = helper.createSecondBloc();

        // Both watch items
        bloc1.add(WatchItemsEvent(userId));
        bloc2.add(WatchItemsEvent(userId));

        await Future.delayed(Duration(milliseconds: 500));

        // Act - Increment from bloc1
        bloc1.add(IncrementItemEvent(itemId: item.id, amount: 1));

        // Wait for sync
        await Future.delayed(Duration(milliseconds: 800));

        // Assert - bloc2 sees the increment
        expect(bloc2.state, isA<ItemsLoaded>());
        final bloc2State = bloc2.state as ItemsLoaded;
        final sharedItem = bloc2State.items.firstWhere((i) => i.id == item.id);
        expect(sharedItem.count, 1);
        expect(sharedItem.todayCount, 1);

        await bloc2.close();
      });

      test('should sync deletes across multiple watchers', () async {
        // Arrange
        await helper.clearFirestore();
        final userId = helper.getTestUserId();

        // Create item
        final createResult = await helper.createItemUseCase(CreateItemParams(
          name: 'Item to Delete',
          incrementBy: 1,
          reminder: ReminderType.none,
          reminderValue: 0,
          userId: userId,
        ));

        final item = createResult.fold(
          (failure) => throw Exception('Creation failed'),
          (item) => item,
        );

        // Create two BLoC instances
        final bloc1 = helper.bloc;
        final bloc2 = helper.createSecondBloc();

        // Both watch items
        bloc1.add(WatchItemsEvent(userId));
        bloc2.add(WatchItemsEvent(userId));

        await Future.delayed(Duration(milliseconds: 500));

        // Verify both have the item
        expect((bloc1.state as ItemsLoaded).items.length, 1);
        expect((bloc2.state as ItemsLoaded).items.length, 1);

        // Act - Delete from bloc1
        bloc1.add(DeleteItemEvent(item.id));

        // Wait for sync
        await Future.delayed(Duration(milliseconds: 800));

        // Assert - bloc2 sees the deletion
        expect(bloc2.state, isA<ItemsLoaded>());
        final bloc2State = bloc2.state as ItemsLoaded;
        expect(bloc2State.items.isEmpty, true);

        await bloc2.close();
      });
    });

    group('Network & Error Scenarios', () {
      test('should handle network delays gracefully', () async {
        // Arrange
        await helper.clearFirestore();
        final userId = helper.getTestUserId();

        // Act - Create item (with simulated network delay)
        final startTime = DateTime.now();
        final result = await helper.createItemUseCase(CreateItemParams(
          name: 'Delayed Item',
          incrementBy: 1,
          reminder: ReminderType.none,
          reminderValue: 0,
          userId: userId,
        ));

        final endTime = DateTime.now();
        final duration = endTime.difference(startTime);

        // Assert - Should succeed despite network conditions
        expect(result.isRight(), true);
        print('Operation completed in ${duration.inMilliseconds}ms');
      });

      test('should handle large batch operations', () async {
        // Arrange
        await helper.clearFirestore();
        final userId = helper.getTestUserId();

        // Act - Create 20 items
        final futures = List.generate(
          20,
          (i) => helper.createItemUseCase(CreateItemParams(
            name: 'Batch Item ${i + 1}',
            incrementBy: 1,
            reminder: ReminderType.none,
            reminderValue: 0,
            userId: userId,
          )),
        );

        final results = await Future.wait(futures);

        // Assert - All succeeded
        for (final result in results) {
          expect(result.isRight(), true);
        }

        // Verify all items exist
        final getResult = await helper.getItemsUseCase(GetItemsParams(userId));
        final items = getResult.fold(
          (failure) => throw Exception('Get failed'),
          (items) => items,
        );

        expect(items.length, 20);
      });
    });

    group('BLoC Optimistic Updates with Real Firestore', () {
      test('should show optimistic update then server confirmation', () async {
        // Arrange
        await helper.clearFirestore();
        final userId = helper.getTestUserId();

        // Create item
        final createResult = await helper.createItemUseCase(CreateItemParams(
          name: 'Coffee',
          incrementBy: 1,
          reminder: ReminderType.none,
          reminderValue: 0,
          userId: userId,
        ));

        final item = createResult.fold(
          (failure) => throw Exception('Creation failed'),
          (item) => item,
        );

        // Load into BLoC
        helper.bloc.add(LoadItemsEvent(userId));
        await helper.bloc.stream.firstWhere((state) => state is ItemsLoaded);

        // Act - Increment
        helper.bloc.add(IncrementItemEvent(itemId: item.id, amount: 1));

        // Assert - Should see optimistic update then server confirmation
        final states = <ItemsState>[];
        final subscription = helper.bloc.stream.listen((state) {
          states.add(state);
        });

        await Future.delayed(Duration(milliseconds: 1000));

        // Should have at least 2 states: optimistic + server
        expect(states.length >= 2, true);
        expect(states.every((s) => s is ItemsLoaded), true);

        // Final state should have count = 1
        final finalState = states.last as ItemsLoaded;
        expect(finalState.items[0].count, 1);

        await subscription.cancel();
      });
    });
  });
}
