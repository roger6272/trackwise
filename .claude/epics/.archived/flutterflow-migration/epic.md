---
name: flutterflow-migration
status: in-progress
created: 2026-01-14T07:54:52Z
updated: 2026-01-14T17:00:00Z
progress: 40%
prd: .claude/prds/flutterflow-migration.md
github: https://github.com/roger6272/trackwise/issues/1
---

# Epic: FlutterFlow Migration

## Overview

Incrementally migrate Trackwise from FlutterFlow-generated code to clean Flutter architecture using a **strangler fig** pattern with **feature flags**. Each component is toggled independently, keeping FF as fallback until new implementation is verified.

## Source of Truth

**PRD**: `.claude/prds/flutterflow-migration.md`

All tasks must align with the PRD. If tasks contradict the PRD, the PRD wins.

## Feature Flags

Located at `lib/core/config/migration_flags.dart`:

```dart
class MigrationFlags {
  static const useNewTheme = false;       // Phase 1
  static const useNewRouter = false;      // Phase 1
  static const useNewProfilePage = false; // Phase 2
  static const useNewAuthPages = false;   // Phase 2
  static const useNewMainPage = false;    // Phase 2
}
```

## Current State (2026-01-14)

### What Exists
| Component | Location | Status |
|-----------|----------|--------|
| MigrationFlags | `core/config/migration_flags.dart` | ✅ Created |
| AppRouter | `core/router/app_router.dart` | ✅ Exists (not enabled) |
| AppTheme | `core/theme/app_theme.dart` | ✅ Exists (not enabled) |
| Clean Auth Pages | `features/auth/presentation/pages/` | ⚠️ Exist but need BLoCs |
| Clean Items Pages | `features/items/presentation/pages/` | ⚠️ Exist but need auth handling |
| Clean Profile Page | `features/profile/presentation/pages/` | ⚠️ Exists but needs BLoCs |
| AppShell | `core/widgets/app_shell.dart` | ✅ Exists |

### What's Missing
| Component | Issue |
|-----------|-------|
| ProfileBloc provider | Not provided in main.dart |
| AuthBloc provider | Not provided in main.dart |
| Auth timing in ItemsListPage | Needs proper wait for currentUserUid |
| Feature flag integration | Router uses flag, pages don't yet |

## Task Breakdown (Aligned with PRD)

### Phase 1: Foundation (Wrap FF, don't replace)

- [x] **Task 1: Create MigrationFlags** ✅
  - Created `lib/core/config/migration_flags.dart`
  - All flags default to `false`

- [x] **Task 2: Wire flag into main.dart** ✅
  - Router selection uses `MigrationFlags.useNewRouter`
  - When false: uses FF `createRouter()`
  - When true: uses `AppRouter.createRouter()`

- [x] **Task 3: Add missing BLoC providers** ✅
  - Added `ProfileBloc` to main.dart MultiProvider
  - Added `AuthBloc` to main.dart MultiProvider
  - All flags remain `false` - providers now available for clean arch pages

### Phase 2: Page Migration (One at a time)

- [x] **Task 4: Enable Profile Page** ✅
  - ProfilePage works with provided BLoCs
  - Tested via FF router - no errors
  - Ready for flag enablement when needed

- [ ] **Task 5: Enable Auth Pages**
  - Test auth pages via FF router
  - Verify login/signup/forgot-password flows work
  - Once working, consider enabling `useNewAuthPages` flag

- [ ] **Task 6: Enable Main/Items Page**
  - Fix ItemsListPage auth timing issue
  - Test via FF router navigation to `/items`
  - This is the most complex - do last
  - Once working, consider enabling `useNewMainPage` flag

- [ ] **Task 7: Enable New Router**
  - Only after all pages work via FF router
  - Set `useNewRouter = true`
  - Test complete app flow

### Phase 3: Cleanup

- [ ] **Task 8: Remove FF Code**
  - Only after all flags are `true` and stable
  - Delete `flutter_flow/`, `components/`, `account_profile_creation/`
  - Remove FF imports from all files

## Implementation Strategy

### Key Principle: Test Before Enabling

For each page:
1. **Keep flag `false`** (use FF implementation)
2. **Fix any issues** in clean arch page
3. **Test via direct navigation** (FF router can still route to clean arch pages)
4. **Verify it works** completely
5. **Then enable flag** to make it the default

### Rollback Strategy

If any flag causes issues:
1. Set flag back to `false`
2. App immediately uses FF implementation
3. Fix the issue
4. Re-enable when ready

## Success Criteria

| Criteria | Verification |
|----------|--------------|
| Each flag can be toggled independently | Change one flag, app still works |
| FF fallback works | Set all flags false, app works |
| Clean arch works | Set all flags true, app works |
| Visual parity | Screenshots match FF exactly |
| All flows work | Auth, items CRUD, bluetooth, profile |

## Lessons Learned

### What Went Wrong (2026-01-14)
- Attempted "big bang" switch without feature flags
- Tasks didn't align with PRD's gradual approach
- Missing BLoC providers caused runtime errors
- Auth timing issues broke ItemsListPage

### What We Fixed
- Created MigrationFlags class
- Updated CLAUDE.md with PRD verification rules
- Wired feature flag into main.dart router selection
- Reset to FF router (all flags false) for stability

## Next Action

**Task 5: Enable Auth Pages** - Test clean arch auth pages (Login, Signup, Forgot Password) via FF router. Verify the flows work correctly with AuthBloc.
