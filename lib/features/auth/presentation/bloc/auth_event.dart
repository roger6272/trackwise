import 'package:equatable/equatable.dart';

import '../../domain/entities/user.dart';

/// Base class for all authentication events.
abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Event to sign in with email and password.
class SignInWithEmailEvent extends AuthEvent {
  final String email;
  final String password;

  const SignInWithEmailEvent({
    required this.email,
    required this.password,
  });

  @override
  List<Object?> get props => [email, password];
}

/// Event to sign in with Google.
class SignInWithGoogleEvent extends AuthEvent {
  const SignInWithGoogleEvent();
}

/// Event to sign in with Apple.
class SignInWithAppleEvent extends AuthEvent {
  const SignInWithAppleEvent();
}

/// Event to create a new account.
class SignUpEvent extends AuthEvent {
  final String email;
  final String password;

  const SignUpEvent({
    required this.email,
    required this.password,
  });

  @override
  List<Object?> get props => [email, password];
}

/// Event to sign out the current user.
class SignOutEvent extends AuthEvent {
  const SignOutEvent();
}

/// Event to send a password reset email.
class ResetPasswordEvent extends AuthEvent {
  final String email;

  const ResetPasswordEvent({required this.email});

  @override
  List<Object?> get props => [email];
}

/// Event triggered when auth state changes (from stream).
class AuthStateChangedEvent extends AuthEvent {
  final User? user;

  const AuthStateChangedEvent(this.user);

  @override
  List<Object?> get props => [user];
}

/// Event to check initial auth state on app start.
class CheckAuthStatusEvent extends AuthEvent {
  const CheckAuthStatusEvent();
}
