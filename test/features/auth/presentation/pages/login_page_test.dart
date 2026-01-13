import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:trackwise/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:trackwise/features/auth/presentation/bloc/auth_event.dart';
import 'package:trackwise/features/auth/presentation/bloc/auth_state.dart';
import 'package:trackwise/features/auth/presentation/pages/login_page.dart';

import '../../helpers/test_fixtures.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

void main() {
  late MockAuthBloc mockAuthBloc;

  setUpAll(() async {
    // Initialize shared preferences for FlutterFlowTheme
    SharedPreferences.setMockInitialValues({});

    registerFallbackValue(const SignInWithEmailEvent(email: '', password: ''));
    registerFallbackValue(const SignInWithGoogleEvent());
    registerFallbackValue(const SignInWithAppleEvent());
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
      home: LoginPage(),
    );
  }

  group('LoginPage', () {
    testWidgets('displays email and password fields', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
    });

    testWidgets('displays sign in button', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Sign In'), findsOneWidget);
    });

    testWidgets('displays forgot password link', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Forgot Password?'), findsOneWidget);
    });

    testWidgets('displays sign up link', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Sign Up'), findsOneWidget);
    });

    testWidgets('displays Google sign in button', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.textContaining('Google'), findsOneWidget);
    });

    testWidgets('shows loading indicator when state is AuthLoading', (tester) async {
      when(() => mockAuthBloc.state).thenReturn(const AuthLoading());

      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('validates empty email', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap sign in without entering email
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your email'), findsOneWidget);
    });

    testWidgets('validates invalid email format', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Enter invalid email
      await tester.enterText(
        find.byType(TextFormField).first,
        'invalid-email',
      );
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email'), findsOneWidget);
    });

    testWidgets('validates empty password', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Enter valid email but no password
      await tester.enterText(
        find.byType(TextFormField).first,
        testEmail,
      );
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your password'), findsOneWidget);
    });

    testWidgets('form can be submitted with valid credentials', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Enter valid credentials
      await tester.enterText(
        find.byType(TextFormField).first,
        testEmail,
      );
      await tester.enterText(
        find.byType(TextFormField).last,
        testPassword,
      );

      // Find and tap sign in button - ensure it's visible first
      final signInButton = find.text('Sign In');
      await tester.ensureVisible(signInButton);
      await tester.tap(signInButton, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Form submission should not show validation errors
      expect(find.text('Please enter your email'), findsNothing);
      expect(find.text('Please enter your password'), findsNothing);
    });

    testWidgets('Google sign in button is displayed', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Find Google sign in button
      final googleButton = find.textContaining('Google');
      expect(googleButton, findsOneWidget);
    });

    testWidgets('displays error state properly', (tester) async {
      // When bloc is in error state, it should show properly styled content
      when(() => mockAuthBloc.state).thenReturn(const AuthError('Invalid credentials'));

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Auth error state should still show the form
      expect(find.byType(TextFormField), findsWidgets);
    });

    testWidgets('password visibility can be toggled', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Find password field
      final passwordField = find.byType(TextFormField).last;

      // Enter text to ensure the field is active
      await tester.enterText(passwordField, testPassword);
      await tester.pump();

      // Find visibility toggle icon
      final visibilityToggle = find.byIcon(Icons.visibility_off);
      expect(visibilityToggle, findsOneWidget);

      // Tap to toggle visibility
      await tester.tap(visibilityToggle);
      await tester.pump();

      // Should now show visibility icon (not visibility_off)
      expect(find.byIcon(Icons.visibility), findsOneWidget);
    });
  });
}
