# Changelog

All notable changes to Traxelos will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Nothing yet

### Changed
- Nothing yet

### Fixed
- Nothing yet

## [1.1.0] - 2026-03-31

### Added

#### Multi-Device Support
- Pair up to 10 devices per account (5 simultaneous connections)
- Device color coding and management UI
- Sync conflict detection with device-as-source-of-truth resolution
- Exclusive device leasing to prevent multi-user conflicts
- Factory reset support for paired devices

#### BLE OTA Firmware Updates
- Over-the-air firmware updates via Bluetooth Low Energy
- MAX17048 fuel gauge battery level monitoring
- Standard Bluetooth Battery Service (0x180F)
- Dual-partition OTA with automatic rollback on failure
- SHA256 verification of firmware images
- Safe battery check (requires >20% for update)
- Optional/required update banners with version gating
- Per-device firmware update tracking via Firebase Remote Config

#### Enhanced Onboarding
- 5-step guided wizard (Profile → Intro → Device Pairing → Item Creation → Done)
- Reuses existing BLE pairing and item creation components
- Onboarding progress tracking (device paired, item created)

### Changed

#### Performance Optimizations
- Fixed O(n²) reordering with Map-based lookups
- Wrapped 29+ debug prints in kDebugMode guards
- Firmware: snprintf-based key handling, non-blocking vibration
- BLE chunk delays standardized to 20ms
- NVS write batching with flush safety

#### Production Hardening
- Renamed app ID to com.traxelos.app
- Configured release signing for Android
- Enabled code obfuscation for release builds
- Enhanced ProGuard rules for all dependencies

### Fixed
- Prevented RangeError when SHA256 hash shorter than 8 characters in OTA log
- Fixed redundant error/complete transfer banners with progress sheet
- Fixed disconnect-during-transfer handling
- Fixed reboot race condition after OTA completion

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

[Unreleased]: https://github.com/roger6272/trackwise/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/roger6272/trackwise/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/roger6272/trackwise/releases/tag/v1.0.0
[0.1.0]: https://github.com/roger6272/trackwise/releases/tag/v0.1.0
