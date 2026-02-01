import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/utils/logger.dart';
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
  ///
  /// Returns the Firestore document data (for use in creating UserModel).
  /// New documents always have onboarding_completed=false.
  /// Existing documents without onboarding_completed field also get it set to false.
  Future<Map<String, dynamic>?> _ensureUserDocument(firebase.User user) async {
    AppLogger.debug('_ensureUserDocument: checking for ${user.uid}');
    final userDoc = _firestore.collection('users').doc(user.uid);
    final docSnapshot = await userDoc.get();

    if (!docSnapshot.exists) {
      AppLogger.debug('_ensureUserDocument: document MISSING, creating...');
      // Create new user document - always require onboarding for new documents
      final newDocData = {
        'uid': user.uid,
        'email': user.email,
        'display_name': user.displayName,
        'photo_url': user.photoURL,
        'created_time': FieldValue.serverTimestamp(),
        'onboarding_completed': false,
      };
      await userDoc.set(newDocData);
      AppLogger.debug('Created user document for ${user.uid} with onboarding_completed=false');
      return newDocData;
    } else {
      AppLogger.debug('_ensureUserDocument: document EXISTS');
      final data = docSnapshot.data() as Map<String, dynamic>?;

      // If document exists but doesn't have onboarding_completed, set it to true
      // These are existing users who signed up before onboarding was implemented
      // They don't need to go through onboarding again
      if (data != null && !data.containsKey('onboarding_completed')) {
        AppLogger.debug('_ensureUserDocument: legacy user, setting onboarding_completed=true');
        await userDoc.update({'onboarding_completed': true});
        return {...data, 'onboarding_completed': true};
      }

      return data;
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
      final firestoreData = await _ensureUserDocument(credential.user!);

      return UserModel.fromFirebaseUserAndFirestore(credential.user!, firestoreData);
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
      final firestoreData = await _ensureUserDocument(credential.user!);

      return UserModel.fromFirebaseUserAndFirestore(credential.user!, firestoreData);
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
      final firestoreData = await _ensureUserDocument(credential.user!);

      return UserModel.fromFirebaseUserAndFirestore(credential.user!, firestoreData);
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

      // Create user document in Firestore (new signup needs onboarding)
      final firestoreData = await _ensureUserDocument(credential.user!);

      return UserModel.fromFirebaseUserAndFirestore(credential.user!, firestoreData);
    } on firebase.FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e));
    }
  }

  @override
  Future<String> reauthenticate() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw AuthException('Not authenticated');
    }

    // Find the provider used to sign in
    final providerIds = user.providerData.map((p) => p.providerId).toList();

    try {
      if (providerIds.contains('google.com')) {
        // Reauthenticate with Google
        if (kIsWeb) {
          final provider = firebase.GoogleAuthProvider();
          await user.reauthenticateWithPopup(provider);
        } else {
          await _googleSignIn.signOut().catchError((_) => null);
          final googleUser = await _googleSignIn.signIn();
          if (googleUser == null) {
            throw AuthException('Google sign-in was cancelled');
          }
          final googleAuth = await googleUser.authentication;
          final credential = firebase.GoogleAuthProvider.credential(
            idToken: googleAuth.idToken,
            accessToken: googleAuth.accessToken,
          );
          await user.reauthenticateWithCredential(credential);
        }
        return 'google.com';
      } else if (providerIds.contains('apple.com')) {
        // Reauthenticate with Apple
        if (kIsWeb) {
          final provider = firebase.OAuthProvider('apple.com')
            ..addScope('email')
            ..addScope('name');
          await user.reauthenticateWithPopup(provider);
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
          await user.reauthenticateWithCredential(oauthCredential);
        }
        return 'apple.com';
      } else {
        // Email/password - can't auto-reauthenticate without password
        throw AuthException('Please sign out and sign in again');
      }
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
