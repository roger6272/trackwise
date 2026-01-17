import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:trackwise/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:trackwise/features/auth/presentation/bloc/auth_event.dart';
import 'package:trackwise/features/auth/presentation/bloc/auth_state.dart';
import 'package:trackwise/features/auth/presentation/pages/forgot_password_page.dart';

import '../../helpers/test_fixtures.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

void main() {
  late MockAuthBloc mockAuthBloc;

  setUpAll(() async {
    // Initialize shared preferences for FlutterFlowTheme
    SharedPreferences.setMockInitialValues({});

    registerFallbackValue(const ResetPasswordEvent(email: ''));
  });

  setUp(() {
    mockAuthBloc = MockAuthBloc();

    // Register mock bloc in service locator
    final sl = GetIt.instance;
    if (sl.isRegistered<AuthBloc>()) {
      sl.unregister<AuthBloc>();
    }
    sl.registerFactory<AuthBloc>(() => mockAuthBloc);

    // Default state
    when(() => mockAuthBloc.state).thenReturn(const AuthInitial());
  });

  tearDown(() {
    final sl = GetIt.instance;
    if (sl.isRegistered<AuthBloc>()) {
      sl.unregister<AuthBloc>();
    }
  });

  Widget createTestWidget() {
    return const MaterialApp(
      home: ForgotPasswordPage(),
    );
  }

  Widget createTestWidgetWithRouter() {
    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => Builder(
            builder: (context) {
              // Automatically push to forgot-password on first build
              WidgetsBinding.instance.addPostFrameCallback((_) {
                context.push('/forgot-password');
              });
              return const Scaffold(body: Text('Login'));
            },
          ),
        ),
        GoRoute(
          path: '/forgot-password',
          builder: (context, state) => const ForgotPasswordPage(),
        ),
      ],
    );

    return MaterialApp.router(
      routerConfig: router,
    );
  }

  group('ForgotPasswordPage', () {
    testWidgets('displays email field', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
    });

    testWidgets('displays send reset link button', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Send Reset Link'), findsOneWidget);
    });

    testWidgets('displays back button', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    });

    testWidgets('displays forgot password title', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Forgot Password'), findsOneWidget);
    });

    testWidgets('shows loading indicator when state is AuthLoading', (tester) async {
      when(() => mockAuthBloc.state).thenReturn(const AuthLoading());

      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('validates empty email', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap send reset link without entering email
      await tester.tap(find.text('Send Reset Link'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your email'), findsOneWidget);
    });

    testWidgets('validates invalid email format', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Enter invalid email
      await tester.enterText(
        find.byType(TextFormField),
        'invalid-email',
      );
      await tester.tap(find.text('Send Reset Link'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email'), findsOneWidget);
    });

    testWidgets('triggers ResetPasswordEvent on valid form submission', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Enter valid email
      await tester.enterText(
        find.byType(TextFormField),
        testEmail,
      );

      // Tap send reset link
      await tester.tap(find.text('Send Reset Link'));
      await tester.pumpAndSettle();

      verify(() => mockAuthBloc.add(
        const ResetPasswordEvent(email: testEmail),
      )).called(1);
    });

    testWidgets('shows success snackbar on PasswordResetSent', (tester) async {
      whenListen(
        mockAuthBloc,
        Stream<AuthState>.fromIterable([
          const PasswordResetSent(),
        ]),
        initialState: const AuthInitial(),
      );

      // Use router widget so context.pop() works after the 2-second timer
      await tester.pumpWidget(createTestWidgetWithRouter());
      // Pump a few times to let the navigation happen and state listener fire
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('Password reset email sent'), findsOneWidget);

      // Advance past the 2-second timer and let pop complete
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
    });

    testWidgets('shows error snackbar on AuthError', (tester) async {
      whenListen(
        mockAuthBloc,
        Stream<AuthState>.fromIterable([
          const AuthError('Email not found'),
        ]),
        initialState: const AuthInitial(),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Email not found'), findsOneWidget);
    });

    testWidgets('back button is visible', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    });
  });
}
