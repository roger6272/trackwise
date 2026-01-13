import 'package:injectable/injectable.dart';

import '../entities/user.dart';
import '../repositories/auth_repository.dart';

/// Use case for watching authentication state changes.
///
/// This is a stream-based use case that doesn't follow the standard
/// UseCase pattern since it returns a Stream instead of Future<Either>.
@injectable
class WatchAuthStateUseCase {
  final AuthRepository repository;

  WatchAuthStateUseCase(this.repository);

  /// Watch auth state changes.
  ///
  /// Returns a stream that emits:
  /// - User when signed in
  /// - null when signed out
  Stream<User?> call() {
    return repository.watchAuthState();
  }

  /// Get the current user synchronously.
  User? get currentUser => repository.currentUser;
}
