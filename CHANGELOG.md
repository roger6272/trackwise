# Changelog

All notable changes to Trackwise will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Nothing yet

### Changed
- Nothing yet

### Fixed
- Nothing yet

## [1.0.0] - 2026-01-13

### Added

#### Core Features
- Items CRUD functionality with Firestore sync
- ESP32 Bluetooth integration for hardware button tracking
- Real-time event logging from ESP32 device
- Bar charts and cumulative charts for data visualization
- CSV data export via email

#### Authentication
- Email/password authentication
- Google Sign-In
- Apple Sign-In (iOS)
- Password reset functionality
- Auth state persistence

#### User Profile & GDPR
- User profile management
- GDPR-compliant data export (JSON format)
- GDPR-compliant account deletion with double confirmation
- Privacy policy viewer (in-app markdown rendering)

#### Monitoring & Analytics
- Firebase Crashlytics for crash reporting
- Firebase Analytics with custom events tracking
- Firebase Performance Monitoring with custom traces
- AnalyticsService for tracking user behavior
- PerformanceService for operation tracing
- CrashlyticsService for error context logging

#### Documentation
- Privacy policy document
- Google Play Store setup guide
- Apple App Store setup guide
- App descriptions and keywords

### Changed
- Migrated from FlutterFlow to Clean Architecture
- Replaced FlutterFlow state management with BLoC pattern
- Implemented dependency injection with GetIt and Injectable
- Restructured codebase into feature-based modules

### Technical Details
- Domain layer: Entities, Repository interfaces, Use cases
- Data layer: Models, Data sources, Repository implementations
- Presentation layer: BLoCs, Events, States, Pages
- Core: DI configuration, Error handling, Services

### Architecture
```
lib/
├── core/
│   ├── di/          # Dependency injection
│   ├── error/       # Failures and exceptions
│   ├── services/    # Analytics, Crashlytics, Performance
│   └── usecases/    # Base use case class
├── features/
│   ├── auth/        # Authentication feature
│   ├── events/      # Event logging feature
│   ├── items/       # Items management feature
│   └── profile/     # User profile & GDPR feature
```

## [0.1.0] - 2026-01-01

### Added
- Initial FlutterFlow prototype
- Basic items management UI
- Simple Bluetooth connection to ESP32
- Firebase project setup
- Basic Firestore data model

### Notes
- This was the original FlutterFlow-generated codebase
- Served as proof of concept before clean architecture migration

---

[Unreleased]: https://github.com/roger6272/trackwise/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/roger6272/trackwise/releases/tag/v1.0.0
[0.1.0]: https://github.com/roger6272/trackwise/releases/tag/v0.1.0
