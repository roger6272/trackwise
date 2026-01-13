import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/user.dart';

/// Repository interface for authentication operations.
///
/// Defines the contract for authentication that the domain layer expects.
/// Implementations handle the actual Firebase Auth integration.
abstract class AuthRepository {
  /// Sign in with email and password.
  Future<Either<Failure, User>> signInWithEmail(String email, String password);

  /// Sign in with Google.
  Future<Either<Failure, User>> signInWithGoogle();

  /// Sign in with Apple (iOS only).
  Future<Either<Failure, User>> signInWithApple();

  /// Create a new account with email and password.
  Future<Either<Failure, User>> signUp(String email, String password);

  /// Sign out the current user.
  Future<Either<Failure, void>> signOut();

  /// Send password reset email.
  Future<Either<Failure, void>> resetPassword(String email);

  /// Get the currently authenticated user.
  User? get currentUser;

  /// Watch authentication state changes.
  ///
  /// Emits the current user when signed in, null when signed out.
  Stream<User?> watchAuthState();
}
