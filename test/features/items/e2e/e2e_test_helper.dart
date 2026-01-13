import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

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

/// E2E test helper for testing with real Firebase emulator.
///
/// This differs from IntegrationTestHelper by using:
/// - Real Firebase emulator (not fake Firestore)
/// - Real authentication
/// - Real network conditions
/// - Real Firestore transactions
///
/// Prerequisites:
/// - Firebase CLI installed
/// - Firebase emulator running: `firebase emulators:start`
///
/// Usage:
/// ```dart
/// setUp(() async {
///   helper = E2ETestHelper();
///   await helper.setUp();
/// });
///
/// tearDown(() async {
///   await helper.tearDown();
/// });
/// ```
class E2ETestHelper {
  late FirebaseFirestore firestore;
  late FirebaseAuth auth;
  late ItemRemoteDataSource dataSource;
  late ItemRepository repository;
  late GetItemsUseCase getItemsUseCase;
  late WatchItemsUseCase watchItemsUseCase;
  late CreateItemUseCase createItemUseCase;
  late UpdateItemUseCase updateItemUseCase;
  late DeleteItemUseCase deleteItemUseCase;
  late IncrementItemUseCase incrementItemUseCase;
  late ItemsBloc bloc;

  User? currentUser;
  bool _isInitialized = false;

  /// Firebase Emulator configuration
  static const String firestoreEmulatorHost = 'localhost';
  static const int firestoreEmulatorPort = 8080;
  static const String authEmulatorHost = 'localhost';
  static const int authEmulatorPort = 9099;

  /// Set up Firebase connection to emulator and create complete stack
  Future<void> setUp() async {
    if (_isInitialized) {
      print('E2ETestHelper already initialized, skipping setup');
      return;
    }

    try {
      // Initialize Firebase for testing
      TestWidgetsFlutterBinding.ensureInitialized();

      // Check if Firebase is already initialized
      try {
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: 'test-api-key',
            appId: 'test-app-id',
            messagingSenderId: 'test-sender-id',
            projectId: 'test-project',
          ),
        );
      } catch (e) {
        // Already initialized, that's fine
        print('Firebase already initialized: $e');
      }

      // Get Firestore and Auth instances
      firestore = FirebaseFirestore.instance;
      auth = FirebaseAuth.instance;

      // Connect to emulators
      firestore.useFirestoreEmulator(firestoreEmulatorHost, firestoreEmulatorPort);
      await auth.useAuthEmulator(authEmulatorHost, authEmulatorPort);

      print('Connected to Firebase emulators:');
      print('  - Firestore: $firestoreEmulatorHost:$firestoreEmulatorPort');
      print('  - Auth: $authEmulatorHost:$authEmulatorPort');

      // Create test user
      await _createTestUser();

      // Create the complete stack
      dataSource = ItemRemoteDataSourceImpl(firestore);
      repository = ItemRepositoryImpl(dataSource);
      getItemsUseCase = GetItemsUseCase(repository);
      watchItemsUseCase = WatchItemsUseCase(repository);
      createItemUseCase = CreateItemUseCase(repository);
      updateItemUseCase = UpdateItemUseCase(repository);
      deleteItemUseCase = DeleteItemUseCase(repository);
      incrementItemUseCase = IncrementItemUseCase(repository);

      bloc = ItemsBloc(
        getItemsUseCase: getItemsUseCase,
        watchItemsUseCase: watchItemsUseCase,
        createItemUseCase: createItemUseCase,
        updateItemUseCase: updateItemUseCase,
        deleteItemUseCase: deleteItemUseCase,
        incrementItemUseCase: incrementItemUseCase,
      );

      _isInitialized = true;
      print('E2ETestHelper setup complete');
    } catch (e, stackTrace) {
      print('Error in E2ETestHelper.setUp: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Create a test user for authentication
  Future<void> _createTestUser() async {
    try {
      // Sign out any existing user
      await auth.signOut();

      // Create test user with email/password
      final credential = await auth.createUserWithEmailAndPassword(
        email: 'test@example.com',
        password: 'test123456',
      );

      currentUser = credential.user;
      print('Created test user: ${currentUser?.uid}');
    } catch (e) {
      // User might already exist, try signing in
      try {
        final credential = await auth.signInWithEmailAndPassword(
          email: 'test@example.com',
          password: 'test123456',
        );
        currentUser = credential.user;
        print('Signed in existing test user: ${currentUser?.uid}');
      } catch (signInError) {
        print('Error creating/signing in test user: $signInError');
        rethrow;
      }
    }
  }

  /// Clean up resources
  Future<void> tearDown() async {
    try {
      await bloc.close();
      await auth.signOut();
      print('E2ETestHelper tearDown complete');
    } catch (e) {
      print('Error in tearDown: $e');
    }
  }

  /// Clear all data from emulator Firestore
  Future<void> clearFirestore() async {
    try {
      // Clear Item collection
      final itemsSnapshot = await firestore.collection('Item').get();
      for (final doc in itemsSnapshot.docs) {
        await doc.reference.delete();
      }

      // Clear EventLog collection
      final eventsSnapshot = await firestore.collection('EventLog').get();
      for (final doc in eventsSnapshot.docs) {
        await doc.reference.delete();
      }

      print('Cleared all data from Firestore emulator');
    } catch (e) {
      print('Error clearing Firestore: $e');
      rethrow;
    }
  }

  /// Seed test data into Firestore emulator
  Future<void> seedFirestore({
    required String userId,
    int itemCount = 3,
  }) async {
    final now = DateTime.now();

    for (int i = 1; i <= itemCount; i++) {
      await firestore.collection('Item').add({
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

    print('Seeded $itemCount items for user $userId');
  }

  /// Get test user ID
  String getTestUserId() {
    if (currentUser == null) {
      throw Exception('No test user signed in. Call setUp() first.');
    }
    return currentUser!.uid;
  }

  /// Get document count in a collection
  Future<int> getDocumentCount(String collectionName) async {
    final snapshot = await firestore.collection(collectionName).get();
    return snapshot.docs.length;
  }

  /// Check if emulator is running
  static Future<bool> isEmulatorRunning() async {
    try {
      final socket = await Socket.connect(
        firestoreEmulatorHost,
        firestoreEmulatorPort,
        timeout: const Duration(seconds: 2),
      );
      await socket.close();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get all items for a user from Firestore
  Future<List<Map<String, dynamic>>> getItemsFromFirestore(
      String userId) async {
    final snapshot = await firestore
        .collection('Item')
        .where('user_id', isEqualTo: userId)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  /// Check if an item exists in Firestore
  Future<bool> itemExistsInFirestore(String itemId) async {
    final doc = await firestore.collection('Item').doc(itemId).get();
    return doc.exists;
  }

  /// Get item data from Firestore
  Future<Map<String, dynamic>?> getItemFromFirestore(String itemId) async {
    final doc = await firestore.collection('Item').doc(itemId).get();
    if (!doc.exists) return null;

    final data = doc.data();
    if (data == null) return null;

    data['id'] = doc.id;
    return data;
  }

  /// Simulate network delay
  Future<void> simulateNetworkDelay({int milliseconds = 100}) async {
    await Future.delayed(Duration(milliseconds: milliseconds));
  }

  /// Create a second BLoC instance for multi-client testing
  ItemsBloc createSecondBloc() {
    return ItemsBloc(
      getItemsUseCase: getItemsUseCase,
      watchItemsUseCase: watchItemsUseCase,
      createItemUseCase: createItemUseCase,
      updateItemUseCase: updateItemUseCase,
      deleteItemUseCase: deleteItemUseCase,
      incrementItemUseCase: incrementItemUseCase,
    );
  }
}
