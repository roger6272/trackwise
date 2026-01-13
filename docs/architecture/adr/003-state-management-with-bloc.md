# ADR-003: State Management with BLoC Pattern

**Status:** Accepted

**Date:** 2026-01-03

**Deciders:** Development Team

**Technical Story:** Task 004 - Add Required Dependencies

## Context

The Presentation layer needs a state management solution to:

1. Separate business logic from UI
2. Handle asynchronous operations (Firebase, Bluetooth)
3. Manage complex state (loading, success, error)
4. Enable reactive UI updates
5. Support testing without Flutter dependencies
6. Handle multiple events triggering state changes

Trackwise requirements:
- Real-time Firebase updates (items changing, event logs)
- Bluetooth connection states (scanning, connected, disconnected)
- Form validation states
- Loading states during async operations
- Error handling and display

## Decision

Use **BLoC (Business Logic Component)** pattern with the **flutter_bloc** package.

### BLoC Pattern Overview

**BLoC = Events in → Business Logic → States out**

```dart
// Event: User action or external trigger
abstract class ItemEvent extends Equatable {}
class LoadItems extends ItemEvent {}
class IncrementItem extends ItemEvent {
  final String itemId;
  IncrementItem(this.itemId);
}

// State: UI representation
abstract class ItemState extends Equatable {}
class ItemInitial extends ItemState {}
class ItemLoading extends ItemState {}
class ItemLoaded extends ItemState {
  final List<Item> items;
  ItemLoaded(this.items);
}
class ItemError extends ItemState {
  final String message;
  ItemError(this.message);
}

// BLoC: Business logic
class ItemBloc extends Bloc<ItemEvent, ItemState> {
  final GetItemsUseCase getItems;
  final IncrementItemUseCase incrementItem;

  ItemBloc({
    required this.getItems,
    required this.incrementItem,
  }) : super(ItemInitial()) {
    on<LoadItems>(_onLoadItems);
    on<IncrementItem>(_onIncrementItem);
  }

  Future<void> _onLoadItems(LoadItems event, Emitter<ItemState> emit) async {
    emit(ItemLoading());
    final result = await getItems(NoParams());
    result.fold(
      (failure) => emit(ItemError(failure.message)),
      (items) => emit(ItemLoaded(items)),
    );
  }
}
```

### Widget Integration

```dart
// Provide BLoC to widget tree
BlocProvider(
  create: (context) => sl<ItemBloc>()..add(LoadItems()),
  child: ItemListWidget(),
)

// Listen to state changes
BlocBuilder<ItemBloc, ItemState>(
  builder: (context, state) {
    if (state is ItemLoading) return CircularProgressIndicator();
    if (state is ItemError) return Text(state.message);
    if (state is ItemLoaded) return ListView(items: state.items);
    return SizedBox();
  },
)

// Trigger events
context.read<ItemBloc>().add(IncrementItem('item_123'));
```

### Architecture Integration

**Presentation Layer Structure:**
```
lib/features/items/presentation/
├── bloc/
│   ├── item_bloc.dart       # BLoC implementation
│   ├── item_event.dart      # Events (user actions)
│   └── item_state.dart      # States (UI data)
└── widgets/
    ├── item_list_widget.dart
    └── item_card_widget.dart
```

**BLoC → Use Case → Repository:**
```
ItemBloc (presentation)
  ↓ calls
GetItemsUseCase (domain)
  ↓ calls
ItemRepository (domain interface)
  ↓ implemented by
ItemRepositoryImpl (data)
```

## Consequences

### Positive

1. **Clear separation:** Business logic completely separate from widgets
2. **Testability:** BLoC can be tested without Flutter (pure Dart unit tests)
3. **Reactive:** UI automatically updates when state changes
4. **Type-safe:** Events and states are strongly typed
5. **Predictable:** Deterministic state transitions (event → state)
6. **Debuggable:** BlocObserver logs all events and state changes
7. **Time-travel debugging:** Can replay events in order
8. **Stream-based:** Built on Dart streams (familiar to Flutter devs)
9. **Community support:** Official Flutter state management solution
10. **Well documented:** Extensive documentation and examples
11. **Testing tools:** bloc_test package for easy testing
12. **DevTools integration:** Flutter DevTools has BLoC inspector

### Negative

1. **Boilerplate:** Requires event, state, and BLoC files per feature (3 files minimum)
2. **Learning curve:** Team needs to understand streams and async programming
3. **Verbose:** More code than setState or Provider for simple cases
4. **Event classes:** Every user action needs an event class
5. **State classes:** Every UI state needs a state class
6. **Equatable dependency:** Need Equatable for proper state comparison
7. **Memory management:** Must close/dispose BLoCs properly

### Neutral

1. **Streams:** Uses Dart streams (powerful but complex)
2. **Immutability:** States should be immutable (requires copyWith methods)
3. **Package dependency:** Adds flutter_bloc and bloc packages

## Alternatives Considered

### 1. Provider
**Rejected because:**
- **Doesn't enforce separation:** Business logic often ends up in ChangeNotifier
- **Not ideal for events:** Provider is value-based, not event-based
- **Testing complexity:** ChangeNotifier has Flutter dependencies
- **Less structure:** No clear event/state pattern
- **Reactive limitations:** Manual notifyListeners() calls

**Example - mixing logic with UI:**
```dart
class ItemProvider extends ChangeNotifier {
  List<Item> items = [];
  bool isLoading = false;

  // Business logic mixed with state management
  Future<void> loadItems() async {
    isLoading = true;
    notifyListeners(); // Manual call

    final result = await getItemsUseCase(NoParams());
    result.fold(
      (failure) => {/* error handling */},
      (data) => items = data,
    );

    isLoading = false;
    notifyListeners(); // Another manual call
  }
}
```

### 2. Riverpod
**Rejected because:**
- **Different paradigm:** Riverpod is provider-based, not event-based
- **Newer:** Less mature than BLoC, smaller community
- **Overkill:** Riverpod is great for simple apps, but BLoC is better for complex state machines
- **Learning curve:** Team would need to learn new concepts (providers, modifiers, etc.)
- **Less prescriptive:** No clear structure for complex flows

### 3. setState (built-in)
**Rejected because:**
- **No separation:** Business logic in widgets
- **Not testable:** Cannot test without widget tests
- **Not scalable:** Becomes unmaintainable with complex state
- **No error handling pattern:** Have to manually manage error states
- **No loading states:** Have to manually track loading
- **Widget rebuilds:** Inefficient, rebuilds entire widget tree

### 4. Redux
**Rejected because:**
- **Too complex:** Single global store is overkill for most features
- **Verbose:** Even more boilerplate than BLoC
- **Learning curve:** Redux concepts (actions, reducers, middleware) are complex
- **Less Flutter-friendly:** Redux comes from React, not native to Flutter
- **Immutability everywhere:** All state must be immutable (more complexity)

### 5. GetX
**Rejected because:**
- **Too magical:** Uses global state and dependency injection in unconventional ways
- **Service locator abuse:** GetX uses service locator extensively (anti-pattern)
- **Testing difficulty:** Global state makes testing harder
- **Community concerns:** Less professional, more opinionated
- **Not following Flutter conventions:** Goes against Flutter's reactive principles

### 6. MobX
**Rejected because:**
- **Code generation:** Requires build_runner (we already have Injectable for DI)
- **Less popular in Flutter:** Smaller community than BLoC
- **Observable pattern:** Different paradigm than streams
- **Learning curve:** Annotations and reactions are new concepts
- **Testing:** Need special setup for observables

## Implementation Details

### BLoC Naming Conventions

**Events:** Verb + Noun (past tense)
- `LoadItems`, `IncrementItem`, `DeleteItem`
- `ConnectToDevice`, `DisconnectFromDevice`

**States:** Noun + Adjective/Status
- `ItemInitial`, `ItemLoading`, `ItemLoaded`, `ItemError`
- `DeviceDisconnected`, `DeviceConnecting`, `DeviceConnected`

**BLoC:** Feature + Bloc
- `ItemBloc`, `AuthBloc`, `BluetoothBloc`

### State Classes Pattern

Always include all possible states:
```dart
// Initial: Before any events
class ItemInitial extends ItemState {}

// Loading: Async operation in progress
class ItemLoading extends ItemState {}

// Success: Operation completed successfully
class ItemLoaded extends ItemState {
  final List<Item> items;
  ItemLoaded(this.items);
}

// Error: Operation failed
class ItemError extends ItemState {
  final String message;
  ItemError(this.message);
}
```

### BLoC Testing with bloc_test

```dart
blocTest<ItemBloc, ItemState>(
  'emits [ItemLoading, ItemLoaded] when LoadItems succeeds',
  build: () {
    when(() => mockGetItems(any())).thenAnswer(
      (_) async => Right([testItem]),
    );
    return ItemBloc(getItems: mockGetItems);
  },
  act: (bloc) => bloc.add(LoadItems()),
  expect: () => [
    ItemLoading(),
    ItemLoaded([testItem]),
  ],
);
```

### BLoC Observer for Debugging

```dart
class AppBlocObserver extends BlocObserver {
  @override
  void onEvent(Bloc bloc, Object? event) {
    super.onEvent(bloc, event);
    print('Event: ${bloc.runtimeType} - $event');
  }

  @override
  void onTransition(Bloc bloc, Transition transition) {
    super.onTransition(bloc, transition);
    print('Transition: ${bloc.runtimeType} - $transition');
  }

  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    print('Error: ${bloc.runtimeType} - $error');
    super.onError(bloc, error, stackTrace);
  }
}
```

## References

- [BLoC Library Documentation](https://bloclibrary.dev/)
- [flutter_bloc Package](https://pub.dev/packages/flutter_bloc)
- [bloc_test Package](https://pub.dev/packages/bloc_test)
- [BLoC Architecture by Felix Angelov](https://www.youtube.com/watch?v=THCkkQ-V1-8)
- [Flutter BLoC - Official Tutorial](https://bloclibrary.dev/#/coreconcepts)
- Related ADRs:
  - ADR-001: Clean Architecture Adoption
  - ADR-002: Dependency Injection with GetIt
  - ADR-005: Testing Strategy
