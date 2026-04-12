import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_firebase_datasource.dart';

/// Implementation of [AuthRepository] using Firebase Authentication.
@LazySingleton(as: AuthRepository)
class AuthRepositoryImpl implements AuthRepository {
  final AuthFirebaseDataSource dataSource;

  AuthRepositoryImpl({required this.dataSource});

  @override
  Future<Either<Failure, User>> signInWithEmail(
    String email,
    String password,
  ) async {
    try {
      final userModel = await dataSource.signInWithEmail(email, password);
      return Right(userModel.toEntity());
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } catch (e, stackTrace) {
      AppLogger.error('signInWithEmail unexpected error: $e', e, stackTrace);
      return Left(AuthFailure('Sign in failed. Please check your connection and try again.'));
    }
  }

  @override
  Future<Either<Failure, User>> signInWithGoogle() async {
    try {
      final userModel = await dataSource.signInWithGoogle();
      return Right(userModel.toEntity());
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } catch (e, stackTrace) {
      AppLogger.error('signInWithGoogle unexpected error: $e', e, stackTrace);
      return Left(AuthFailure('Google sign-in failed. Please check your connection and try again.'));
    }
  }

  @override
  Future<Either<Failure, User>> signInWithApple() async {
    try {
      final userModel = await dataSource.signInWithApple();
      return Right(userModel.toEntity());
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } catch (e, stackTrace) {
      AppLogger.error('signInWithApple unexpected error: $e', e, stackTrace);
      return Left(AuthFailure('Apple sign-in failed. Please check your connection and try again.'));
    }
  }

  @override
  Future<Either<Failure, User>> signUp(String email, String password) async {
    try {
      final userModel = await dataSource.signUp(email, password);
      return Right(userModel.toEntity());
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } catch (e, stackTrace) {
      AppLogger.error('signUp unexpected error: $e', e, stackTrace);
      return Left(AuthFailure('Sign up failed. Please check your connection and try again.'));
    }
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    try {
      await dataSource.signOut();
      return const Right(null);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } catch (e, stackTrace) {
      AppLogger.error('signOut unexpected error: $e', e, stackTrace);
      return Left(AuthFailure('Sign out failed. Please try again.'));
    }
  }

  @override
  Future<Either<Failure, void>> resetPassword(String email) async {
    try {
      await dataSource.resetPassword(email);
      return const Right(null);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } catch (e, stackTrace) {
      AppLogger.error('resetPassword unexpected error: $e', e, stackTrace);
      return Left(AuthFailure('Password reset failed. Please try again.'));
    }
  }

  @override
  User? get currentUser {
    final userModel = dataSource.currentUser;
    return userModel?.toEntity();
  }

  @override
  Stream<User?> watchAuthState() {
    return dataSource.watchAuthState().map((userModel) {
      return userModel?.toEntity();
    });
  }

  @override
  Future<Either<Failure, String>> reauthenticate() async {
    try {
      final providerId = await dataSource.reauthenticate();
      return Right(providerId);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } catch (e, stackTrace) {
      AppLogger.error('reauthenticate unexpected error: $e', e, stackTrace);
      return Left(AuthFailure('Re-authentication failed. Please try again.'));
    }
  }
}
