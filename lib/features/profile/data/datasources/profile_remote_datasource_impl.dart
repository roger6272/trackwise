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
        final firestoreProfile = UserProfileModel.fromFirestore(doc);
        // Merge with Firebase Auth data - prefer Firebase Auth displayName
        // as it may have been updated during onboarding
        return firestoreProfile.copyWith(
          email: user.email ?? firestoreProfile.email,
          displayName: user.displayName ?? firestoreProfile.displayName,
          photoUrl: user.photoURL ?? firestoreProfile.photoUrl,
        );
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
      final userRef = _firestore.collection('users').doc(user.uid);
      final profileDoc = await userRef.get();
      final profileData = profileDoc.data();

      // Gather active items (exclude soft-deleted; uid as DocumentReference)
      final itemsSnapshot = await _firestore
          .collection('Item')
          .where('uid', isEqualTo: userRef)
          .get();
      final items = itemsSnapshot.docs
          .where((doc) => doc.data()['deletedAt'] == null)
          .map((doc) {
        final data = doc.data();
        // Resolve categoryId from DocumentReference or String
        String? categoryId;
        final catField = data['category_id'];
        if (catField is DocumentReference) {
          categoryId = catField.id;
        } else if (catField is String) {
          categoryId = catField.isEmpty ? null : catField;
        }
        return {
          'id': doc.id,
          'name': data['item_name'],
          'count': data['count'],
          'today_count': data['todaycount'],
          'increment_by': data['increment_by'],
          'reminder': data['reminder'],
          'reminder_value': data['reminder_value'],
          'initial_count': data['initial_count'],
          'goal': data['goal'],
          'reset_number': data['reset_number'],
          'category_id': categoryId,
          'cycle_names': data['cycle_names'],
          'cycle_notes': data['cycle_notes'],
          'last_reset_time': data['lastResetTime'],
          'last_updated': data['lastUpdated'],
        };
      }).toList();

      // Gather categories (exclude soft-deleted; uid as DocumentReference)
      final categoriesSnapshot = await _firestore
          .collection('Category')
          .where('uid', isEqualTo: userRef)
          .get();
      final categories = categoriesSnapshot.docs
          .where((doc) => doc.data()['deleted_at'] == null)
          .map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['category_name'],
          'created_at': data['created_time'],
        };
      }).toList();

      // Gather event logs (uid stored as DocumentReference, not string)
      final eventsSnapshot = await _firestore
          .collection('EventLog')
          .where('uid', isEqualTo: userRef)
          .get();
      final events = eventsSnapshot.docs.map((doc) {
        final data = doc.data();
        // Extract itemId from DocumentReference (field is 'item', not 'item_id')
        String? itemId;
        final itemRef = data['item'];
        if (itemRef is DocumentReference) {
          itemId = itemRef.id;
        } else if (itemRef is String) {
          itemId = itemRef;
        }
        return {
          'id': doc.id,
          'item_id': itemId,
          'event_name': data['event_name'],
          'increment': data['increment'],
          'timestamp': data['created_time'],
          'reset_number': data['reset_number'],
          'device_instance_id': data['device_instance_id'],
        };
      }).toList();

      // Build export data
      final exportData = {
        'export_date': DateTime.now().toIso8601String(),
        'export_format_version': '1.1',
        'profile': {
          'user_id': user.uid,
          'email': user.email,
          'display_name': profileData?['display_name'] ?? user.displayName,
          'created_at': profileData?['created_at'],
          'last_login': profileData?['last_login'],
        },
        'items': items,
        'items_count': items.length,
        'categories': categories,
        'categories_count': categories.length,
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

    final userId = user.uid;
    final userRef = _firestore.collection('users').doc(userId);

    // Try to delete Firebase Auth account FIRST
    // This requires recent authentication - if it fails, no data is deleted yet
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw AuthException('Please sign in again to delete your account');
      }
      throw AuthException('Failed to delete account: ${e.message}');
    }

    // Auth account deleted successfully, now clean up Firestore data
    // Even if this fails, the account is gone and data will be orphaned
    try {
      // Collect all document references to delete
      final allRefs = <DocumentReference>[];

      final itemsSnapshot = await _firestore
          .collection('Item')
          .where('uid', isEqualTo: userRef)
          .get();
      allRefs.addAll(itemsSnapshot.docs.map((d) => d.reference));

      final eventsSnapshot = await _firestore
          .collection('EventLog')
          .where('uid', isEqualTo: userRef)
          .get();
      allRefs.addAll(eventsSnapshot.docs.map((d) => d.reference));

      final categoriesSnapshot = await _firestore
          .collection('Category')
          .where('uid', isEqualTo: userRef)
          .get();
      allRefs.addAll(categoriesSnapshot.docs.map((d) => d.reference));

      allRefs.add(userRef);

      // Firestore batch limit is 500 operations — split into chunks
      const batchLimit = 499;
      for (var i = 0; i < allRefs.length; i += batchLimit) {
        final batch = _firestore.batch();
        final end = (i + batchLimit < allRefs.length) ? i + batchLimit : allRefs.length;
        for (var j = i; j < end; j++) {
          batch.delete(allRefs[j]);
        }
        await batch.commit();
      }
    } catch (e) {
      // Firestore cleanup failed, but account is already deleted
      // Data will be orphaned but user can't access it anymore
    }
  }
}
