import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:traxelos/core/error/failures.dart';
import 'package:traxelos/core/usecases/usecase.dart';
import 'package:traxelos/features/auth/domain/usecases/sign_in_with_email_usecase.dart';
import 'package:traxelos/features/auth/domain/usecases/sign_up_usecase.dart';
import 'package:traxelos/features/auth/domain/usecases/reset_password_usecase.dart';
import 'package:traxelos/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:traxelos/features/auth/presentation/bloc/auth_event.dart';
import 'package:traxelos/features/auth/presentation/bloc/auth_state.dart';

import '../../helpers/test_helper.dart';
import '../../helpers/test_fixtures.dart';

void main() {
  late MockSignInWithEmailUseCase mockSignInWithEmail;
  late MockSignInWithGoogleUseCase mockSignInWithGoogle;
  late MockSignInWithAppleUseCase mockSignInWithApple;
  late MockSignUpUseCase mockSignUp;
  late MockSignOutUseCase mockSignOut;
  late MockResetPasswordUseCase mockResetPassword;
  late MockWatchAuthStateUseCase mockWatchAuthState;

  setUpAll(() {
    // Register fallback values for mocktail
    registerFallbackValue(const SignInWithEmailParams(email: '', password: ''));
    registerFallbackValue(const SignUpParams(email: '', password: ''));
    registerFallbackValue(const ResetPasswordParams(email: ''));
    registerFallbackValue(const NoParams());
  });

  setUp(() {
    mockSignInWithEmail = MockSignInWithEmailUseCase();
    mockSignInWithGoogle = MockSignInWithGoogleUseCase();
    mockSignInWithApple = MockSignInWithAppleUseCase();
    mockSignUp = MockSignUpUseCase();
    mockSignOut = MockSignOutUseCase();
    mockResetPassword = MockResetPasswordUseCase();
    mockWatchAuthState = MockWatchAuthStateUseCase();
  });

  AuthBloc createBloc() {
    return AuthBloc(
      signInWithEmail: mockSignInWithEmail,
      signInWithGoogle: mockSignInWithGoogle,
      signInWithApple: mockSignInWithApple,
      signUp: mockSignUp,
      signOut: mockSignOut,
      resetPassword: mockResetPassword,
      watchAuthState: mockWatchAuthState,
    );
  }

  test('initial state should be AuthInitial', () {
    final bloc = createBloc();
    expect(bloc.state, const AuthInitial());
    bloc.close();
  });

  group('CheckAuthStatusEvent', () {
    blocTest<AuthBloc, AuthState>(
      'emits [Authenticated] when user is already signed in',
      build: () {
        when(() => mockWatchAuthState.currentUser).thenReturn(testUser);
        when(() => mockWatchAuthState()).thenAnswer((_) => const Stream.empty());
        return createBloc();
      },
      act: (bloc) => bloc.add(const CheckAuthStatusEvent()),
      expect: () => [const Authenticated(testUser)],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [Unauthenticated] when no user is signed in',
      build: () {
        when(() => mockWatchAuthState.currentUser).thenReturn(null);
        when(() => mockWatchAuthState()).thenAnswer((_) => const Stream.empty());
        return createBloc();
      },
      act: (bloc) => bloc.add(const CheckAuthStatusEvent()),
      expect: () => [const Unauthenticated()],
    );
  });

  group('SignInWithEmailEvent', () {
    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, Authenticated] when sign in succeeds',
      build: () {
        when(() => mockSignInWithEmail(any()))
            .thenAnswer((_) async => const Right(testUser));
        return createBloc();
      },
      act: (bloc) => bloc.add(const SignInWithEmailEvent(
        email: testEmail,
        password: testPassword,
      )),
      expect: () => [
        const AuthLoading(),
        const Authenticated(testUser),
      ],
      verify: (_) {
        verify(() => mockSignInWithEmail(
          const SignInWithEmailParams(email: testEmail, password: testPassword),
        )).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthError] when sign in fails',
      build: () {
        when(() => mockSignInWithEmail(any()))
            .thenAnswer((_) async => const Left(AuthFailure('Invalid credentials')));
        return createBloc();
      },
      act: (bloc) => bloc.add(const SignInWithEmailEvent(
        email: testEmail,
        password: testPassword,
      )),
      expect: () => [
        const AuthLoading(),
        const AuthError('Invalid credentials'),
      ],
    );
  });

  group('SignInWithGoogleEvent', () {
    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, Authenticated] when Google sign in succeeds',
      build: () {
        when(() => mockSignInWithGoogle(any()))
            .thenAnswer((_) async => const Right(testGoogleUser));
        return createBloc();
      },
      act: (bloc) => bloc.add(const SignInWithGoogleEvent()),
      expect: () => [
        const AuthLoading(),
        const Authenticated(testGoogleUser),
      ],
      verify: (_) {
        verify(() => mockSignInWithGoogle(const NoParams())).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthError] when Google sign in fails',
      build: () {
        when(() => mockSignInWithGoogle(any()))
            .thenAnswer((_) async => const Left(AuthFailure('Google sign-in cancelled')));
        return createBloc();
      },
      act: (bloc) => bloc.add(const SignInWithGoogleEvent()),
      expect: () => [
        const AuthLoading(),
        const AuthError('Google sign-in cancelled'),
      ],
    );
  });

  group('SignInWithAppleEvent', () {
    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, Authenticated] when Apple sign in succeeds',
      build: () {
        when(() => mockSignInWithApple(any()))
            .thenAnswer((_) async => const Right(testAppleUser));
        return createBloc();
      },
      act: (bloc) => bloc.add(const SignInWithAppleEvent()),
      expect: () => [
        const AuthLoading(),
        const Authenticated(testAppleUser),
      ],
      verify: (_) {
        verify(() => mockSignInWithApple(const NoParams())).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthError] when Apple sign in fails',
      build: () {
        when(() => mockSignInWithApple(any()))
            .thenAnswer((_) async => const Left(AuthFailure('Apple sign-in cancelled')));
        return createBloc();
      },
      act: (bloc) => bloc.add(const SignInWithAppleEvent()),
      expect: () => [
        const AuthLoading(),
        const AuthError('Apple sign-in cancelled'),
      ],
    );
  });

  group('SignUpEvent', () {
    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, Authenticated] when sign up succeeds',
      build: () {
        when(() => mockSignUp(any()))
            .thenAnswer((_) async => const Right(testUser));
        return createBloc();
      },
      act: (bloc) => bloc.add(const SignUpEvent(
        email: testEmail,
        password: testPassword,
      )),
      expect: () => [
        const AuthLoading(),
        const Authenticated(testUser),
      ],
      verify: (_) {
        verify(() => mockSignUp(
          const SignUpParams(email: testEmail, password: testPassword),
        )).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthError] when sign up fails',
      build: () {
        when(() => mockSignUp(any()))
            .thenAnswer((_) async => const Left(AuthFailure('Email already in use')));
        return createBloc();
      },
      act: (bloc) => bloc.add(const SignUpEvent(
        email: testEmail,
        password: testPassword,
      )),
      expect: () => [
        const AuthLoading(),
        const AuthError('Email already in use'),
      ],
    );
  });

  group('SignOutEvent', () {
    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, Unauthenticated] when sign out succeeds',
      build: () {
        when(() => mockSignOut(any()))
            .thenAnswer((_) async => const Right(null));
        return createBloc();
      },
      act: (bloc) => bloc.add(const SignOutEvent()),
      expect: () => [
        const AuthLoading(),
        const Unauthenticated(),
      ],
      verify: (_) {
        verify(() => mockSignOut(const NoParams())).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthError] when sign out fails',
      build: () {
        when(() => mockSignOut(any()))
            .thenAnswer((_) async => const Left(ServerFailure('Sign out failed')));
        return createBloc();
      },
      act: (bloc) => bloc.add(const SignOutEvent()),
      expect: () => [
        const AuthLoading(),
        const AuthError('Sign out failed'),
      ],
    );
  });

  group('ResetPasswordEvent', () {
    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, PasswordResetSent] when reset password succeeds',
      build: () {
        when(() => mockResetPassword(any()))
            .thenAnswer((_) async => const Right(null));
        return createBloc();
      },
      act: (bloc) => bloc.add(const ResetPasswordEvent(email: testEmail)),
      expect: () => [
        const AuthLoading(),
        const PasswordResetSent(),
      ],
      verify: (_) {
        verify(() => mockResetPassword(
          const ResetPasswordParams(email: testEmail),
        )).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthError] when reset password fails',
      build: () {
        when(() => mockResetPassword(any()))
            .thenAnswer((_) async => const Left(AuthFailure('Email not found')));
        return createBloc();
      },
      act: (bloc) => bloc.add(const ResetPasswordEvent(email: testEmail)),
      expect: () => [
        const AuthLoading(),
        const AuthError('Email not found'),
      ],
    );
  });

  group('AuthStateChangedEvent', () {
    blocTest<AuthBloc, AuthState>(
      'emits [Authenticated] when user signs in',
      build: createBloc,
      act: (bloc) => bloc.add(const AuthStateChangedEvent(testUser)),
      expect: () => [const Authenticated(testUser)],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [Unauthenticated] when user signs out',
      build: createBloc,
      act: (bloc) => bloc.add(const AuthStateChangedEvent(null)),
      expect: () => [const Unauthenticated()],
    );
  });
}
