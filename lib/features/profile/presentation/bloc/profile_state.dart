import 'package:equatable/equatable.dart';

import '../../domain/entities/user_profile.dart';

/// Base class for all profile states.
abstract class ProfileState extends Equatable {
  const ProfileState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any action.
class ProfileInitial extends ProfileState {
  const ProfileInitial();
}

/// Loading state during async operations.
class ProfileLoading extends ProfileState {
  const ProfileLoading();
}

/// Profile loaded successfully.
class ProfileLoaded extends ProfileState {
  final UserProfile profile;

  const ProfileLoaded(this.profile);

  @override
  List<Object?> get props => [profile];
}

/// Profile update succeeded.
class ProfileUpdated extends ProfileState {
  final UserProfile profile;

  const ProfileUpdated(this.profile);

  @override
  List<Object?> get props => [profile];
}

/// Data export succeeded.
class DataExported extends ProfileState {
  final String jsonData;

  const DataExported(this.jsonData);

  @override
  List<Object?> get props => [jsonData];
}

/// Account deletion in progress.
class AccountDeleting extends ProfileState {
  const AccountDeleting();
}

/// Account deleted successfully.
class AccountDeleted extends ProfileState {
  const AccountDeleted();
}

/// Error state.
class ProfileError extends ProfileState {
  final String message;

  const ProfileError(this.message);

  @override
  List<Object?> get props => [message];
}
