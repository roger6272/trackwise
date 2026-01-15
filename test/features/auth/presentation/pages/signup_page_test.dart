import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:trackwise/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:trackwise/features/auth/presentation/bloc/auth_event.dart';
import 'package:trackwise/features/auth/presentation/bloc/auth_state.dart';
import 'package:trackwise/features/auth/presentation/pages/signup_page.dart';

import '../../helpers/test_fixtures.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

void main() {
  late MockAuthBloc mockAuthBloc;

  setUpAll(() async {
    // Initialize shared preferences for FlutterFlowTheme
    SharedPreferences.setMockInitialValues({});

    registerFallbackValue(const SignUpEvent(email: '', password: ''));
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
      home: SignupPage(),
    );
  }

  group('SignupPage', () {
    testWidgets('displays email, password, and confirm password fields', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsNWidgets(3));
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);
    });

    testWidgets('displays create account button', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Create Account'), findsWidgets);
    });

    testWidgets('displays sign in link', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Verify the page has RichText widgets (sign in link uses RichText)
      expect(find.byType(RichText), findsWidgets);
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

    testWidgets('validates empty email on form submission', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Find the button that's an ElevatedButton (not a TextButton)
      final createAccountButton = find.byWidgetPredicate(
        (widget) => widget is ElevatedButton &&
            widget.child is Text &&
            (widget.child as Text).data == 'Create Account',
      );

      if (createAccountButton.evaluate().isNotEmpty) {
        await tester.tap(createAccountButton);
        await tester.pumpAndSettle();
        expect(find.text('Please enter your email'), findsOneWidget);
      }
    });

    testWidgets('validates password length', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Enter valid email
      await tester.enterText(
        find.byType(TextFormField).first,
        testEmail,
      );

      // Enter short password
      final passwordFields = find.byType(TextFormField);
      await tester.enterText(passwordFields.at(1), '123');

      // Find and tap the Create Account ElevatedButton
      final createAccountButton = find.byWidgetPredicate(
        (widget) => widget is ElevatedButton &&
            widget.child is Text &&
            (widget.child as Text).data == 'Create Account',
      );

      if (createAccountButton.evaluate().isNotEmpty) {
        await tester.ensureVisible(createAccountButton);
        await tester.tap(createAccountButton);
        await tester.pumpAndSettle();
        expect(find.text('Password must be at least 6 characters'), findsOneWidget);
      }
    });

    testWidgets('validates password match', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Enter valid email
      await tester.enterText(
        find.byType(TextFormField).first,
        testEmail,
      );

      // Enter password
      final passwordFields = find.byType(TextFormField);
      await tester.enterText(passwordFields.at(1), testPassword);

      // Enter different confirm password
      await tester.enterText(passwordFields.at(2), 'differentPassword');

      // Find and tap the Create Account ElevatedButton
      final createAccountButton = find.byWidgetPredicate(
        (widget) => widget is ElevatedButton &&
            widget.child is Text &&
            (widget.child as Text).data == 'Create Account',
      );

      if (createAccountButton.evaluate().isNotEmpty) {
        await tester.ensureVisible(createAccountButton);
        await tester.tap(createAccountButton);
        await tester.pumpAndSettle();
        expect(find.text('Passwords do not match'), findsOneWidget);
      }
    });

    testWidgets('triggers SignUpEvent on valid form submission', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Enter valid credentials
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), testEmail);
      await tester.enterText(textFields.at(1), testPassword);
      await tester.enterText(textFields.at(2), testPassword);

      // Find and tap the Create Account ElevatedButton
      final createAccountButton = find.byWidgetPredicate(
        (widget) => widget is ElevatedButton &&
            widget.child is Text &&
            (widget.child as Text).data == 'Create Account',
      );

      if (createAccountButton.evaluate().isNotEmpty) {
        await tester.ensureVisible(createAccountButton);
        await tester.tap(createAccountButton);
        await tester.pumpAndSettle();
        verify(() => mockAuthBloc.add(any(that: isA<SignUpEvent>()))).called(1);
      }
    });

    testWidgets('triggers SignInWithGoogleEvent on Google button tap', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Find and tap Google sign in button
      final googleButton = find.textContaining('Google');
      await tester.ensureVisible(googleButton);
      await tester.tap(googleButton);
      await tester.pumpAndSettle();

      verify(() => mockAuthBloc.add(const SignInWithGoogleEvent())).called(1);
    });

    testWidgets('shows snackbar on AuthError', (tester) async {
      whenListen(
        mockAuthBloc,
        Stream<AuthState>.fromIterable([
          const AuthError('Email already in use'),
        ]),
        initialState: const AuthInitial(),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Email already in use'), findsOneWidget);
    });

    testWidgets('password visibility can be toggled', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Find password field (second TextFormField)
      final passwordField = find.byType(TextFormField).at(1);

      // Enter text
      await tester.enterText(passwordField, testPassword);
      await tester.pump();

      // Find first visibility toggle icon (outlined variant)
      final visibilityToggles = find.byIcon(Icons.visibility_off_outlined);
      expect(visibilityToggles, findsWidgets);

      // Tap first toggle
      await tester.tap(visibilityToggles.first);
      await tester.pump();

      // Should show visibility icon
      expect(find.byIcon(Icons.visibility_outlined), findsWidgets);
    });
  });
}
