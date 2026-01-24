import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:injectable/injectable.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../../core/error/exceptions.dart';
import '../models/user_model.dart';
import 'auth_firebase_datasource.dart';

/// Implementation of [AuthFirebaseDataSource] using Firebase Auth.
@LazySingleton(as: AuthFirebaseDataSource)
class AuthFirebaseDataSourceImpl implements AuthFirebaseDataSource {
  final firebase.FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;

  AuthFirebaseDataSourceImpl({
    firebase.FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
  })  : _firebaseAuth = firebaseAuth ?? firebase.FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn(scopes: ['profile', 'email']);

  /// Creates or updates user document in Firestore.
  Future<void> _ensureUserDocument(firebase.User user) async {
    debugPrint('🔐 _ensureUserDocument: checking for ${user.uid}');
    final userDoc = _firestore.collection('users').doc(user.uid);
    final docSnapshot = await userDoc.get();

    if (!docSnapshot.exists) {
      debugPrint('🔐 _ensureUserDocument: document MISSING, creating...');
      // Create new user document
      await userDoc.set({
        'uid': user.uid,
        'email': user.email,
        'display_name': user.displayName,
        'photo_url': user.photoURL,
        'created_time': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Created user document for ${user.uid}');
    } else {
      debugPrint('🔐 _ensureUserDocument: document EXISTS');
    }
  }

  @override
  Future<UserModel> signInWithEmail(String email, String password) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (credential.user == null) {
        throw AuthException('Sign in failed: No user returned');
      }

      // Ensure user document exists (for backwards compatibility with old accounts)
      await _ensureUserDocument(credential.user!);

      return UserModel.fromFirebaseUser(credential.user!);
    } on firebase.FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e));
    }
  }

  @override
  Future<UserModel> signInWithGoogle() async {
    try {
      firebase.UserCredential credential;

      if (kIsWeb) {
        credential = await _firebaseAuth.signInWithPopup(
          firebase.GoogleAuthProvider(),
        );
      } else {
        // Sign out first to allow account selection
        await _googleSignIn.signOut().catchError((_) => null);

        final googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          throw AuthException('Google sign-in was cancelled');
        }

        final googleAuth = await googleUser.authentication;
        final authCredential = firebase.GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
          accessToken: googleAuth.accessToken,
        );

        credential = await _firebaseAuth.signInWithCredential(authCredential);
      }

      if (credential.user == null) {
        throw AuthException('Google sign-in failed: No user returned');
      }

      // Ensure user document exists in Firestore
      await _ensureUserDocument(credential.user!);

      return UserModel.fromFirebaseUser(credential.user!);
    } on firebase.FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e));
    }
  }

  @override
  Future<UserModel> signInWithApple() async {
    try {
      firebase.UserCredential credential;

      if (kIsWeb) {
        final provider = firebase.OAuthProvider('apple.com')
          ..addScope('email')
          ..addScope('name');
        credential = await _firebaseAuth.signInWithPopup(provider);
      } else {
        final rawNonce = _generateNonce();
        final nonce = _sha256ofString(rawNonce);

        final appleCredential = await SignInWithApple.getAppleIDCredential(
          scopes: [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
          nonce: nonce,
        );

        final oauthCredential = firebase.OAuthProvider('apple.com').credential(
          idToken: appleCredential.identityToken,
          rawNonce: rawNonce,
          accessToken: appleCredential.authorizationCode,
        );

        credential = await _firebaseAuth.signInWithCredential(oauthCredential);

        // Update display name from Apple credential
        final displayName = [
          appleCredential.givenName,
          appleCredential.familyName,
        ].where((name) => name != null).join(' ');

        if (displayName.isNotEmpty) {
          await credential.user?.updateDisplayName(displayName);
        }
      }

      if (credential.user == null) {
        throw AuthException('Apple sign-in failed: No user returned');
      }

      // Ensure user document exists in Firestore
      await _ensureUserDocument(credential.user!);

      return UserModel.fromFirebaseUser(credential.user!);
    } on firebase.FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e));
    } on SignInWithAppleAuthorizationException catch (e) {
      throw AuthException('Apple sign-in failed: ${e.message}');
    }
  }

  @override
  Future<UserModel> signUp(String email, String password) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (credential.user == null) {
        throw AuthException('Sign up failed: No user returned');
      }

      // Create user document in Firestore
      await _ensureUserDocument(credential.user!);

      return UserModel.fromFirebaseUser(credential.user!);
    } on firebase.FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e));
    }
  }

  @override
  Future<void> signOut() async {
    try {
      // Sign out from Google if applicable
      await _googleSignIn.signOut().catchError((_) => null);
      await _firebaseAuth.signOut();
    } on firebase.FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e));
    }
  }

  @override
  Future<void> resetPassword(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
    } on firebase.FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e));
    }
  }

  @override
  UserModel? get currentUser {
    final user = _firebaseAuth.currentUser;
    return user != null ? UserModel.fromFirebaseUser(user) : null;
  }

  @override
  Stream<UserModel?> watchAuthState() {
    return _firebaseAuth.authStateChanges().map((user) {
      return user != null ? UserModel.fromFirebaseUser(user) : null;
    });
  }

  /// Maps Firebase auth error codes to user-friendly messages.
  String _mapFirebaseAuthError(firebase.FirebaseAuthException e) {
    return switch (e.code) {
      'email-already-in-use' =>
        'This email is already in use by another account',
      'invalid-email' => 'The email address is invalid',
      'operation-not-allowed' => 'This sign-in method is not enabled',
      'weak-password' => 'The password is too weak',
      'user-disabled' => 'This account has been disabled',
      'user-not-found' => 'No account found with this email',
      'wrong-password' => 'Incorrect password',
      'INVALID_LOGIN_CREDENTIALS' => 'Invalid email or password',
      'invalid-credential' => 'Invalid email or password',
      'too-many-requests' => 'Too many attempts. Please try again later',
      'requires-recent-login' => 'Please sign in again to complete this action',
      _ => e.message ?? 'An authentication error occurred',
    };
  }

  /// Generates a cryptographically secure random nonce for Apple sign-in.
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  /// Returns the sha256 hash of [input] in hex notation.
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
