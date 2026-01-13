import 'package:equatable/equatable.dart';

/// Base class for all profile events.
abstract class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object?> get props => [];
}

/// Event to load the current user's profile.
class LoadProfileEvent extends ProfileEvent {
  const LoadProfileEvent();
}

/// Event to update the user's profile.
class UpdateProfileEvent extends ProfileEvent {
  final String? displayName;
  final String? photoUrl;

  const UpdateProfileEvent({
    this.displayName,
    this.photoUrl,
  });

  @override
  List<Object?> get props => [displayName, photoUrl];
}

/// Event to export all user data (GDPR).
class ExportUserDataEvent extends ProfileEvent {
  const ExportUserDataEvent();
}

/// Event to delete the user account (GDPR).
class DeleteAccountEvent extends ProfileEvent {
  const DeleteAccountEvent();
}
