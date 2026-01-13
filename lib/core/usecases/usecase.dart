import 'package:dartz/dartz.dart';
import '../error/failures.dart';

/// Base class for all use cases in the application.
///
/// Each use case represents a single business logic operation.
/// Use cases take parameters and return Either<Failure, Type> for error handling.
///
/// Example usage:
/// ```dart
/// class GetItemsUseCase implements UseCase<List<Item>, NoParams> {
///   final ItemRepository repository;
///
///   GetItemsUseCase(this.repository);
///
///   @override
///   Future<Either<Failure, List<Item>>> call(NoParams params) async {
///     return await repository.getItems();
///   }
/// }
/// ```
abstract class UseCase<Type, Params> {
  /// Execute the use case with the given parameters.
  ///
  /// Returns Either:
  /// - Left(Failure) if operation failed
  /// - Right(Type) if operation succeeded
  Future<Either<Failure, Type>> call(Params params);
}

/// Use this when a use case doesn't require parameters.
///
/// Example:
/// ```dart
/// class LogoutUseCase implements UseCase<void, NoParams> {
///   @override
///   Future<Either<Failure, void>> call(NoParams params) async {
///     // ...
///   }
/// }
/// ```
class NoParams {
  const NoParams();
}
