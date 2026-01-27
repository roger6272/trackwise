import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/usecases/usecase.dart';
import '../../domain/repositories/user_repository.dart';
import '../../domain/usecases/reset_password_usecase.dart';
import '../../domain/usecases/sign_in_with_apple_usecase.dart';
import '../../domain/usecases/sign_in_with_email_usecase.dart';
import '../../domain/usecases/sign_in_with_google_usecase.dart';
import '../../domain/usecases/sign_out_usecase.dart';
import '../../domain/usecases/sign_up_usecase.dart';
import '../../domain/usecases/watch_auth_state_usecase.dart';
import 'auth_event.dart';
import 'auth_state.dart';

/// BLoC for managing authentication state.
@injectable
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final SignInWithEmailUseCase _signInWithEmail;
  final SignInWithGoogleUseCase _signInWithGoogle;
  final SignInWithAppleUseCase _signInWithApple;
  final SignUpUseCase _signUp;
  final SignOutUseCase _signOut;
  final ResetPasswordUseCase _resetPassword;
  final WatchAuthStateUseCase _watchAuthState;
  final UserRepository _userRepository;

  StreamSubscription? _authSubscription;

  AuthBloc({
    required SignInWithEmailUseCase signInWithEmail,
    required SignInWithGoogleUseCase signInWithGoogle,
    required SignInWithAppleUseCase signInWithApple,
    required SignUpUseCase signUp,
    required SignOutUseCase signOut,
    required ResetPasswordUseCase resetPassword,
    required WatchAuthStateUseCase watchAuthState,
    required UserRepository userRepository,
  })  : _signInWithEmail = signInWithEmail,
        _signInWithGoogle = signInWithGoogle,
        _signInWithApple = signInWithApple,
        _signUp = signUp,
        _signOut = signOut,
        _resetPassword = resetPassword,
        _watchAuthState = watchAuthState,
        _userRepository = userRepository,
        super(const AuthInitial()) {
    on<CheckAuthStatusEvent>(_onCheckAuthStatus);
    on<SignInWithEmailEvent>(_onSignInWithEmail);
    on<SignInWithGoogleEvent>(_onSignInWithGoogle);
    on<SignInWithAppleEvent>(_onSignInWithApple);
    on<SignUpEvent>(_onSignUp);
    on<SignOutEvent>(_onSignOut);
    on<ResetPasswordEvent>(_onResetPassword);
    on<AuthStateChangedEvent>(_onAuthStateChanged);
  }

  void _startWatchingAuthState() {
    _authSubscription?.cancel();
    _authSubscription = _watchAuthState().listen(
      (user) => add(AuthStateChangedEvent(user)),
    );
  }

  Future<void> _onCheckAuthStatus(
    CheckAuthStatusEvent event,
    Emitter<AuthState> emit,
  ) async {
    // Check if there's a logged-in user
    final currentUser = _watchAuthState.currentUser;
    if (currentUser != null) {
      // Fetch full user data from Firestore (includes onboarding_completed)
      final result = await _userRepository.getCurrentUser();
      result.fold(
        // If fetch fails, use basic user data
        (_) => emit(Authenticated(currentUser)),
        (fullUser) => emit(Authenticated(fullUser)),
      );
    } else {
      emit(const Unauthenticated());
    }

    // Start watching for future auth changes
    _startWatchingAuthState();
  }

  Future<void> _onAuthStateChanged(
    AuthStateChangedEvent event,
    Emitter<AuthState> emit,
  ) async {
    if (event.user != null) {
      emit(Authenticated(event.user!));
    } else {
      emit(const Unauthenticated());
    }
  }

  Future<void> _onSignInWithEmail(
    SignInWithEmailEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    final result = await _signInWithEmail(
      SignInWithEmailParams(
        email: event.email,
        password: event.password,
      ),
    );

    result.fold(
      (failure) => emit(AuthError(failure.message)),
      (user) => emit(Authenticated(user)),
    );
  }

  Future<void> _onSignInWithGoogle(
    SignInWithGoogleEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    final result = await _signInWithGoogle(const NoParams());

    result.fold(
      (failure) => emit(AuthError(failure.message)),
      (user) => emit(Authenticated(user)),
    );
  }

  Future<void> _onSignInWithApple(
    SignInWithAppleEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    final result = await _signInWithApple(const NoParams());

    result.fold(
      (failure) => emit(AuthError(failure.message)),
      (user) => emit(Authenticated(user)),
    );
  }

  Future<void> _onSignUp(
    SignUpEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    final result = await _signUp(
      SignUpParams(
        email: event.email,
        password: event.password,
      ),
    );

    result.fold(
      (failure) => emit(AuthError(failure.message)),
      (user) => emit(Authenticated(user)),
    );
  }

  Future<void> _onSignOut(
    SignOutEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    final result = await _signOut(const NoParams());

    result.fold(
      (failure) => emit(AuthError(failure.message)),
      (_) => emit(const Unauthenticated()),
    );
  }

  Future<void> _onResetPassword(
    ResetPasswordEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    final result = await _resetPassword(
      ResetPasswordParams(email: event.email),
    );

    result.fold(
      (failure) => emit(AuthError(failure.message)),
      (_) => emit(const PasswordResetSent()),
    );
  }

  @override
  Future<void> close() {
    _authSubscription?.cancel();
    return super.close();
  }
}
