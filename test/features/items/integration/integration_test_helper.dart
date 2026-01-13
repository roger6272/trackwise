import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:get_it/get_it.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:trackwise/features/items/data/datasources/item_remote_datasource.dart';
import 'package:trackwise/features/items/data/datasources/item_remote_datasource_impl.dart';
import 'package:trackwise/features/items/data/repositories/item_repository_impl.dart';
import 'package:trackwise/features/items/domain/repositories/item_repository.dart';
import 'package:trackwise/features/items/domain/usecases/create_item_usecase.dart';
import 'package:trackwise/features/items/domain/usecases/delete_item_usecase.dart';
import 'package:trackwise/features/items/domain/usecases/get_items_usecase.dart';
import 'package:trackwise/features/items/domain/usecases/increment_item_usecase.dart';
import 'package:trackwise/features/items/domain/usecases/update_item_usecase.dart';
import 'package:trackwise/features/items/domain/usecases/watch_items_usecase.dart';
import 'package:trackwise/features/items/presentation/bloc/items_bloc.dart';

/// Integration test helper for setting up the complete Items feature stack
/// with a fake Firestore instance.
///
/// This allows testing the entire flow:
/// BLoC → UseCase → Repository → DataSource → Firestore
///
/// without mocking any layers (true integration testing).
class IntegrationTestHelper {
  late FakeFirebaseFirestore fakeFirestore;
  late ItemRemoteDataSource dataSource;
  late ItemRepository repository;
  late GetItemsUseCase getItemsUseCase;
  late WatchItemsUseCase watchItemsUseCase;
  late CreateItemUseCase createItemUseCase;
  late UpdateItemUseCase updateItemUseCase;
  late DeleteItemUseCase deleteItemUseCase;
  late IncrementItemUseCase incrementItemUseCase;
  late ItemsBloc bloc;

  final GetIt getIt = GetIt.instance;

  /// Set up the complete Items feature stack with fake Firestore
  Future<void> setUp() async {
    // Create fake Firestore instance
    fakeFirestore = FakeFirebaseFirestore();

    // Create data source with fake Firestore
    dataSource = ItemRemoteDataSourceImpl(fakeFirestore);

    // Create repository with real data source
    repository = ItemRepositoryImpl(dataSource);

    // Create use cases with real repository
    getItemsUseCase = GetItemsUseCase(repository);
    watchItemsUseCase = WatchItemsUseCase(repository);
    createItemUseCase = CreateItemUseCase(repository);
    updateItemUseCase = UpdateItemUseCase(repository);
    deleteItemUseCase = DeleteItemUseCase(repository);
    incrementItemUseCase = IncrementItemUseCase(repository);

    // Create BLoC with all real use cases
    bloc = ItemsBloc(
      getItemsUseCase: getItemsUseCase,
      watchItemsUseCase: watchItemsUseCase,
      createItemUseCase: createItemUseCase,
      updateItemUseCase: updateItemUseCase,
      deleteItemUseCase: deleteItemUseCase,
      incrementItemUseCase: incrementItemUseCase,
    );
  }

  /// Clean up resources
  Future<void> tearDown() async {
    await bloc.close();
    // Note: FakeFirebaseFirestore doesn't require terminate/clearPersistence
  }

  /// Clear all data from fake Firestore
  Future<void> clearFirestore() async {
    // Delete all documents in Item collection
    final itemsSnapshot = await fakeFirestore.collection('Item').get();
    for (final doc in itemsSnapshot.docs) {
      await doc.reference.delete();
    }

    // Delete all documents in EventLog collection
    final eventsSnapshot = await fakeFirestore.collection('EventLog').get();
    for (final doc in eventsSnapshot.docs) {
      await doc.reference.delete();
    }
  }

  /// Add test data to Firestore
  Future<void> seedFirestore({
    required String userId,
    int itemCount = 3,
  }) async {
    final now = DateTime.now();

    for (int i = 1; i <= itemCount; i++) {
      await fakeFirestore.collection('Item').add({
        'item_name': 'Test Item $i',
        'count': i * 10,
        'todaycount': i * 5,
        'increment_by': 1,
        'reminder': 'NONE',
        'reminder_value': 0,
        'lastResetTime': now.millisecondsSinceEpoch,
        'lastUpdated': now.millisecondsSinceEpoch,
        'user_id': userId,
      });
    }
  }

  /// Get count of documents in a collection
  Future<int> getDocumentCount(String collectionName) async {
    final snapshot = await fakeFirestore.collection(collectionName).get();
    return snapshot.docs.length;
  }

  /// Get all items for a user from Firestore directly
  Future<List<Map<String, dynamic>>> getItemsFromFirestore(
      String userId) async {
    final snapshot = await fakeFirestore
        .collection('Item')
        .where('user_id', isEqualTo: userId)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  /// Verify an item exists in Firestore
  Future<bool> itemExistsInFirestore(String itemId) async {
    final doc = await fakeFirestore.collection('Item').doc(itemId).get();
    return doc.exists;
  }

  /// Get item data from Firestore
  Future<Map<String, dynamic>?> getItemFromFirestore(String itemId) async {
    final doc = await fakeFirestore.collection('Item').doc(itemId).get();
    if (!doc.exists) return null;

    final data = doc.data();
    if (data == null) return null;

    data['id'] = doc.id;
    return data;
  }
}
