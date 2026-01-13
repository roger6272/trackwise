# ADR-005: Testing Strategy

**Status:** Accepted

**Date:** 2026-01-03

**Deciders:** Development Team

**Technical Story:** Task 005 - Set Up Testing Infrastructure

## Context

The migration from FlutterFlow to Clean Architecture requires a comprehensive testing strategy. The FlutterFlow codebase had:
- **0 tests** (FlutterFlow doesn't generate tests)
- No way to test business logic in isolation
- Tight coupling between UI and data access
- Difficult to mock Firebase services

Clean Architecture enables testing at every layer. We need a strategy that:
1. Ensures code quality and correctness
2. Catches regressions early
3. Enables confident refactoring
4. Supports test-driven development (TDD)
5. Provides fast feedback during development
6. Achieves meaningful code coverage (70%+ target)

## Decision

Implement a **comprehensive testing pyramid** with three test types:

### 1. Unit Tests (70% of tests)

**Purpose:** Test individual components in isolation

**Scope:**
- Validators
- Use cases
- Repositories
- Data sources
- Entities and models
- Failures and exceptions
- Utility functions

**Tools:**
- `flutter_test` - Testing framework
- `mockito` - Mocking framework
- `mocktail` - Alternative mocking (null-safe)

**Pattern:**
```dart
group('GetItemsUseCase', () {
  late GetItemsUseCase useCase;
  late MockItemRepository mockRepository;

  setUp(() {
    mockRepository = MockItemRepository();
    useCase = GetItemsUseCase(mockRepository);
  });

  test('should return items when repository call succeeds', () async {
    // arrange
    when(() => mockRepository.getItems())
        .thenAnswer((_) async => Right([testItem]));

    // act
    final result = await useCase(NoParams());

    // assert
    expect(result, Right([testItem]));
    verify(() => mockRepository.getItems()).called(1);
  });
});
```

**Coverage Target:** 80%+ for domain and data layers

### 2. Widget Tests (25% of tests)

**Purpose:** Test widgets and UI logic

**Scope:**
- Widget rendering
- User interactions (taps, swipes, input)
- BLoC integration
- Navigation
- Form validation UI

**Tools:**
- `flutter_test` - Widget testing framework
- `bloc_test` - BLoC testing utilities

**Pattern:**
```dart
testWidgets('should display items when ItemLoaded state', (tester) async {
  // arrange
  final mockBloc = MockItemBloc();
  whenListen(
    mockBloc,
    Stream.fromIterable([ItemLoaded([testItem])]),
    initialState: ItemInitial(),
  );

  // act
  await tester.pumpWidget(
    BlocProvider.value(
      value: mockBloc,
      child: MaterialApp(home: ItemListWidget()),
    ),
  );
  await tester.pump();

  // assert
  expect(find.text('Test Item'), findsOneWidget);
});
```

**Coverage Target:** All critical user flows tested

### 3. Integration Tests (5% of tests)

**Purpose:** Test feature flows end-to-end

**Scope:**
- Complete user journeys (login → add item → increment → logout)
- Firebase integration (with test database)
- Bluetooth integration (with mock devices)
- Multi-screen navigation flows

**Tools:**
- `integration_test` - Integration testing framework
- `flutter_driver` - For running on real devices

**Pattern:**
```dart
testWidgets('complete item flow', (tester) async {
  await tester.pumpWidget(MyApp());

  // User creates item
  await tester.tap(find.byIcon(Icons.add));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), 'New Item');
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();

  // User increments item
  await tester.tap(find.text('New Item'));
  await tester.pumpAndSettle();

  // Verify item incremented in Firebase
  expect(find.text('1'), findsOneWidget);
});
```

**Coverage Target:** All major user flows tested

### Test Organization

```
test/
├── helpers/              # Shared test utilities
│   ├── test_helpers.dart
│   └── test_helpers.mocks.dart
├── fixtures/             # Test data
│   └── test_fixtures.dart
├── core/                 # Core tests
│   ├── error/
│   │   └── failures_test.dart
│   └── utils/
│       └── validators_test.dart
├── features/             # Feature tests (mirrors lib structure)
│   └── items/
│       ├── domain/
│       │   ├── entities/
│       │   │   └── item_test.dart
│       │   └── usecases/
│       │       └── get_items_usecase_test.dart
│       ├── data/
│       │   ├── models/
│       │   │   └── item_model_test.dart
│       │   ├── datasources/
│       │   │   └── item_remote_datasource_test.dart
│       │   └── repositories/
│       │       └── item_repository_impl_test.dart
│       └── presentation/
│           ├── bloc/
│           │   └── item_bloc_test.dart
│           └── widgets/
│               └── item_list_widget_test.dart
└── integration/          # Integration tests
    └── item_flow_test.dart
```

### Mocking Strategy

**Use Mockito with code generation:**

1. Define mock annotations in `test/helpers/test_helpers.dart`:
```dart
@GenerateMocks([
  FirebaseFirestore,
  FirebaseAuth,
  ItemRepository,
  ItemRemoteDataSource,
])
class TestHelpers {}
```

2. Generate mocks:
```bash
flutter pub run build_runner build
```

3. Use mocks in tests:
```dart
final mockRepository = MockItemRepository();
when(() => mockRepository.getItems()).thenAnswer((_) async => Right([testItem]));
```

### Test Fixtures

Centralize test data in `test/fixtures/test_fixtures.dart`:
```dart
const testItemData = {
  'item_name': 'Test Item',
  'todaycount': 5,
  'increment_by': 1,
};

final testItem = Item(
  id: 'item_123',
  name: 'Test Item',
  todayCount: 5,
  incrementBy: 1,
);
```

### Coverage Configuration

Run tests with coverage:
```bash
flutter test --coverage
```

Generate HTML report:
```bash
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

**Coverage Targets:**
- Domain layer: 90%+ (business logic is critical)
- Data layer: 80%+ (repository and data sources)
- Presentation layer: 70%+ (BLoCs and widgets)
- Overall: 75%+ average

## Consequences

### Positive

1. **Confidence:** Can refactor safely with comprehensive test coverage
2. **Fast feedback:** Unit tests run in <2 seconds
3. **Regression prevention:** Tests catch bugs before production
4. **Documentation:** Tests serve as usage examples
5. **Design improvement:** Testable code is usually better-designed code
6. **TDD enablement:** Can write tests first, then implementation
7. **Mocking support:** Easy to test in isolation with mocks
8. **CI/CD integration:** Automated testing in pipeline
9. **Code quality:** Forces thinking about edge cases
10. **Maintainability:** Tests make refactoring safer

### Negative

1. **Initial time investment:** Writing tests takes time upfront
2. **Maintenance burden:** Tests need updating when requirements change
3. **Mock maintenance:** Generated mocks need regeneration when interfaces change
4. **False confidence:** High coverage doesn't guarantee correctness
5. **Test brittleness:** Over-specific tests can break on refactoring
6. **Build time:** Mock generation adds to build process
7. **Learning curve:** Team needs to learn testing best practices

### Neutral

1. **Test code volume:** Tests often 2-3x the size of production code
2. **Package dependencies:** Adds mockito, bloc_test, mocktail
3. **Coverage metrics:** Can become a vanity metric if not meaningful

## Alternatives Considered

### 1. Manual Testing Only
**Rejected because:**
- **Not scalable:** Manual testing takes too long for large apps
- **Human error:** Easy to forget test cases
- **No regression prevention:** Can't easily re-run all tests
- **Slow feedback:** Find bugs late in development cycle
- **No CI/CD:** Can't automate quality checks

### 2. Integration Tests Only
**Rejected because:**
- **Slow:** Integration tests take minutes to run
- **Flaky:** Depend on Firebase, network, etc.
- **Hard to debug:** Failures could be in any layer
- **Poor coverage:** Can't test all edge cases
- **Late feedback:** Find bugs after writing lots of code

### 3. Widget Tests Only
**Rejected because:**
- **Can't test domain logic:** Business rules need unit tests
- **Slower than unit tests:** Require widget tree setup
- **Harder to maintain:** UI changes break tests
- **Limited coverage:** Can't test data layer in isolation

### 4. TDD Exclusively
**Rejected because:**
- **Too strict:** Not practical for all situations
- **Learning curve:** Team not experienced with TDD
- **Slows initial development:** Writing tests first takes practice
- **Not necessary:** Tests after implementation are still valuable

Decision: **Use TDD when appropriate, but don't mandate it**

### 5. 100% Code Coverage Target
**Rejected because:**
- **Diminishing returns:** Last 10% is very expensive
- **False sense of security:** Coverage ≠ quality
- **Wastes time:** Testing trivial getters/setters
- **Discourages refactoring:** Fear of breaking coverage metrics

Decision: **75% overall target with focus on critical paths**

## Implementation Details

### Testing Workflow

**1. Feature Development:**
```bash
# 1. Write implementation
# 2. Write tests
# 3. Run tests
flutter test test/features/items/

# 4. Check coverage
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

**2. Continuous Integration:**
```yaml
# .github/workflows/test.yml
- run: flutter test --coverage
- run: flutter test integration_test/
- uses: codecov/codecov-action@v3
```

**3. Pre-commit Hook:**
```bash
#!/bin/bash
# Run tests before commit
flutter test || exit 1
```

### BLoC Testing Pattern

Use `bloc_test` package for concise BLoC tests:
```dart
blocTest<ItemBloc, ItemState>(
  'emits [ItemLoading, ItemLoaded] when LoadItems succeeds',
  build: () {
    when(() => mockGetItems(any())).thenAnswer((_) async => Right([testItem]));
    return ItemBloc(getItems: mockGetItems);
  },
  act: (bloc) => bloc.add(LoadItems()),
  expect: () => [ItemLoading(), ItemLoaded([testItem])],
  verify: (_) {
    verify(() => mockGetItems(NoParams())).called(1);
  },
);
```

### Golden Tests for Widgets

Use golden file testing for complex widgets:
```dart
testWidgets('ItemCard matches golden file', (tester) async {
  await tester.pumpWidget(ItemCard(item: testItem));
  await expectLater(
    find.byType(ItemCard),
    matchesGoldenFile('goldens/item_card.png'),
  );
});
```

## Current Status

**Task 005 Complete:**
- ✅ Test infrastructure set up
- ✅ Mock generation configured
- ✅ Test fixtures created
- ✅ 67 tests passing (Validators: 42, Failures: 24, Placeholder: 1)
- ✅ Coverage reporting enabled
- ✅ Documentation created (test/README.md)

**Next Steps:**
- Write tests for each feature as it's developed (Tasks 007+)
- Achieve 75%+ coverage by end of migration
- Set up CI/CD with automated testing
- Configure pre-commit hooks for test running

## References

- [Flutter Testing Documentation](https://docs.flutter.dev/testing)
- [Test-Driven Development by Example - Kent Beck](https://www.amazon.com/Test-Driven-Development-Kent-Beck/dp/0321146530)
- [bloc_test Package](https://pub.dev/packages/bloc_test)
- [Mockito Documentation](https://pub.dev/packages/mockito)
- [Flutter Testing Best Practices](https://flutter.dev/docs/cookbook/testing)
- [The Practical Test Pyramid](https://martinfowler.com/articles/practical-test-pyramid.html)
- Related ADRs:
  - ADR-001: Clean Architecture Adoption
  - ADR-002: Dependency Injection with GetIt
  - ADR-003: State Management with BLoC
  - ADR-004: Error Handling with Dartz
