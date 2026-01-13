# ADR-001: Clean Architecture Adoption

**Status:** Accepted

**Date:** 2026-01-03

**Deciders:** Development Team

**Technical Story:** Migration from FlutterFlow to maintainable architecture

## Context

The Trackwise application was initially built using FlutterFlow, a low-code platform that generates Flutter code. While FlutterFlow enabled rapid prototyping, the codebase has become difficult to maintain and extend:

- **Tight coupling:** UI, business logic, and data access are mixed together
- **Testing difficulty:** Direct Firebase calls in widgets make unit testing impossible
- **Code generation conflicts:** Manual changes conflict with FlutterFlow regeneration
- **Limited flexibility:** Custom features require workarounds
- **Technical debt:** 1000+ analysis warnings from generated code

The app needs to support:
- ESP32 Bluetooth integration for habit tracking
- Offline-first functionality
- Complex business rules (daily resets, reminders, incrementing)
- GDPR compliance (data export, account deletion)
- Multiple platforms (iOS, Android, Web)

## Decision

Adopt **Clean Architecture** with three distinct layers:

### 1. Presentation Layer (UI)
- **Responsibilities:** Display data, handle user input
- **Components:** Widgets, BLoC (state management)
- **Dependencies:** Can depend on Domain layer only
- **Location:** `lib/features/[feature]/presentation/`

### 2. Domain Layer (Business Logic)
- **Responsibilities:** Business rules, use cases, entities
- **Components:** Use cases, entities, repository interfaces, failures
- **Dependencies:** No dependencies on other layers (pure Dart)
- **Location:** `lib/features/[feature]/domain/`

### 3. Data Layer (Data Access)
- **Responsibilities:** External data sources, caching
- **Components:** Repository implementations, data sources (remote/local), models
- **Dependencies:** Can depend on Domain layer only
- **Location:** `lib/features/[feature]/data/`

### Core Layer (Shared)
- **Purpose:** Shared utilities, base classes, constants
- **Location:** `lib/core/`

### Dependency Rule
Dependencies point inward only: Presentation → Domain ← Data

## Consequences

### Positive

1. **Testability:** Each layer can be tested in isolation with mocks
2. **Maintainability:** Clear separation of concerns makes code easier to understand
3. **Flexibility:** Can swap implementations (e.g., Firebase → local DB) without affecting business logic
4. **Scalability:** New features follow consistent patterns
5. **Team collaboration:** Developers can work on different layers simultaneously
6. **Platform independence:** Domain layer has zero Flutter dependencies
7. **GDPR compliance:** Data export/deletion isolated in data layer
8. **Error handling:** Consistent error propagation through layers

### Negative

1. **Initial overhead:** More boilerplate than FlutterFlow (interfaces, models, mappers)
2. **Learning curve:** Team needs to understand clean architecture principles
3. **Development time:** Features take longer initially (3-layer implementation)
4. **File count:** More files per feature (~10-15 vs 2-3 in FlutterFlow)
5. **Abstraction complexity:** Beginners might find repository pattern confusing

### Neutral

1. **Code volume:** More total lines of code, but each piece is simpler
2. **Build time:** Similar build times (more files, but smaller individual files)
3. **Package dependencies:** Need additional packages (dartz, injectable, equatable)

## Alternatives Considered

### 1. Keep FlutterFlow
**Rejected because:**
- Cannot achieve required testability
- Custom Bluetooth integration is too complex for FlutterFlow
- Technical debt is unsustainable
- Offline-first requires manual code conflicting with regeneration

### 2. MVC (Model-View-Controller)
**Rejected because:**
- Doesn't enforce clear boundaries between layers
- Controllers often become "god objects" with too many responsibilities
- Still allows direct data access from views
- Less testable than clean architecture

### 3. MVVM (Model-View-ViewModel)
**Rejected because:**
- Similar issues to MVC in Flutter context
- ViewModels can still access data sources directly
- Doesn't provide repository abstraction for data access
- Less common in Flutter community (harder to find examples)

### 4. Feature-first without Clean Architecture
**Rejected because:**
- Doesn't enforce separation between business logic and data access
- Testing still difficult without repository abstraction
- No clear pattern for error handling across layers

## References

- [Clean Architecture by Robert C. Martin](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [Flutter Clean Architecture Guide by Reso Coder](https://resocoder.com/flutter-clean-architecture-tdd/)
- [Clean Architecture in Flutter - Fireship](https://fireship.io/lessons/flutter-clean-architecture/)
- Related ADRs:
  - ADR-002: Dependency Injection with GetIt
  - ADR-003: State Management with BLoC
  - ADR-004: Error Handling with Dartz
  - ADR-005: Testing Strategy
