import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/profile_repository.dart';

/// Use case for exporting all user data as JSON (GDPR compliance).
///
/// Returns a JSON string containing:
/// - Profile information
/// - All items
/// - All event logs
@lazySingleton
class ExportUserDataUseCase implements UseCase<String, NoParams> {
  final ProfileRepository repository;

  ExportUserDataUseCase(this.repository);

  @override
  Future<Either<Failure, String>> call(NoParams params) async {
    return await repository.exportUserData();
  }
}
