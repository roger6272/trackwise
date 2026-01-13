# Trackwise

Habit tracking app with ESP32 Bluetooth integration for physical button counters.

**Status:** Migrating from FlutterFlow to Clean Architecture

## Project Structure

This project follows **Clean Architecture** principles with a feature-based organization:

```
lib/
├── core/                      # Shared core functionality
│   ├── di/                    # Dependency Injection (GetIt)
│   ├── error/                 # Failures & Exceptions
│   ├── theme/                 # App Theme & Colors
│   ├── usecases/              # Base UseCase classes
│   └── utils/                 # Constants, Validators, Helpers
│
├── features/                  # Feature modules (Clean Architecture)
│   ├── auth/                  # Authentication & Authorization
│   │   ├── data/              # Data sources, models, repository impl
│   │   │   ├── datasources/   # Firebase Auth data source
│   │   │   ├── models/        # User model
│   │   │   └── repositories/  # AuthRepository implementation
│   │   ├── domain/            # Business logic (pure Dart)
│   │   │   ├── entities/      # User entity
│   │   │   ├── repositories/  # AuthRepository interface
│   │   │   └── usecases/      # SignIn, SignOut, SignUp use cases
│   │   └── presentation/      # UI layer
│   │       ├── bloc/          # AuthBloc for state management
│   │       ├── pages/         # Login, SignUp pages
│   │       └── widgets/       # Auth UI widgets
│   │
│   ├── items/                 # Items CRUD (counters/habits)
│   ├── bluetooth/             # ESP32 BLE integration
│   ├── events/                # Event logging & history
│   ├── export/                # CSV data export
│   └── profile/               # User profile & GDPR compliance
│
├── account_profile_creation/  # Legacy FlutterFlow code (for reference)
├── custom_code/               # FlutterFlow custom actions (preserved)
├── flutter_flow/              # FlutterFlow utilities (preserved)
│
├── main.dart                  # App entry point
└── app.dart                   # Root app widget

```

## Architecture Layers

Each feature follows a **three-layer architecture**:

### 1. Presentation Layer (`presentation/`)
- **BLoC**: State management using flutter_bloc
- **Pages**: Full-screen UI components
- **Widgets**: Reusable UI components
- **Dependencies**: Can access Domain layer only

### 2. Domain Layer (`domain/`)
- **Entities**: Business objects (pure Dart)
- **Repositories**: Abstract interfaces
- **Use Cases**: Business logic operations
- **Dependencies**: No dependencies on other layers (pure Dart)

### 3. Data Layer (`data/`)
- **Models**: Data models (extend entities)
- **Data Sources**: External data sources (Firestore, API, local storage)
- **Repositories**: Concrete implementations of domain repositories
- **Dependencies**: Can access Domain layer only

## Key Technologies

- **State Management:** flutter_bloc
- **Dependency Injection:** GetIt
- **Error Handling:** dartz (Either<Failure, Success>)
- **Database:** Cloud Firestore
- **Authentication:** Firebase Auth
- **Bluetooth:** flutter_blue_plus (ESP32 BLE)
- **Testing:** mockito, bloc_test

## Getting Started

FlutterFlow projects are built to run on the Flutter _stable_ release.

### Clean Architecture Migration

This project is actively being migrated from FlutterFlow-generated code to Clean Architecture.

**Migration Status:**
- ✅ Task 001: Folder structure created
- ⏳ Task 002: GetIt configuration (pending)
- ⏳ Remaining tasks: See `.claude/epics/flutterflow-to-clean-architecture-migration/`

**Legacy Code:** FlutterFlow code is preserved in `lib/account_profile_creation/` and `lib/custom_code/` for reference during migration.
