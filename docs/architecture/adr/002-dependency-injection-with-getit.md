# ADR-002: Dependency Injection with GetIt and Injectable

**Status:** Accepted

**Date:** 2026-01-03

**Deciders:** Development Team

**Technical Story:** Task 002 - Configure GetIt Dependency Injection

## Context

Clean Architecture requires loose coupling between layers through dependency inversion. Components should depend on abstractions (interfaces) rather than concrete implementations. This requires a dependency injection (DI) mechanism to:

1. Provide concrete implementations at runtime
2. Allow easy swapping of implementations (e.g., mock for tests)
3. Manage object lifecycles (singletons, factories, scoped)
4. Enable testing by injecting mocks instead of real implementations

Requirements:
- Must support lazy initialization (don't create objects until needed)
- Must handle both singleton and factory patterns
- Must work with interfaces/abstract classes
- Must be testable (easy to reset and inject mocks)
- Should minimize boilerplate code
- Should be type-safe (compile-time errors, not runtime)

## Decision

Use **GetIt** as the service locator with **Injectable** for code generation.

### Implementation

**GetIt** provides the service locator pattern:
```dart
final sl = GetIt.instance;

// Register dependencies
sl.registerLazySingleton<FirebaseFirestore>(() => FirebaseFirestore.instance);
sl.registerFactory<GetItemsUseCase>(() => GetItemsUseCase(sl()));

// Retrieve dependencies
final firestore = sl<FirebaseFirestore>();
```

**Injectable** automates registration with annotations:
```dart
@injectable
class ItemRepositoryImpl implements ItemRepository {
  final FirebaseFirestore firestore;

  ItemRepositoryImpl(this.firestore); // Auto-injected
}

@lazySingleton
class GetItemsUseCase {
  final ItemRepository repository;

  GetItemsUseCase(this.repository);
}
```

### Registration Types

1. **@lazySingleton** - Created once, shared across app (repositories, use cases)
2. **@singleton** - Created immediately when registered
3. **@injectable** - Created fresh each time (BLoCs)
4. **@factoryMethod** - Custom factory logic

### Manual Registration

External dependencies (Firebase, FlutterBluePlus) registered manually:
```dart
Future<void> _registerManualDependencies() async {
  sl.registerLazySingleton<FirebaseFirestore>(() => FirebaseFirestore.instance);
  sl.registerLazySingleton<FirebaseAuth>(() => FirebaseAuth.instance);
}
```

### Testing Support

Easy to reset and inject mocks:
```dart
setUp(() {
  resetServiceLocator();
  registerMockFirebaseInstances(
    mockFirestore: MockFirebaseFirestore(),
    mockAuth: MockFirebaseAuth(),
  );
});
```

## Consequences

### Positive

1. **Automatic registration:** Injectable generates registration code from annotations
2. **Type safety:** Compile-time errors if dependencies are missing
3. **Lazy loading:** Objects created only when first requested (faster app startup)
4. **Testability:** Easy to inject mocks by resetting service locator
5. **Single source of truth:** All dependencies in one place (`injection.dart`)
6. **Constructor injection:** Clear dependencies visible in constructor
7. **IDE support:** Navigate to dependency definitions
8. **Zero runtime overhead:** Service locator is fast (Dictionary lookup)
9. **Simple API:** `sl<Type>()` to retrieve dependencies
10. **Lifecycle management:** Proper disposal through registration types

### Negative

1. **Service locator pattern:** Some consider it an anti-pattern (global state)
2. **Code generation required:** Must run `build_runner` after annotation changes
3. **Build time:** Adding `build_runner` step (takes ~20-30 seconds)
4. **Learning curve:** Team needs to understand registration types
5. **Debugging complexity:** Dependency graph not immediately visible
6. **Manual registration:** External packages still need manual setup
7. **Runtime errors possible:** If dependency not registered, fails at runtime (not compile-time)

### Neutral

1. **Additional packages:** Adds get_it and injectable dependencies
2. **Generated files:** Creates `injection.config.dart` (needs git commit)
3. **Initialization required:** Must call `configureDependencies()` in main()

## Alternatives Considered

### 1. Provider (Flutter's recommended DI)
**Rejected because:**
- **Widget tree coupling:** Requires placing providers in widget tree
- **BuildContext required:** Can't easily use in pure Dart classes (use cases, repositories)
- **Verbose:** Each provider needs separate widget wrapper
- **Testing complexity:** Need to wrap test widgets with providers
- **Not ideal for multi-layer:** Clean architecture needs DI outside widget tree

**Example complexity:**
```dart
// Provider - widget tree coupling
MultiProvider(
  providers: [
    Provider<FirebaseFirestore>(create: (_) => FirebaseFirestore.instance),
    ProxyProvider<FirebaseFirestore, ItemRepository>(
      create: (_) => ItemRepositoryImpl(/* need firestore */),
    ),
  ],
  child: MyApp(),
)

// GetIt - clean separation
sl.registerLazySingleton<FirebaseFirestore>(() => FirebaseFirestore.instance);
sl.registerLazySingleton<ItemRepository>(() => ItemRepositoryImpl(sl()));
```

### 2. Riverpod
**Rejected because:**
- **Provider-based:** Similar widget tree issues as Provider
- **Newer/less mature:** Smaller community, fewer examples for clean architecture
- **Overkill:** Riverpod is excellent for state management, but we're using BLoC for that
- **Learning curve:** Team would need to learn both Riverpod AND BLoC
- **Code generation:** Also requires code generation (same as Injectable)

### 3. Manual DI (no framework)
**Rejected because:**
- **Too much boilerplate:** Manual registration of 50+ classes
- **Error-prone:** Easy to forget to register dependencies
- **No lifecycle management:** Have to manually track singletons vs factories
- **Testing difficulty:** No easy reset mechanism

**Example boilerplate:**
```dart
// Manual DI - lots of boilerplate
class ServiceLocator {
  static FirebaseFirestore? _firestore;
  static ItemRepository? _itemRepository;
  static GetItemsUseCase? _getItemsUseCase;

  static FirebaseFirestore get firestore {
    _firestore ??= FirebaseFirestore.instance;
    return _firestore!;
  }

  static ItemRepository get itemRepository {
    _itemRepository ??= ItemRepositoryImpl(firestore);
    return _itemRepository!;
  }

  // ... 50+ more getters
}
```

### 4. Injectable alone (no GetIt)
**Not viable:** Injectable requires GetIt as the underlying service locator

## Implementation Details

### Project Structure
```
lib/
├── core/
│   └── di/
│       ├── injection.dart        # GetIt setup, manual registration
│       └── injection.config.dart # Generated by Injectable
└── main.dart                     # Calls configureDependencies()
```

### Build Configuration
```yaml
# build.yaml
targets:
  $default:
    builders:
      injectable_generator:injectable_builder:
        enabled: true
        options:
          auto_register: true
```

### Initialization Flow
1. App starts (`main.dart`)
2. Initialize Firebase
3. Call `await configureDependencies()`
   - Runs generated `sl.init()` (registers @injectable classes)
   - Runs `_registerManualDependencies()` (Firebase, etc.)
4. Service locator ready
5. App runs

## References

- [GetIt Documentation](https://pub.dev/packages/get_it)
- [Injectable Documentation](https://pub.dev/packages/injectable)
- [Service Locator Pattern](https://en.wikipedia.org/wiki/Service_locator_pattern)
- [Dependency Injection in Flutter](https://medium.com/flutter-community/dependency-injection-in-flutter-f19fb66a0740)
- Related ADRs:
  - ADR-001: Clean Architecture Adoption
  - ADR-005: Testing Strategy
