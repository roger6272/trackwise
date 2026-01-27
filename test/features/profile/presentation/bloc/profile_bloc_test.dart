import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:traxelos/core/error/failures.dart';
import 'package:traxelos/core/usecases/usecase.dart';
import 'package:traxelos/features/profile/domain/entities/user_profile.dart';
import 'package:traxelos/features/profile/domain/usecases/delete_account_usecase.dart';
import 'package:traxelos/features/profile/domain/usecases/export_user_data_usecase.dart';
import 'package:traxelos/features/profile/domain/usecases/get_profile_usecase.dart';
import 'package:traxelos/features/profile/domain/usecases/update_profile_usecase.dart';
import 'package:traxelos/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:traxelos/features/profile/presentation/bloc/profile_event.dart';
import 'package:traxelos/features/profile/presentation/bloc/profile_state.dart';

class MockGetProfileUseCase extends Mock implements GetProfileUseCase {}

class MockUpdateProfileUseCase extends Mock implements UpdateProfileUseCase {}

class MockExportUserDataUseCase extends Mock implements ExportUserDataUseCase {}

class MockDeleteAccountUseCase extends Mock implements DeleteAccountUseCase {}

void main() {
  late ProfileBloc bloc;
  late MockGetProfileUseCase mockGetProfile;
  late MockUpdateProfileUseCase mockUpdateProfile;
  late MockExportUserDataUseCase mockExportUserData;
  late MockDeleteAccountUseCase mockDeleteAccount;

  setUp(() {
    mockGetProfile = MockGetProfileUseCase();
    mockUpdateProfile = MockUpdateProfileUseCase();
    mockExportUserData = MockExportUserDataUseCase();
    mockDeleteAccount = MockDeleteAccountUseCase();

    bloc = ProfileBloc(
      getProfile: mockGetProfile,
      updateProfile: mockUpdateProfile,
      exportUserData: mockExportUserData,
      deleteAccount: mockDeleteAccount,
    );
  });

  tearDown(() {
    bloc.close();
  });

  setUpAll(() {
    registerFallbackValue(const NoParams());
    registerFallbackValue(const UpdateProfileParams());
  });

  final testProfile = UserProfile(
    userId: 'user_123',
    email: 'test@example.com',
    displayName: 'Test User',
    photoUrl: 'https://example.com/photo.jpg',
    createdAt: DateTime(2024, 1, 1),
    lastLogin: DateTime(2024, 1, 15),
  );

  group('ProfileBloc', () {
    test('initial state should be ProfileInitial', () {
      expect(bloc.state, const ProfileInitial());
    });

    group('LoadProfileEvent', () {
      blocTest<ProfileBloc, ProfileState>(
        'emits [ProfileLoading, ProfileLoaded] when getProfile succeeds',
        build: () {
          when(() => mockGetProfile(any()))
              .thenAnswer((_) async => Right(testProfile));
          return bloc;
        },
        act: (bloc) => bloc.add(const LoadProfileEvent()),
        expect: () => [
          const ProfileLoading(),
          ProfileLoaded(testProfile),
        ],
        verify: (_) {
          verify(() => mockGetProfile(const NoParams())).called(1);
        },
      );

      blocTest<ProfileBloc, ProfileState>(
        'emits [ProfileLoading, ProfileError] when getProfile fails',
        build: () {
          when(() => mockGetProfile(any()))
              .thenAnswer((_) async => const Left(AuthFailure('Not authenticated')));
          return bloc;
        },
        act: (bloc) => bloc.add(const LoadProfileEvent()),
        expect: () => [
          const ProfileLoading(),
          const ProfileError('Not authenticated'),
        ],
      );
    });

    group('UpdateProfileEvent', () {
      blocTest<ProfileBloc, ProfileState>(
        'emits [ProfileLoading, ProfileUpdated] when update succeeds',
        build: () {
          when(() => mockUpdateProfile(any()))
              .thenAnswer((_) async => Right(testProfile));
          return bloc;
        },
        act: (bloc) => bloc.add(const UpdateProfileEvent(displayName: 'New Name')),
        expect: () => [
          const ProfileLoading(),
          ProfileUpdated(testProfile),
        ],
        verify: (_) {
          verify(() => mockUpdateProfile(const UpdateProfileParams(displayName: 'New Name'))).called(1);
        },
      );

      blocTest<ProfileBloc, ProfileState>(
        'emits [ProfileLoading, ProfileError] when update fails',
        build: () {
          when(() => mockUpdateProfile(any()))
              .thenAnswer((_) async => const Left(ServerFailure('Update failed')));
          return bloc;
        },
        act: (bloc) => bloc.add(const UpdateProfileEvent(displayName: 'New Name')),
        expect: () => [
          const ProfileLoading(),
          const ProfileError('Update failed'),
        ],
      );
    });

    group('ExportUserDataEvent', () {
      const testJsonData = '{"profile": {}, "items": []}';

      blocTest<ProfileBloc, ProfileState>(
        'emits [ProfileLoading, DataExported] when export succeeds',
        build: () {
          when(() => mockExportUserData(any()))
              .thenAnswer((_) async => const Right(testJsonData));
          return bloc;
        },
        act: (bloc) => bloc.add(const ExportUserDataEvent()),
        expect: () => [
          const ProfileLoading(),
          const DataExported(testJsonData),
        ],
        verify: (_) {
          verify(() => mockExportUserData(const NoParams())).called(1);
        },
      );

      blocTest<ProfileBloc, ProfileState>(
        'emits [ProfileLoading, ProfileError] when export fails',
        build: () {
          when(() => mockExportUserData(any()))
              .thenAnswer((_) async => const Left(ServerFailure('Export failed')));
          return bloc;
        },
        act: (bloc) => bloc.add(const ExportUserDataEvent()),
        expect: () => [
          const ProfileLoading(),
          const ProfileError('Export failed'),
        ],
      );
    });

    group('DeleteAccountEvent', () {
      blocTest<ProfileBloc, ProfileState>(
        'emits [AccountDeleting, AccountDeleted] when deletion succeeds',
        build: () {
          when(() => mockDeleteAccount(any()))
              .thenAnswer((_) async => const Right(null));
          return bloc;
        },
        act: (bloc) => bloc.add(const DeleteAccountEvent()),
        expect: () => [
          const AccountDeleting(),
          const AccountDeleted(),
        ],
        verify: (_) {
          verify(() => mockDeleteAccount(const NoParams())).called(1);
        },
      );

      blocTest<ProfileBloc, ProfileState>(
        'emits [AccountDeleting, ProfileError] when deletion fails with auth error',
        build: () {
          when(() => mockDeleteAccount(any()))
              .thenAnswer((_) async => const Left(AuthFailure('Please sign in again')));
          return bloc;
        },
        act: (bloc) => bloc.add(const DeleteAccountEvent()),
        expect: () => [
          const AccountDeleting(),
          const ProfileError('Please sign in again'),
        ],
      );

      blocTest<ProfileBloc, ProfileState>(
        'emits [AccountDeleting, ProfileError] when deletion fails with server error',
        build: () {
          when(() => mockDeleteAccount(any()))
              .thenAnswer((_) async => const Left(ServerFailure('Deletion failed')));
          return bloc;
        },
        act: (bloc) => bloc.add(const DeleteAccountEvent()),
        expect: () => [
          const AccountDeleting(),
          const ProfileError('Deletion failed'),
        ],
      );
    });
  });
}
