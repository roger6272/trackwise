import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_datasource.dart';

/// Implementation of [ProfileRepository] using Firebase.
@LazySingleton(as: ProfileRepository)
class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileRemoteDataSource dataSource;

  ProfileRepositoryImpl({required this.dataSource});

  @override
  Future<Either<Failure, UserProfile>> getProfile() async {
    try {
      final profile = await dataSource.getProfile();
      return Right(profile.toEntity());
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, UserProfile>> updateProfile({
    String? displayName,
    String? photoUrl,
  }) async {
    try {
      final profile = await dataSource.updateProfile(
        displayName: displayName,
        photoUrl: photoUrl,
      );
      return Right(profile.toEntity());
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, String>> exportUserData() async {
    try {
      final jsonData = await dataSource.exportUserData();
      return Right(jsonData);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> deleteAccount() async {
    try {
      await dataSource.deleteAccount();
      return const Right(null);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
