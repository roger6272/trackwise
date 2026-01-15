---
name: trackwise-app-migration
description: Complete migration from FlutterFlow to clean Flutter architecture
status: backlog
created: 2026-01-15T04:09:19Z
---

# PRD: Trackwise App Migration

## Executive Summary

Migrate the Trackwise app from FlutterFlow-generated code to a clean Flutter architecture. The goal is to achieve feature parity with the existing app, then remove all FlutterFlow dependencies. This replaces the previous fragmented migration attempt with a cohesive, page-by-page approach.

## Problem Statement

### What Problem Are We Solving?

The current Trackwise app is built with FlutterFlow-generated code that is:
- Verbose and difficult to maintain
- Tightly coupled with FF utilities, theme, and navigation
- Awkwardly mixed with clean architecture features already built

### Why Is This Important Now?

- Clean architecture foundation already exists (`features/`, `core/`)
- Previous migration attempt failed due to fragmented execution
- New implementations exist but are not wired up (all migration flags are `false`)
- Technical debt is accumulating

## User Stories

### Developer (Primary User)

- As a developer, I want all pages to use clean architecture patterns so the codebase is consistent
- As a developer, I want to remove FF dependencies so I have full control over the code
- As a developer, I want comprehensive tests so I can refactor with confidence

### End User (Indirect)

- As a user, I expect the app to work exactly the same after migration
- As a user, I should not notice any change in functionality

## Requirements

### Functional Requirements

#### App Structure

The app has 3 main navigation tabs:
1. **Home** - Items list (Main Page)
2. **Bluetooth** - Device connection/management
3. **Profile** - User settings and account

#### Pages to Migrate (10 total)

**Auth Flow (3 pages)**
1. Login Page - Email/password, Google, Apple sign-in
2. Signup Page - Account creation with same providers
3. Forgot Password Page - Password reset via email

**Items Flow (4 pages)**
4. Main Page (Items List)
   - List of user's items with name and count
   - Total/Today toggle for count display
   - Swipe actions: Activate, Update, Delete
   - Add item button (requires device connection)
   - Bottom navigation bar

5. Item Detail Page
   - View item details and statistics
   - Charts/graphs for item data

6. Item Setup Page
   - Create new item form

7. Item Update Page
   - Edit existing item

**Bluetooth Flow (3 pages)**
8. Connection Initiation Page
   - Entry point when no device connected
   - Prompt to connect device

9. Bluetooth Search Page
   - Scan for ESP32 devices
   - List available devices
   - Connect to selected device

10. Device Management Page
    - View connected device info
    - Disconnect option
    - Device settings

**Profile Flow (2 pages)**
11. Profile Page
    - User account info
    - App settings
    - Sign out

12. Download Page
    - Export data functionality

#### Core Features

**Authentication**
- Email/password authentication
- Google Sign-In
- Apple Sign-In
- Password reset flow
- Session persistence

**Bluetooth (ESP32)**
- Scan for nearby devices
- Connect/disconnect to device
- Send items list to device
- Send selected/active item to device
- Receive event data from device
- Time sync with device

**Items Management**
- CRUD operations for items
- Real-time sync with Firestore
- Total count tracking
- Today count tracking (resets daily)
- Activate item on device

**Data & Export**
- Event logging from device
- Charts and statistics
- CSV export
- Email export

### Non-Functional Requirements

1. **Feature Parity** - New pages must have identical functionality to old pages
2. **Visual Similarity** - UI should be similar (exact match not required)
3. **Test Coverage** - Each page should have widget tests
4. **No Regressions** - App must remain fully functional throughout migration
5. **Clean Architecture** - Follow existing patterns in `features/`

## Technical Approach

### Directory Structure

**Old App (to be deleted):**
```
lib/
├── flutter_flow/              # FF utilities - DELETE
├── account_profile_creation/  # FF pages - DELETE
├── components/                # FF components - DELETE
├── auth/                      # Keep (Firebase auth utils)
└── backend/                   # Keep (Firebase config)
```

**New App (target state):**
```
lib/
├── core/
│   ├── config/migration_flags.dart  # Remove after migration
│   ├── di/                          # Dependency injection
│   ├── router/app_router.dart       # Navigation
│   ├── theme/app_theme.dart         # Theming
│   ├── services/                    # Analytics, Crashlytics
│   ├── widgets/                     # Shared widgets (nav bar, etc.)
│   └── utils/
│
├── features/
│   ├── auth/presentation/pages/
│   │   ├── login_page.dart
│   │   ├── signup_page.dart
│   │   └── forgot_password_page.dart
│   │
│   ├── items/presentation/pages/
│   │   ├── items_list_page.dart     # Main page
│   │   ├── item_detail_page.dart
│   │   ├── item_form_page.dart      # Create/Edit
│   │   └── item_setup_page.dart
│   │
│   ├── bluetooth/presentation/pages/
│   │   ├── connection_initiation_page.dart
│   │   ├── bluetooth_search_page.dart
│   │   └── device_management_page.dart
│   │
│   ├── profile/presentation/pages/
│   │   ├── profile_page.dart
│   │   └── download_page.dart
│   │
│   ├── events/                      # Already exists
│   ├── charts/                      # Already exists
│   └── export/                      # Already exists
│
└── app.dart
```

### Migration Strategy

**Phase 1: Wire Up Existing Code**
- Enable migration flags one by one
- Test each flag thoroughly before enabling the next
- Fix any issues in existing new implementations

**Phase 2: Complete Missing Pages**
- Implement any pages not yet created
- Ensure all routes work in AppRouter
- Add widget tests for each page

**Phase 3: Cleanup**
- Remove all FF imports from features
- Delete `flutter_flow/` directory
- Delete `account_profile_creation/` directory
- Delete `components/` directory
- Remove migration flags system

### Existing Assets

**Already Created (need wiring):**
- `core/theme/app_theme.dart`
- `core/router/app_router.dart`
- `core/utils/app_util.dart`
- `core/config/migration_flags.dart`
- `features/auth/presentation/pages/` (login, signup, forgot_password)
- `features/profile/presentation/pages/profile_page.dart`
- `features/items/presentation/pages/` (items_list, item_detail, item_form)
- `features/bluetooth/presentation/bloc/bluetooth_bloc.dart`

**Need to Create:**
- `core/widgets/navigation_bar.dart` (bottom nav)
- `features/bluetooth/presentation/pages/` (3 pages)
- `features/profile/presentation/pages/download_page.dart`
- Widget tests for all pages

## Success Criteria

| Metric | Target |
|--------|--------|
| All pages migrated | 12 pages |
| FF directories deleted | 3 (flutter_flow, account_profile_creation, components) |
| FF imports remaining | 0 |
| Widget test coverage | 1+ test per page |
| App builds successfully | Every commit |
| All auth providers work | Email, Google, Apple |
| Bluetooth functionality | Scan, connect, send, receive |

## Dependencies

### Internal
- Existing `features/` domain and data layers
- Existing `core/di/` dependency injection
- Existing BLoCs (items, bluetooth, events, charts, export)

### External
- `go_router` - Navigation
- `flutter_bloc` - State management
- `firebase_auth` - Authentication
- `cloud_firestore` - Database
- `flutter_blue_plus` - Bluetooth
- `google_sign_in` - Google auth
- `sign_in_with_apple` - Apple auth

## Out of Scope

- UI/UX redesign (only functional migration)
- New features not in current app
- Backend/Firebase schema changes
- Bluetooth protocol changes
- Performance optimization (separate effort)
- iOS-specific or Android-specific features

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Breaking changes during migration | Use migration flags for gradual rollout |
| Missing edge cases | Keep FF code as reference until confident |
| Bluetooth complexity | Test extensively with real ESP32 device |
| Auth provider issues | Test all 3 providers (email, Google, Apple) |

## Epic Breakdown Suggestion

### Epic 1: Foundation & Auth
- Enable new router
- Enable new theme
- Wire up auth pages
- Test all auth flows

### Epic 2: Items Flow
- Wire up main page (items list)
- Wire up item detail page
- Wire up item form pages
- Add navigation bar widget

### Epic 3: Bluetooth Flow
- Create bluetooth pages
- Wire up bluetooth BLoC to pages
- Test with real device

### Epic 4: Profile & Export
- Wire up profile page
- Create download page
- Test export functionality

### Epic 5: Cleanup & Tests
- Add widget tests
- Remove FF imports
- Delete FF directories
- Remove migration flags
