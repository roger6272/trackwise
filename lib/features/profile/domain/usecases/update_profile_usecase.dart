import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/user_profile.dart';
import '../repositories/profile_repository.dart';

/// Use case for updating the current user's profile.
@lazySingleton
class UpdateProfileUseCase implements UseCase<UserProfile, UpdateProfileParams> {
  final ProfileRepository repository;

  UpdateProfileUseCase(this.repository);

  @override
  Future<Either<Failure, UserProfile>> call(UpdateProfileParams params) async {
    return await repository.updateProfile(
      displayName: params.displayName,
      photoUrl: params.photoUrl,
    );
  }
}

/// Parameters for updating a profile.
class UpdateProfileParams extends Equatable {
  final String? displayName;
  final String? photoUrl;

  const UpdateProfileParams({
    this.displayName,
    this.photoUrl,
  });

  @override
  List<Object?> get props => [displayName, photoUrl];
}
