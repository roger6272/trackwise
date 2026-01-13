import 'package:equatable/equatable.dart';

import '../../domain/entities/user.dart';

/// Base class for all authentication states.
abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Initial state before auth status is determined.
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// State when an auth operation is in progress.
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// State when user is authenticated.
class Authenticated extends AuthState {
  final User user;

  const Authenticated(this.user);

  @override
  List<Object?> get props => [user];
}

/// State when user is not authenticated.
class Unauthenticated extends AuthState {
  const Unauthenticated();
}

/// State when an auth operation fails.
class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}

/// State when password reset email was sent successfully.
class PasswordResetSent extends AuthState {
  const PasswordResetSent();
}
