/// Test helper utilities and shared test setup.
///
/// This file provides common utilities used across all test files.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

// Generate mocks using build_runner:
// flutter pub run build_runner build --delete-conflicting-outputs
@GenerateMocks([
  FirebaseFirestore,
  FirebaseAuth,
  User,
  CollectionReference,
  DocumentReference,
  DocumentSnapshot,
  QuerySnapshot,
  Query,
])
class TestHelpers {}

/// Reset GetIt service locator for testing.
///
/// Call this in setUp() to ensure clean state between tests.
void resetServiceLocator() {
  final sl = GetIt.instance;
  if (sl.isRegistered<FirebaseFirestore>()) {
    sl.unregister<FirebaseFirestore>();
  }
  if (sl.isRegistered<FirebaseAuth>()) {
    sl.unregister<FirebaseAuth>();
  }
}

/// Register mock Firebase instances for testing.
///
/// Call this after resetServiceLocator() to inject mocks.
void registerMockFirebaseInstances({
  required FirebaseFirestore mockFirestore,
  required FirebaseAuth mockAuth,
}) {
  final sl = GetIt.instance;
  sl.registerLazySingleton<FirebaseFirestore>(() => mockFirestore);
  sl.registerLazySingleton<FirebaseAuth>(() => mockAuth);
}
