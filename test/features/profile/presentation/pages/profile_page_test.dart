import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:traxelos/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:traxelos/features/auth/presentation/bloc/auth_event.dart';
import 'package:traxelos/features/auth/presentation/bloc/auth_state.dart';
import 'package:traxelos/features/profile/domain/entities/user_profile.dart';
import 'package:traxelos/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:traxelos/features/profile/presentation/bloc/profile_event.dart';
import 'package:traxelos/features/profile/presentation/bloc/profile_state.dart';
import 'package:traxelos/features/profile/presentation/pages/profile_page.dart';

class MockProfileBloc extends MockBloc<ProfileEvent, ProfileState>
    implements ProfileBloc {}

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

void main() {
  late MockProfileBloc mockProfileBloc;
  late MockAuthBloc mockAuthBloc;

  final testProfile = UserProfile(
    userId: 'user_123',
    email: 'test@example.com',
    displayName: 'Test User',
    createdAt: DateTime(2024, 1, 1),
    lastLogin: DateTime(2024, 1, 15),
  );

  setUpAll(() {
    registerFallbackValue(const LoadProfileEvent());
    registerFallbackValue(const DeleteAccountEvent());
    registerFallbackValue(const SignOutEvent());
  });

  setUp(() {
    mockProfileBloc = MockProfileBloc();
    mockAuthBloc = MockAuthBloc();

    when(() => mockAuthBloc.state).thenReturn(const AuthInitial());
  });

  Widget createTestWidget() {
    return MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<ProfileBloc>.value(value: mockProfileBloc),
          BlocProvider<AuthBloc>.value(value: mockAuthBloc),
        ],
        child: const ProfilePage(),
      ),
    );
  }

  group('ProfilePage', () {
    testWidgets('displays loading indicator when loading', (tester) async {
      when(() => mockProfileBloc.state).thenReturn(const ProfileLoading());

      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('displays loading during account deletion', (tester) async {
      when(() => mockProfileBloc.state).thenReturn(const AccountDeleting());

      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
