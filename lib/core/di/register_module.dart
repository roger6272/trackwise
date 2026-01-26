import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:injectable/injectable.dart';

import '../state/app_ui_state.dart';

/// Module for registering external dependencies that cannot be annotated.
///
/// This includes Firebase instances, third-party packages, and other
/// dependencies that come from external sources.
@module
abstract class RegisterModule {
  /// Firebase Firestore singleton instance
  @lazySingleton
  FirebaseFirestore get firestore => FirebaseFirestore.instance;

  /// Firebase Auth singleton instance
  @lazySingleton
  FirebaseAuth get firebaseAuth => FirebaseAuth.instance;

  /// Google Sign-In instance
  @lazySingleton
  GoogleSignIn get googleSignIn => GoogleSignIn(scopes: ['profile', 'email']);

  /// App UI State singleton instance
  @lazySingleton
  AppUiState get appUiState => AppUiState();

  /// Connectivity instance for checking network status
  @lazySingleton
  Connectivity get connectivity => Connectivity();
}
