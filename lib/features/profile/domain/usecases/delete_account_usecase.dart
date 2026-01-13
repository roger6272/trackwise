import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/profile_repository.dart';

/// Use case for deleting the user account and all data (GDPR compliance).
///
/// Permanently deletes:
/// - All items owned by the user
/// - All event logs for the user
/// - User profile document
/// - Firebase Auth account
///
/// This operation is irreversible.
@lazySingleton
class DeleteAccountUseCase implements UseCase<void, NoParams> {
  final ProfileRepository repository;

  DeleteAccountUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(NoParams params) async {
    return await repository.deleteAccount();
  }
}
