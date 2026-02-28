import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:injectable/injectable.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../bluetooth/domain/entities/paired_device.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/user_repository.dart';
import '../models/user_model.dart';

/// Maximum number of devices that can be paired to a single account.
const int maxPairedDevices = 10;

/// Implementation of [UserRepository] using Firebase Auth and Firestore.
///
/// Manages user document data in Firestore for multi-device sync support.
@LazySingleton(as: UserRepository)
class UserRepositoryImpl implements UserRepository {
  final firebase.FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  UserRepositoryImpl({
    firebase.FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  })  : _firebaseAuth = firebaseAuth ?? firebase.FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  /// Gets the current Firebase Auth user or throws [AuthException].
  firebase.User _requireCurrentUser() {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw AuthException('Not authenticated');
    }
    return user;
  }

  /// Gets the user document reference for the current user.
  DocumentReference _userDocRef(String userId) {
    return _firestore.collection('users').doc(userId);
  }

  @override
  Future<Either<Failure, User>> getCurrentUser() async {
    try {
      final firebaseUser = _requireCurrentUser();
      final userDoc = await _userDocRef(firebaseUser.uid).get();

      final firestoreData =
          userDoc.exists ? userDoc.data() as Map<String, dynamic>? : null;

      final userModel = UserModel.fromFirebaseUserAndFirestore(
        firebaseUser,
        firestoreData,
      );

      return Right(userModel.toEntity());
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on FirebaseException catch (e) {
      return Left(ServerFailure('Failed to get user: ${e.message}'));
    } catch (e) {
      return Left(ServerFailure('Unexpected error getting user: $e'));
    }
  }

  @override
  Future<Either<Failure, int>> fetchSyncSequenceFromServer() async {
    try {
      final firebaseUser = _requireCurrentUser();

      // CRITICAL: Use GetOptions.serverAndCache with Source.server
      // to ensure we always get fresh data from Firestore, not cached.
      // This is essential for multi-device sync correctness.
      final userDoc = await _userDocRef(firebaseUser.uid).get(
        const GetOptions(source: Source.server),
      );

      if (!userDoc.exists) {
        // User document doesn't exist yet - return default
        return const Right(0);
      }

      final data = userDoc.data() as Map<String, dynamic>?;
      final syncSeq = data?['sync_sequence_no'] as int? ?? 0;

      return Right(syncSeq);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on FirebaseException catch (e) {
      return Left(ServerFailure('Failed to fetch sync sequence: ${e.message}'));
    } catch (e) {
      return Left(
          ServerFailure('Unexpected error fetching sync sequence: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> updateSyncState({
    required int syncSequenceNo,
    required int lastSelectedDeviceItemId,
  }) async {
    try {
      final firebaseUser = _requireCurrentUser();

      await _userDocRef(firebaseUser.uid).set(
        {
          'sync_sequence_no': syncSequenceNo,
          'last_selected_device_item_id': lastSelectedDeviceItemId,
        },
        SetOptions(merge: true),
      );

      return const Right(null);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on FirebaseException catch (e) {
      return Left(ServerFailure('Failed to update sync state: ${e.message}'));
    } catch (e) {
      return Left(ServerFailure('Unexpected error updating sync state: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> addPairedDevice(PairedDevice device) async {
    try {
      final firebaseUser = _requireCurrentUser();
      final userDocRef = _userDocRef(firebaseUser.uid);

      // Use transaction to ensure atomicity when checking device limit
      await _firestore.runTransaction((transaction) async {
        final userDoc = await transaction.get(userDocRef);

        List<dynamic> existingDevices = [];
        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>?;
          existingDevices = data?['paired_devices'] as List<dynamic>? ?? [];
        }

        // Check device limit
        if (existingDevices.length >= maxPairedDevices) {
          throw const ValidationFailure(
            'Maximum $maxPairedDevices devices allowed per account',
          );
        }

        // Check if device already exists (by device_instance_id)
        final alreadyPaired = existingDevices.any((d) {
          final deviceMap = d as Map<String, dynamic>;
          return deviceMap['device_instance_id'] == device.deviceInstanceId;
        });

        if (alreadyPaired) {
          // Device already paired - no-op
          return;
        }

        // Add new device to array
        existingDevices.add(device.toFirestore());

        transaction.set(
          userDocRef,
          {'paired_devices': existingDevices},
          SetOptions(merge: true),
        );
      });

      return const Right(null);
    } on ValidationFailure catch (e) {
      return Left(e);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on FirebaseException catch (e) {
      return Left(ServerFailure('Failed to add paired device: ${e.message}'));
    } catch (e) {
      return Left(ServerFailure('Unexpected error adding paired device: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> removePairedDevice(
      String deviceInstanceId) async {
    try {
      final firebaseUser = _requireCurrentUser();
      final userDocRef = _userDocRef(firebaseUser.uid);

      // Get current devices and filter out the one to remove
      final userDoc = await userDocRef.get();

      if (!userDoc.exists) {
        return const Right(null); // Nothing to remove
      }

      final data = userDoc.data() as Map<String, dynamic>?;
      final existingDevices = data?['paired_devices'] as List<dynamic>? ?? [];

      // Filter out the device to remove
      final updatedDevices = existingDevices.where((d) {
        final deviceMap = d as Map<String, dynamic>;
        return deviceMap['device_instance_id'] != deviceInstanceId;
      }).toList();

      // Update the document
      await userDocRef.update({'paired_devices': updatedDevices});

      return const Right(null);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on FirebaseException catch (e) {
      return Left(
          ServerFailure('Failed to remove paired device: ${e.message}'));
    } catch (e) {
      return Left(
          ServerFailure('Unexpected error removing paired device: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> updateDeviceName(
    String deviceInstanceId,
    String newName,
  ) async {
    try {
      final firebaseUser = _requireCurrentUser();
      final userDocRef = _userDocRef(firebaseUser.uid);

      final userDoc = await userDocRef.get();

      if (!userDoc.exists) {
        return const Left(ValidationFailure('Device not found'));
      }

      final data = userDoc.data() as Map<String, dynamic>?;
      final existingDevices = data?['paired_devices'] as List<dynamic>? ?? [];

      // Find and update the device
      bool found = false;
      final updatedDevices = existingDevices.map((d) {
        final deviceMap = Map<String, dynamic>.from(d as Map<String, dynamic>);
        if (deviceMap['device_instance_id'] == deviceInstanceId) {
          found = true;
          deviceMap['device_name'] = newName;
        }
        return deviceMap;
      }).toList();

      if (!found) {
        return const Left(ValidationFailure('Device not found'));
      }

      // Update the document
      await userDocRef.update({'paired_devices': updatedDevices});

      return const Right(null);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on FirebaseException catch (e) {
      return Left(ServerFailure('Failed to update device name: ${e.message}'));
    } catch (e) {
      return Left(ServerFailure('Unexpected error updating device name: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> updateDeviceColor(
    String deviceInstanceId,
    int newColor,
  ) async {
    try {
      final firebaseUser = _requireCurrentUser();
      final userDocRef = _userDocRef(firebaseUser.uid);

      final userDoc = await userDocRef.get();

      if (!userDoc.exists) {
        return const Left(ValidationFailure('Device not found'));
      }

      final data = userDoc.data() as Map<String, dynamic>?;
      final existingDevices = data?['paired_devices'] as List<dynamic>? ?? [];

      // Find and update the device
      bool found = false;
      final updatedDevices = existingDevices.map((d) {
        final deviceMap = Map<String, dynamic>.from(d as Map<String, dynamic>);
        if (deviceMap['device_instance_id'] == deviceInstanceId) {
          found = true;
          deviceMap['color'] = newColor;
        }
        return deviceMap;
      }).toList();

      if (!found) {
        return const Left(ValidationFailure('Device not found'));
      }

      // Update the document
      await userDocRef.update({'paired_devices': updatedDevices});

      return const Right(null);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on FirebaseException catch (e) {
      return Left(ServerFailure('Failed to update device color: ${e.message}'));
    } catch (e) {
      return Left(ServerFailure('Unexpected error updating device color: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> addStaleClaim(
    String deviceInstanceId,
    String itemName,
  ) async {
    try {
      final firebaseUser = _requireCurrentUser();
      final userDocRef = _userDocRef(firebaseUser.uid);

      final userDoc = await userDocRef.get();
      if (!userDoc.exists) return const Right(null);

      final data = userDoc.data() as Map<String, dynamic>?;
      final existingDevices = data?['paired_devices'] as List<dynamic>? ?? [];

      final updatedDevices = existingDevices.map((d) {
        final deviceMap = Map<String, dynamic>.from(d as Map<String, dynamic>);
        if (deviceMap['device_instance_id'] == deviceInstanceId) {
          final claims = List<String>.from(
            deviceMap['stale_claims'] as List<dynamic>? ?? [],
          );
          if (!claims.contains(itemName)) claims.add(itemName);
          deviceMap['stale_claims'] = claims;
        }
        return deviceMap;
      }).toList();

      await userDocRef.update({'paired_devices': updatedDevices});
      return const Right(null);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on FirebaseException catch (e) {
      return Left(ServerFailure('Failed to add stale claim: ${e.message}'));
    } catch (e) {
      return Left(ServerFailure('Unexpected error adding stale claim: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> clearStaleClaims(
    String deviceInstanceId,
  ) async {
    try {
      final firebaseUser = _requireCurrentUser();
      final userDocRef = _userDocRef(firebaseUser.uid);

      final userDoc = await userDocRef.get();
      if (!userDoc.exists) return const Right(null);

      final data = userDoc.data() as Map<String, dynamic>?;
      final existingDevices = data?['paired_devices'] as List<dynamic>? ?? [];

      final updatedDevices = existingDevices.map((d) {
        final deviceMap = Map<String, dynamic>.from(d as Map<String, dynamic>);
        if (deviceMap['device_instance_id'] == deviceInstanceId) {
          deviceMap.remove('stale_claims');
        }
        return deviceMap;
      }).toList();

      await userDocRef.update({'paired_devices': updatedDevices});
      return const Right(null);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on FirebaseException catch (e) {
      return Left(ServerFailure('Failed to clear stale claims: ${e.message}'));
    } catch (e) {
      return Left(ServerFailure('Unexpected error clearing stale claims: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> completeOnboarding({
    String? displayName,
    required String primaryUseCase,
    String? referralSource,
    bool? onboardingDevicePaired,
    bool? onboardingItemCreated,
  }) async {
    try {
      final firebaseUser = _requireCurrentUser();
      final userDocRef = _userDocRef(firebaseUser.uid);

      // Build update data
      final updateData = <String, dynamic>{
        'onboarding_completed': true,
        'primary_use_case': primaryUseCase,
      };

      if (referralSource != null && referralSource.isNotEmpty) {
        updateData['referral_source'] = referralSource;
      }

      if (onboardingDevicePaired != null) {
        updateData['onboarding_device_paired'] = onboardingDevicePaired;
      }
      if (onboardingItemCreated != null) {
        updateData['onboarding_item_created'] = onboardingItemCreated;
      }

      // Update Firestore
      await userDocRef.set(updateData, SetOptions(merge: true));

      // Update display name in Firebase Auth if provided
      if (displayName != null && displayName.isNotEmpty) {
        await firebaseUser.updateDisplayName(displayName);
      }

      return const Right(null);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on FirebaseException catch (e) {
      return Left(ServerFailure('Failed to complete onboarding: ${e.message}'));
    } catch (e) {
      return Left(ServerFailure('Unexpected error during onboarding: $e'));
    }
  }
}
