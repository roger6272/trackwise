---
name: trackwise-app-migration
status: backlog
created: 2026-01-15T04:38:34Z
progress: 0%
prd: .claude/prds/trackwise-app-migration.md
github: https://github.com/roger6272/trackwise/issues/7
---

# Epic: trackwise-app-migration

## Overview

Migrate Trackwise from FlutterFlow to clean Flutter architecture by wiring up existing implementations, creating missing bluetooth pages, and removing FF dependencies. Most code already exists - this epic focuses on integration and cleanup.

## Architecture Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| State Management | flutter_bloc (existing) | Already in use, consistent patterns |
| Navigation | go_router via AppRouter | Already created, modern Flutter navigation |
| DI | get_it + injectable | Already configured in core/di/ |
| Theme | AppTheme (new) | Already created, replaces FF theme |

## Technical Approach

### Key Insight: Leverage Existing Code

Most implementations already exist but aren't wired up:
- **Auth pages** - Created, need router integration
- **Items pages** - Created, need router + BLoC wiring
- **Profile page** - Created, need router integration
- **Core infrastructure** - Router, theme, utils all ready
- **All BLoCs** - Items, Bluetooth, Events, Charts, Export exist

### What Needs Creation

Only 4 new files needed:
1. `core/widgets/app_navigation_bar.dart` - Bottom nav (3 tabs)
2. `features/bluetooth/presentation/pages/bluetooth_page.dart` - Connection initiation
3. `features/bluetooth/presentation/pages/bluetooth_search_page.dart` - Device scanning
4. `features/bluetooth/presentation/pages/device_management_page.dart` - Connected device

### Integration Strategy

1. Update `AppRouter` to include all routes
2. Update `main.dart` to use new router
3. Enable migration flags progressively
4. Test each flow before proceeding
5. Remove FF code only after all flows work

## Implementation Strategy

### Phase 1: Foundation
Enable new router and theme in main.dart. This unlocks all subsequent work.

### Phase 2: Flow Integration
Wire up auth → items → bluetooth → profile flows sequentially. Each flow depends on router working.

### Phase 3: Cleanup
Remove FF directories only after full app works on new architecture.

## Task Breakdown Preview

Consolidated to 7 tasks for focused execution:

- [ ] **Task 1: Foundation Setup** - Enable AppRouter and AppTheme in main.dart, verify app launches
- [ ] **Task 2: Auth Flow** - Wire auth pages to router, test email/Google/Apple sign-in
- [ ] **Task 3: Items Flow** - Wire items pages, create navigation bar widget, test CRUD operations
- [ ] **Task 4: Bluetooth Pages** - Create 3 bluetooth pages, wire to BluetoothBloc
- [ ] **Task 5: Profile & Export** - Wire profile page, create download page, test export
- [ ] **Task 6: Widget Tests** - Add tests for critical pages (auth, items list, bluetooth)
- [ ] **Task 7: FF Cleanup** - Remove FF imports, delete FF directories, remove migration flags

## Dependencies

### Prerequisites (All Met)
- [x] BLoCs exist (items, bluetooth, events, charts, export, auth)
- [x] Domain/Data layers complete for all features
- [x] Core infrastructure ready (DI, router, theme, utils)
- [x] Firebase configured (auth, firestore)

### External Packages (All Installed)
- go_router, flutter_bloc, firebase_auth, cloud_firestore
- flutter_blue_plus, google_sign_in, sign_in_with_apple

## Success Criteria (Technical)

| Criteria | Verification |
|----------|--------------|
| App launches with new router | `flutter run` succeeds |
| Auth flow complete | Sign in/up/out with all 3 providers |
| Items CRUD works | Create, read, update, delete items |
| Bluetooth connects | Scan, connect, send data to ESP32 |
| No FF imports | `grep -r "flutter_flow" lib/features` returns empty |
| FF directories deleted | `flutter_flow/`, `account_profile_creation/`, `components/` removed |
| Tests pass | `flutter test` passes |

## Estimated Effort

| Task | Complexity | Notes |
|------|------------|-------|
| Foundation Setup | Low | Config changes only |
| Auth Flow | Low | Pages exist, just routing |
| Items Flow | Medium | Navigation bar creation |
| Bluetooth Pages | Medium | 3 new pages to create |
| Profile & Export | Low | Mostly wiring |
| Widget Tests | Medium | ~6-8 test files |
| FF Cleanup | Low | Delete and verify |

**Total: 7 tasks** - Can be completed incrementally with working app at each step.

## Tasks Created

- [ ] [#8](https://github.com/roger6272/trackwise/issues/8) - Foundation Setup (parallel: false) - 2-4 hrs
- [ ] [#9](https://github.com/roger6272/trackwise/issues/9) - Auth Flow Integration (parallel: true) - 3-4 hrs
- [ ] [#10](https://github.com/roger6272/trackwise/issues/10) - Items Flow & Navigation Bar (parallel: true) - 6-8 hrs
- [ ] [#11](https://github.com/roger6272/trackwise/issues/11) - Bluetooth Pages (parallel: true) - 6-8 hrs
- [ ] [#12](https://github.com/roger6272/trackwise/issues/12) - Profile & Export Pages (parallel: true) - 4-5 hrs
- [ ] [#13](https://github.com/roger6272/trackwise/issues/13) - Widget Tests (parallel: false) - 6-8 hrs
- [ ] [#14](https://github.com/roger6272/trackwise/issues/14) - FlutterFlow Cleanup (parallel: false) - 2-3 hrs

**Summary:**
- Total tasks: 7
- Parallel tasks: 4 (tasks #9-#12 can run concurrently after #8)
- Sequential tasks: 3 (#8 first, #13-#14 last)
- Estimated total effort: 30-40 hours

**Dependency Graph:**
```
#8 (Foundation)
 ├── #9 (Auth) ───────┐
 ├── #10 (Items) ─────┼── #13 (Tests) ── #14 (Cleanup)
 ├── #11 (Bluetooth) ─┤
 └── #12 (Profile) ───┘
```
