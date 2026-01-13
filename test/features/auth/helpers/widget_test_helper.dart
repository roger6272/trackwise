import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:trackwise/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:trackwise/features/auth/presentation/bloc/auth_event.dart';
import 'package:trackwise/features/auth/presentation/bloc/auth_state.dart';

/// Mock AuthBloc for widget tests using bloc_test.
class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

/// Creates a testable widget with MaterialApp wrapper.
Widget createTestableWidget({
  required Widget child,
  AuthBloc? authBloc,
}) {
  if (authBloc != null) {
    return MaterialApp(
      home: BlocProvider<AuthBloc>.value(
        value: authBloc,
        child: Scaffold(body: child),
      ),
    );
  }
  return MaterialApp(
    home: Scaffold(body: child),
  );
}

/// Sets up a MockAuthBloc with the given initial state.
MockAuthBloc setupMockAuthBloc({AuthState initialState = const AuthInitial()}) {
  final mockBloc = MockAuthBloc();
  when(() => mockBloc.state).thenReturn(initialState);
  return mockBloc;
}
