import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exceptions.dart';
import '../models/user_profile_model.dart';
import 'profile_remote_datasource.dart';

/// Implementation of [ProfileRemoteDataSource] using Firebase.
@LazySingleton(as: ProfileRemoteDataSource)
class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  ProfileRemoteDataSourceImpl({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<UserProfileModel> getProfile() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw AuthException('Not authenticated');
    }

    try {
      // Try to get profile from Firestore first
      final doc = await _firestore.collection('users').doc(user.uid).get();

      if (doc.exists) {
        return UserProfileModel.fromFirestore(doc);
      }

      // If no Firestore profile, create one from Firebase Auth user
      final profile = UserProfileModel.fromFirebaseUser(user);
      await _firestore.collection('users').doc(user.uid).set(profile.toFirestore());
      return profile;
    } catch (e) {
      if (e is AuthException) rethrow;
      throw ServerException('Failed to get profile: ${e.toString()}');
    }
  }

  @override
  Future<UserProfileModel> updateProfile({
    String? displayName,
    String? photoUrl,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw AuthException('Not authenticated');
    }

    try {
      // Update Firebase Auth profile
      await user.updateDisplayName(displayName);
      if (photoUrl != null) {
        await user.updatePhotoURL(photoUrl);
      }

      // Update Firestore profile
      final updates = <String, dynamic>{
        'last_login': DateTime.now().millisecondsSinceEpoch,
      };
      if (displayName != null) {
        updates['display_name'] = displayName;
      }
      if (photoUrl != null) {
        updates['photo_url'] = photoUrl;
      }

      await _firestore.collection('users').doc(user.uid).update(updates);

      return await getProfile();
    } catch (e) {
      if (e is AuthException) rethrow;
      throw ServerException('Failed to update profile: ${e.toString()}');
    }
  }

  @override
  Future<String> exportUserData() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw AuthException('Not authenticated');
    }

    try {
      // Gather profile data
      final profileDoc = await _firestore.collection('users').doc(user.uid).get();
      final profileData = profileDoc.data();

      // Gather items
      final itemsSnapshot = await _firestore
          .collection('Item')
          .where('user_id', isEqualTo: user.uid)
          .get();
      final items = itemsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['item_name'],
          'count': data['count'],
          'today_count': data['todaycount'],
          'increment_by': data['increment_by'],
          'reminder': data['reminder'],
          'reminder_value': data['reminder_value'],
          'last_reset_time': data['lastResetTime'],
          'last_updated': data['lastUpdated'],
        };
      }).toList();

      // Gather event logs
      final eventsSnapshot = await _firestore
          .collection('EventLog')
          .where('user_id', isEqualTo: user.uid)
          .get();
      final events = eventsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'item_id': data['item_id'],
          'event_name': data['eventName'],
          'increment': data['increment'],
          'timestamp': data['createdTime'],
        };
      }).toList();

      // Build export data
      final exportData = {
        'export_date': DateTime.now().toIso8601String(),
        'export_format_version': '1.0',
        'profile': {
          'user_id': user.uid,
          'email': user.email,
          'display_name': profileData?['display_name'] ?? user.displayName,
          'created_at': profileData?['created_at'],
          'last_login': profileData?['last_login'],
        },
        'items': items,
        'items_count': items.length,
        'events': events,
        'events_count': events.length,
      };

      return const JsonEncoder.withIndent('  ').convert(exportData);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw ServerException('Failed to export data: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteAccount() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw AuthException('Not authenticated');
    }

    try {
      final batch = _firestore.batch();
      final userRef = _firestore.collection('users').doc(user.uid);

      // Delete all items (uses DocumentReference for uid)
      final itemsSnapshot = await _firestore
          .collection('Item')
          .where('uid', isEqualTo: userRef)
          .get();
      for (final doc in itemsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete all event logs (uses string user_id)
      final eventsSnapshot = await _firestore
          .collection('EventLog')
          .where('user_id', isEqualTo: user.uid)
          .get();
      for (final doc in eventsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete all categories (uses DocumentReference for uid)
      final categoriesSnapshot = await _firestore
          .collection('Category')
          .where('uid', isEqualTo: userRef)
          .get();
      for (final doc in categoriesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete profile document
      batch.delete(userRef);

      // Commit batch delete
      await batch.commit();

      // Delete Firebase Auth account (must be last)
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw AuthException('Please sign in again to delete your account');
      }
      throw AuthException('Failed to delete account: ${e.message}');
    } catch (e) {
      if (e is AuthException) rethrow;
      throw ServerException('Failed to delete account: ${e.toString()}');
    }
  }
}
