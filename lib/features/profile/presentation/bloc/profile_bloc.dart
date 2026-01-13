import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/usecases/usecase.dart';
import '../../domain/usecases/delete_account_usecase.dart';
import '../../domain/usecases/export_user_data_usecase.dart';
import '../../domain/usecases/get_profile_usecase.dart';
import '../../domain/usecases/update_profile_usecase.dart';
import 'profile_event.dart';
import 'profile_state.dart';

/// BLoC for managing user profile state.
///
/// Handles profile operations including:
/// - Loading profile
/// - Updating profile
/// - Exporting user data (GDPR)
/// - Deleting account (GDPR)
@injectable
class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final GetProfileUseCase _getProfile;
  final UpdateProfileUseCase _updateProfile;
  final ExportUserDataUseCase _exportUserData;
  final DeleteAccountUseCase _deleteAccount;

  ProfileBloc({
    required GetProfileUseCase getProfile,
    required UpdateProfileUseCase updateProfile,
    required ExportUserDataUseCase exportUserData,
    required DeleteAccountUseCase deleteAccount,
  })  : _getProfile = getProfile,
        _updateProfile = updateProfile,
        _exportUserData = exportUserData,
        _deleteAccount = deleteAccount,
        super(const ProfileInitial()) {
    on<LoadProfileEvent>(_onLoadProfile);
    on<UpdateProfileEvent>(_onUpdateProfile);
    on<ExportUserDataEvent>(_onExportUserData);
    on<DeleteAccountEvent>(_onDeleteAccount);
  }

  Future<void> _onLoadProfile(
    LoadProfileEvent event,
    Emitter<ProfileState> emit,
  ) async {
    emit(const ProfileLoading());

    final result = await _getProfile(const NoParams());

    result.fold(
      (failure) => emit(ProfileError(failure.message)),
      (profile) => emit(ProfileLoaded(profile)),
    );
  }

  Future<void> _onUpdateProfile(
    UpdateProfileEvent event,
    Emitter<ProfileState> emit,
  ) async {
    emit(const ProfileLoading());

    final result = await _updateProfile(UpdateProfileParams(
      displayName: event.displayName,
      photoUrl: event.photoUrl,
    ));

    result.fold(
      (failure) => emit(ProfileError(failure.message)),
      (profile) => emit(ProfileUpdated(profile)),
    );
  }

  Future<void> _onExportUserData(
    ExportUserDataEvent event,
    Emitter<ProfileState> emit,
  ) async {
    emit(const ProfileLoading());

    final result = await _exportUserData(const NoParams());

    result.fold(
      (failure) => emit(ProfileError(failure.message)),
      (jsonData) => emit(DataExported(jsonData)),
    );
  }

  Future<void> _onDeleteAccount(
    DeleteAccountEvent event,
    Emitter<ProfileState> emit,
  ) async {
    emit(const AccountDeleting());

    final result = await _deleteAccount(const NoParams());

    result.fold(
      (failure) => emit(ProfileError(failure.message)),
      (_) => emit(const AccountDeleted()),
    );
  }
}
