import '../models/user_model.dart';

/// Data source interface for Firebase Authentication operations.
abstract class AuthFirebaseDataSource {
  /// Signs in with email and password.
  Future<UserModel> signInWithEmail(String email, String password);

  /// Signs in with Google.
  Future<UserModel> signInWithGoogle();

  /// Signs in with Apple.
  Future<UserModel> signInWithApple();

  /// Creates a new account with email and password.
  Future<UserModel> signUp(String email, String password);

  /// Signs out the current user.
  Future<void> signOut();

  /// Sends a password reset email.
  Future<void> resetPassword(String email);

  /// Gets the current user, or null if not signed in.
  UserModel? get currentUser;

  /// Stream of auth state changes.
  Stream<UserModel?> watchAuthState();
}
