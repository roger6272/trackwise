---
name: enhanced-onboarding
status: backlog
created: 2026-02-02T01:27:08Z
progress: 0%
prd: .claude/prds/enhanced-onboarding.md
github: [Will be updated when synced to GitHub]
---

# Epic: Enhanced Onboarding

## Overview

Replace the single-screen onboarding form with a 5-step PageView wizard that reuses existing BLE scan/connect and item creation infrastructure. The current `OnboardingPage` becomes a multi-step coordinator managing: user profile → product intro → device pairing → first item creation → done. No new BLoC needed — the page stays as a StatefulWidget with direct repository calls, delegating BLE operations to the existing `BluetoothBloc`.

## Architecture Decisions

- **PageView over sub-routes:** Use a single `OnboardingPage` with `PageView` and `PageController` instead of GoRouter sub-routes. Simpler state management, preserves form data across steps without serialization, and avoids router complexity. The `/onboarding` route stays as-is.
- **Reuse, don't rebuild:** Extract scan/connect widgets from `BluetoothSearchPage` into shared components. Reuse `ItemFormPage` validation logic. No new BLoC — the existing `BluetoothBloc` handles all BLE operations.
- **StatefulWidget pattern:** Keep the current direct-repository-call approach. Onboarding is a one-time flow that doesn't benefit from BLoC overhead. Local state tracks current step, form values, and pairing/creation results.
- **Firestore merge writes:** Add new tracking fields (`onboarding_device_paired`, `onboarding_item_created`) via the existing `completeOnboarding()` method using `SetOptions(merge: true)`.

## Technical Approach

### Frontend Components

**Modified:**
- `onboarding_page.dart` — Major rewrite: PageView with 5 step widgets, progress indicator, back navigation, skip handling
- `items_list_page.dart` — Add "Connect Your Device" card to empty state when no device has been paired

**New step widgets (inside onboarding page or as private widgets):**
- Step 1: Existing profile/preferences form (refactored from current page)
- Step 2: Product intro (static content, illustration)
- Step 3: Device scan/connect (reuses extracted BLE widgets + BluetoothBloc)
- Step 4: Simplified item creation (name, goal, count-per-press)
- Step 5: Done screen (conditional — only if Steps 3+4 both completed)

**Extracted from `BluetoothSearchPage` for reuse:**
- Permission/Bluetooth status banner widget
- Device list tile widget
- Scan button with animation

### Data Model Changes

**User entity + model:** Add two fields:
- `onboarding_device_paired: bool` (default: false)
- `onboarding_item_created: bool` (default: false)

**Repository:** Extend `completeOnboarding()` signature to accept the new tracking fields.

**Firestore:** Two new fields on user document, written on onboarding completion.

### State Management

- `PageController` manages step transitions
- Local `_currentStep` int for progress indicator
- Form data stored in local state variables (name, useCase, referralSource)
- BLE state observed via `BlocListener<BluetoothBloc>` for connection/handshake results
- Item creation via direct `ItemRepository.createItem()` call (same as existing form)

## Implementation Strategy

### Development Phases

1. **Extract reusable BLE widgets** from `BluetoothSearchPage` — enables Step 3 without duplication
2. **Update data model and repository** — new tracking fields needed by all subsequent work
3. **Build PageView skeleton** with step navigation, progress dots, back/skip — the framework all steps plug into
4. **Implement each step** sequentially (1→5), testing each in isolation
5. **Add post-onboarding empty state** card on home page
6. **Update documentation**

### Risk Mitigation

- BLE scan/connect is the riskiest step — reusing existing `BluetoothBloc` events (`StartScan`, `ConnectToDevice`) avoids reimplementing connection logic
- Handshake results already handled by `BluetoothBloc._performInitialSync()` — onboarding just listens for outcomes
- If BLE fails during onboarding, skip option always available — no dead ends

### Testing Approach

- Unit tests for updated `completeOnboarding()` with new fields
- Widget tests for each step in isolation (mock BluetoothBloc for Step 3)
- Integration test for full happy path: profile → intro → pair → create → done
- Manual test: skip at each step, verify correct home screen state

## Task Breakdown

- [ ] **Task 1: Extract reusable BLE widgets from BluetoothSearchPage** — Pull permission banner, device list tile, and scan button into shared widgets under `bluetooth/presentation/widgets/` (feature-scoped, not `core/` — only onboarding and search page use them). Update `BluetoothSearchPage` to use the extracted widgets (no behavior change).
- [ ] **Task 2: Add onboarding tracking fields to User entity/model/repository** — Add `onboardingDevicePaired` and `onboardingItemCreated` to User entity, UserModel (Firestore serialization), and extend `completeOnboarding()` to accept and write them.
- [ ] **Task 3: Build onboarding PageView skeleton with navigation** — Rewrite `OnboardingPage` as a PageView with 5 steps, progress dots, back button, and skip handling. Each step is a placeholder widget initially. Wire up `completeOnboarding()` on any exit path (skip or completion), including `authStateNotifier.updateAuthState(onboardingCompleted: true)` to trigger the router redirect to home. *Depends on: Task 2.*
- [ ] **Task 4: Implement Step 1 (User Profile) and Step 2 (Product Intro)** — Migrate existing profile form into Step 1 widget. Build Step 2 as a static intro screen with product description and illustration. *Depends on: Task 3.*
- [ ] **Task 5: Implement Step 3 (Device Scan & Connect)** — Build scan/connect step using extracted BLE widgets and BluetoothBloc. Handle permissions inline, Bluetooth-off state, device list, connection progress, and all handshake outcomes. Include skip and "I don't have a device yet" options. *Depends on: Tasks 1, 3.*
- [ ] **Task 6: Implement Step 4 (Create First Item) and Step 5 (Done)** — Build simplified item form (name + goal + count-per-press) with use-case-based suggestions. Build conditional Done screen. Wire item creation through existing `ItemRepository.createItem()` and device sync. *Depends on: Task 3.*
- [ ] **Task 7: Add post-onboarding "Connect Your Device" card to home empty state** — Show dismissible connect card in `items_list_page.dart` when the user has no paired devices in Firestore (check via existing paired devices data, not the onboarding tracking field — more reliable and works for users who skip onboarding entirely). Card links to Bluetooth scan page. Disappears after first successful device connection.
- [ ] **Task 8: Update documentation** — Update `docs/USER_GUIDE.md` Section 2.3 (Complete Onboarding) to reflect the new multi-step flow. Verify no other docs reference the old onboarding form.

## Dependencies

- **Multi-device enablement:** Handshake protocol must be implemented before Step 3 can work. The epic on branch `epic/multi-device-enablement` covers this — onboarding should be built after or alongside it.
- **Existing BLE infrastructure:** `BluetoothBloc`, `BluetoothSearchPage`, connection/handshake flow must be stable.
- **Item creation:** `ItemRepository.createItem()` and device sync must work correctly.

## Success Criteria (Technical)

- All 5 steps render correctly and transitions are smooth
- Skip at any step marks `onboarding_completed = true` and routes to home
- Full happy path: user ends on home with connected device + 1 item visible
- No regressions: existing users with `onboarding_completed = true` are unaffected
- New Firestore fields populated correctly for analytics
- BLE errors during onboarding don't block the user (skip always available)
