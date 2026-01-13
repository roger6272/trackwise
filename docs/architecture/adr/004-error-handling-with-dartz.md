# ADR-004: Error Handling with Dartz Either Type

**Status:** Accepted

**Date:** 2026-01-03

**Deciders:** Development Team

**Technical Story:** Task 003 - Create Base Classes and Core Utilities

## Context

Clean Architecture requires clear error propagation through layers without using exceptions for control flow. The application needs to handle multiple error types:

**Data Layer Errors:**
- Firebase connection failures
- Authentication errors
- Cache read/write failures
- Bluetooth connection errors
- Network timeouts

**Domain Layer Errors:**
- Business rule violations
- Validation failures
- Unauthorized access

**Requirements:**
1. Type-safe error handling (compile-time, not runtime)
2. Force error handling (cannot ignore errors)
3. No try-catch blocks for control flow (anti-pattern)
4. Clear separation between error types and success data
5. Testable error paths
6. Explicit error propagation through layers

**Problem with Exceptions:**
```dart
// Bad: Exceptions for control flow
try {
  final items = await repository.getItems();
  return items; // Success path
} catch (e) {
  // Error path - what type of error? ServerException? CacheException?
  // Have to check runtime type
  if (e is ServerException) {
    return ServerFailure(e.message);
  } else if (e is CacheException) {
    return CacheFailure(e.message);
  }
  // Easy to miss error types!
}
```

## Decision

Use **Dartz** library's **Either<L, R>** type for functional error handling.

### Either Type

`Either<Failure, SuccessType>` represents one of two possible values:
- **Left:** Failure (error)
- **Right:** Success (data)

```dart
// Repository returns Either
Future<Either<Failure, List<Item>>> getItems();

// Success case: Right(data)
return Right([item1, item2, item3]);

// Failure case: Left(failure)
return Left(ServerFailure('Connection failed'));
```

### Error Hierarchy

**Failures (Domain Layer):**
```dart
abstract class Failure extends Equatable {
  final String message;
  const Failure(this.message);
}

class ServerFailure extends Failure {}
class CacheFailure extends Failure {}
class BluetoothFailure extends Failure {}
class AuthFailure extends Failure {}
class ValidationFailure extends Failure {}
```

**Exceptions (Data Layer):**
```dart
class ServerException implements Exception {
  final String message;
  ServerException(this.message);
}
// Similar for Cache, Bluetooth, Auth
```

### Layer Boundary Pattern

**Data Layer throws Exceptions:**
```dart
class ItemRemoteDataSource {
  Future<List<ItemModel>> getItems() async {
    try {
      final snapshot = await firestore.collection('Item').get();
      return snapshot.docs.map((doc) => ItemModel.fromFirestore(doc)).toList();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Server error');
    }
  }
}
```

**Repository catches Exceptions, returns Either:**
```dart
class ItemRepositoryImpl implements ItemRepository {
  final ItemRemoteDataSource remoteDataSource;

  @override
  Future<Either<Failure, List<Item>>> getItems() async {
    try {
      final itemModels = await remoteDataSource.getItems();
      return Right(itemModels);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }
}
```

**Use Case propagates Either:**
```dart
class GetItemsUseCase extends UseCase<List<Item>, NoParams> {
  final ItemRepository repository;

  @override
  Future<Either<Failure, List<Item>>> call(NoParams params) async {
    return await repository.getItems();
  }
}
```

**BLoC handles Either with fold:**
```dart
class ItemBloc extends Bloc<ItemEvent, ItemState> {
  Future<void> _onLoadItems(LoadItems event, Emitter<ItemState> emit) async {
    emit(ItemLoading());

    final result = await getItemsUseCase(NoParams());

    result.fold(
      (failure) => emit(ItemError(failure.message)), // Left = error
      (items) => emit(ItemLoaded(items)),             // Right = success
    );
  }
}
```

### fold() Method

The `fold()` method forces handling both cases:
```dart
result.fold(
  (failure) => {/* Handle error */},  // Called if Left
  (success) => {/* Handle success */}, // Called if Right
);
```

**Cannot ignore errors:**
```dart
// This won't compile - must handle Left case
final items = result.fold(
  // Missing: (failure) => ...
  (items) => items,
);
```

## Consequences

### Positive

1. **Type-safe:** Compiler enforces error handling (cannot forget)
2. **Explicit:** Clear which operations can fail
3. **No exceptions for control flow:** Exceptions only for truly exceptional cases
4. **Testable:** Easy to test both success and failure paths
5. **Self-documenting:** Return type shows possible failures
6. **Railway-oriented programming:** Chain operations cleanly
7. **Immutable:** Either is immutable, cannot change after creation
8. **Pattern matching:** fold() ensures all cases handled
9. **No null checks:** Either is never null
10. **Clear layer boundaries:** Exception → Failure conversion at repository

### Negative

1. **Learning curve:** Team needs to understand functional programming concepts
2. **Verbose:** More code than try-catch
3. **Dartz dependency:** Adds external package dependency
4. **Nested folds:** Multiple operations can lead to callback hell
5. **Async complexity:** Combining Future and Either can be confusing
6. **IDE support:** Less autocomplete support for functional methods
7. **Stack traces:** Can lose stack trace information across layer boundaries

### Neutral

1. **Functional programming:** Different paradigm than traditional OOP
2. **Either syntax:** `Left` and `Right` names can be confusing initially
3. **Package size:** Dartz is a large package (has many FP utilities)

## Alternatives Considered

### 1. Try-Catch with Exceptions
**Rejected because:**
- **Not type-safe:** Can forget to catch specific exceptions
- **Control flow anti-pattern:** Exceptions should be exceptional, not expected
- **Hidden failures:** Return type doesn't show that operation can fail
- **Runtime errors:** Easy to miss exception types, fails at runtime
- **Testing difficulty:** Hard to test all exception paths

**Example problems:**
```dart
// What exceptions can this throw? No way to know from signature!
Future<List<Item>> getItems();

// Easy to forget exception types
try {
  return await getItems();
} catch (e) {
  // Catches ALL exceptions, not just expected ones
  // What if it's a programming error? We'd hide it!
}
```

### 2. Nullable Return Types
**Rejected because:**
- **No error information:** `null` doesn't tell you why it failed
- **Not clear:** `null` could mean "no data" or "error occurred"
- **Requires null checks everywhere:** Verbose and error-prone
- **Cannot distinguish error types:** All errors collapse to `null`

**Example:**
```dart
Future<List<Item>?> getItems(); // Why is it null? No idea!

final items = await repository.getItems();
if (items == null) {
  // Was it a server error? Cache error? Network error? Unknown!
  return Text('Error'); // Generic, unhelpful
}
```

### 3. Result Class (Custom)
**Rejected because:**
- **Reinventing the wheel:** Dartz already provides battle-tested Either
- **Maintenance burden:** Have to maintain custom Result class
- **No ecosystem:** Dartz has many utility methods (map, flatMap, etc.)
- **Less functional:** Custom Result often becomes OOP-style

**Example:**
```dart
class Result<T> {
  final T? data;
  final String? error;
  bool get isSuccess => data != null;
}

// Problems:
// - Both data and error can be null (ambiguous)
// - No compile-time enforcement of handling both cases
// - No type information about error (just String)
```

### 4. Callback Hell (onSuccess/onError)
**Rejected because:**
- **Not composable:** Hard to chain operations
- **Verbose:** Every operation needs two callbacks
- **Testing complexity:** Have to test both callback paths
- **No type safety:** Can call either callback, not enforced

**Example:**
```dart
repository.getItems(
  onSuccess: (items) => emit(ItemLoaded(items)),
  onError: (error) => emit(ItemError(error)),
);

// Problem: What if neither callback is called? What if both are called?
```

### 5. Reactive Streams (Stream<Result>)
**Rejected because:**
- **Over-engineering:** Not all operations need streams
- **Complexity:** Streams are harder to test and reason about
- **Memory leaks:** Easy to forget to dispose streams
- **Overkill for single operations:** Either is simpler for one-time operations

## Implementation Pattern

### Complete Flow Example

```dart
// 1. Data Source (throws Exceptions)
class ItemRemoteDataSource {
  Future<List<ItemModel>> getItems() async {
    try {
      final snapshot = await firestore.collection('Item').get();
      return snapshot.docs.map((doc) => ItemModel.fromFirestore(doc)).toList();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Unknown error');
    }
  }
}

// 2. Repository (converts Exception → Failure, returns Either)
class ItemRepositoryImpl implements ItemRepository {
  @override
  Future<Either<Failure, List<Item>>> getItems() async {
    try {
      final models = await remoteDataSource.getItems();
      final entities = models.map((m) => m.toEntity()).toList();
      return Right(entities);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }
}

// 3. Use Case (propagates Either)
class GetItemsUseCase extends UseCase<List<Item>, NoParams> {
  final ItemRepository repository;

  @override
  Future<Either<Failure, List<Item>>> call(NoParams params) {
    return repository.getItems();
  }
}

// 4. BLoC (handles Either with fold)
class ItemBloc extends Bloc<ItemEvent, ItemState> {
  Future<void> _onLoadItems(LoadItems event, Emitter<ItemState> emit) async {
    emit(ItemLoading());

    final result = await getItems(NoParams());

    result.fold(
      (failure) => emit(ItemError(failure.message)),
      (items) => emit(ItemLoaded(items)),
    );
  }
}

// 5. Widget (displays state)
BlocBuilder<ItemBloc, ItemState>(
  builder: (context, state) {
    if (state is ItemError) {
      return ErrorWidget(message: state.message);
    }
    if (state is ItemLoaded) {
      return ListView(items: state.items);
    }
    return LoadingWidget();
  },
)
```

### Testing Example

```dart
test('should return ServerFailure when remote data source fails', () async {
  // arrange
  when(() => mockRemoteDataSource.getItems())
      .thenThrow(ServerException('Connection failed'));

  // act
  final result = await repository.getItems();

  // assert
  expect(result, Left(ServerFailure('Connection failed')));
});

test('should return items when remote data source succeeds', () async {
  // arrange
  when(() => mockRemoteDataSource.getItems())
      .thenAnswer((_) async => [testItemModel]);

  // act
  final result = await repository.getItems();

  // assert
  expect(result, Right([testItem]));
});
```

## References

- [Dartz Package](https://pub.dev/packages/dartz)
- [Railway Oriented Programming](https://fsharpforfunandprofit.com/rop/)
- [Functional Error Handling in Dart](https://resocoder.com/2019/12/28/functional-error-handling-in-flutter-dart/)
- [Either Type Explained](https://medium.com/flutter-community/functional-error-handling-in-flutter-dart-with-dartz-b93d03ae1fec)
- Related ADRs:
  - ADR-001: Clean Architecture Adoption
  - ADR-005: Testing Strategy
