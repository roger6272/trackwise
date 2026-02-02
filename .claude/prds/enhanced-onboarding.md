---
name: enhanced-onboarding
description: Replace single-form onboarding with guided flow including product intro, device pairing, and first item creation
status: backlog
created: 2026-02-02T01:16:39Z
---

# PRD: Enhanced Onboarding

## Executive Summary

Replace the current single-screen data-collection form with a multi-step onboarding wizard that collects user preferences, introduces the product, guides users through their first device pairing, and helps them create their first item. The goal is to get users to a fully working state — paired device with at least one item — before they reach the home screen.

## Problem Statement

### What Problem Are We Solving?

The current onboarding is a marketing data form (name, use case, referral source) that does nothing to help users succeed. After completing it, users land on an empty home screen with no devices, no items, and a disabled "Create Item" button. The most critical steps — BLE device pairing and first item creation — have zero guidance, and users must discover them on their own.

Without at least one item, a paired device sits on a blank screen with nothing to count. Without pairing, nothing in the app works. Both steps are mandatory for the product to deliver value, yet neither is part of onboarding today.

### Why Is This Important Now?

- A hardware-dependent app that doesn't help users pair on first launch will lose most users immediately
- Multi-device enablement (in progress) adds pairing complexity, making guided setup more important
- The current onboarding was a placeholder; the product is past MVP stage

## User Stories

### New User with Device in Hand

- As a new user who just unboxed my Traxelos One, I want the app to walk me through pairing and creating my first item so I can start counting immediately
  - **Acceptance:** User completes onboarding with a connected device and at least one item ready to count

- As a new user, I want to understand what the app does before I start setting things up
  - **Acceptance:** Single intro screen explains the product and what's needed

### New User without Device

- As a user who found the app before buying hardware, I want to understand what Traxelos One is and what I need
  - **Acceptance:** Intro screen makes it clear a physical device is required

- As a user without a device, I want to skip pairing and explore the app
  - **Acceptance:** Skip option available at pairing step; user reaches home screen with guidance to pair later

### Returning User (Incomplete Onboarding)

- As a user who previously skipped onboarding, I should not be forced through it again
  - **Acceptance:** `onboarding_completed` is set to true even when skipping; pairing prompt appears on home screen instead

## Requirements

### Functional Requirements

#### Onboarding Flow (5 Steps)

**Step 1: User Profile & Preferences (existing — keep current position)**
- Name field (optional)
- Primary use case selection (required): Inventory, Habit, Fitness, Manufacturing, Other
- Referral source (optional): Friend, Social Media, Search, App Store, Other
- "Continue" button (validates use case selected)
- "Skip for now" link (sets use case to "skipped", advances to Step 2)

**Step 2: Product Introduction (new)**
- Single screen explaining:
  - What Traxelos One is (physical counter device + companion app)
  - What you need (a Traxelos One device with Bluetooth)
  - What you'll do next (pair your device and create your first item)
- Illustration or icon showing device + phone
- "Continue" button advances to Step 3
- No skip needed — informational only

**Step 3: Device Scan & Connect (new — reuses existing BLE logic)**
- On entry: request Bluetooth and location permissions if not already granted (inline, same as existing `BluetoothSearchPage` behavior)
- If Bluetooth adapter is off: show "Turn on Bluetooth" prompt with system toggle
- If permissions denied: show explanation and "Open Settings" option; user can retry or skip
- Once permissions granted and Bluetooth on: auto-start BLE scan
- Show discovered Traxelos devices with signal strength
- User taps device to connect
- Show connection progress (scanning → connecting → paired)
- Handle connection failures with retry and troubleshooting tips:
  - "Make sure your device is powered on and nearby"
  - "Try turning Bluetooth off and on"
- On successful connection: execute handshake protocol automatically
- Handle handshake responses:
  - `uninitialized`: proceed to Step 4 (expected for new devices)
  - `in_sync`: proceed to Step 4 (device already paired, may need first item)
  - `wrong_account`: show error with factory reset instructions
  - `conflict`: show conflict resolution dialog
- "Skip" option available — marks onboarding complete, goes to home
- "I don't have a device yet" link — marks onboarding complete, goes to home

**Step 4: Create First Item (new)**
- Simplified item creation form (subset of full form):
  - Item name (required) — e.g., "Push-ups", "Inventory Count"
  - Pre-filled suggestions based on use case selected in Step 1:
    - Inventory → "Stock Count"
    - Habit → "Water Intake"
    - Fitness → "Push-ups"
    - Manufacturing → "Units Produced"
  - Goal (optional)
  - Count per press (default: 1)
- "Create" button syncs item to device and activates it
- "Skip" option — marks onboarding complete, goes to home with no items
- If device not connected (user skipped Step 3): skip this step entirely, mark onboarding complete, go to home

**Step 5: Done (new — conditional)**
- Only shown when both device pairing (Step 3) and item creation (Step 4) completed
- If either was skipped: go straight to home instead of showing this step
- Success confirmation screen:
  - Show device name and item name
  - Device display now shows the item name and count (0)
  - "Get Started" button — marks onboarding complete, navigates to home

#### Post-Onboarding Empty State (enhancement)

- If user skipped pairing: home screen shows a "Connect Your Device" card above the existing empty state
  - Brief text + "Connect Now" button → navigates to Bluetooth scan
  - Dismissible; persists until first successful device connection
- If user paired but skipped item creation: home screen shows "Create Your First Item" prompt (existing empty state is sufficient)

#### Progress Indicator

- Step dots or progress bar visible on all steps (1–5)
- Back navigation available on Steps 2–4 (not Step 1 — it's the entry point)
- Back preserves previously entered data

#### Data & State

- `onboarding_completed` set to `true` on any completion path (including skip at any step)
- New Firestore field: `onboarding_device_paired: bool` — tracks whether user paired during onboarding
- New Firestore field: `onboarding_item_created: bool` — tracks whether user created an item during onboarding
- Existing fields preserved: `primary_use_case`, `referral_source`, `display_name`

### Non-Functional Requirements

- **Performance:** BLE scan should start within 1 second of permissions being granted
- **Responsiveness:** All steps must work on screen sizes 320dp through tablet
- **Offline tolerance:** Steps 1–2 work offline; Step 3 requires Bluetooth but not internet; Step 4 requires both Bluetooth (device sync) and internet (Firestore)
- **Animation:** Smooth page transitions between steps (horizontal slide)
- **Accessibility:** All steps must have proper Semantics labels; focus order must be logical; touch targets at least 48dp

## Success Criteria

1. Increase in users who reach home screen with a connected device and at least one item
2. Onboarding completion rate (all steps including pairing and item creation) >= 50%
3. Onboarding skip rate trackable per step via Firestore fields
4. Reduction in users who reach the empty home screen with no device and no items

## Constraints & Assumptions

### Constraints

| Constraint | Reason |
|---|---|
| BLE pairing requires physical device nearby | Cannot simulate or demo without hardware |
| Android/iOS permission flows differ | Must handle platform-specific permission dialogs |
| Existing `completeOnboarding()` API must remain compatible | Other code depends on current Firestore fields |
| Item creation requires both BLE connection and internet | Device needs the item synced; Firestore needs the record |

### Assumptions

- Most first-time users will have their Traxelos One device nearby when first opening the app
- Most first-time users have not previously granted Bluetooth permissions
- The existing BLE scan and connection logic is stable enough to embed in onboarding
- A simplified item creation form (name + optional goal) is sufficient for first item

## Out of Scope

- Firmware update checks during onboarding
- Account linking or multi-account support
- Animated tutorials or video content
- A/B testing different onboarding flows
- Re-onboarding for existing users who already completed the current flow
- Changes to signup/login screens
- Full item creation form (categories, reminders, etc.) — keep it simple for onboarding

## Dependencies

- **Existing BLE infrastructure:** `BluetoothSearchPage` scan/permission logic, `BleConnectionService`, handshake protocol
- **Multi-device enablement PRD:** Handshake protocol and pairing flow defined there; onboarding must align
- **Firebase Auth:** Display name update on Step 1
- **Firestore:** User document updates for onboarding fields and item creation

## Implementation Notes

### Files Likely Affected

| Area | Files |
|---|---|
| Onboarding UI | `lib/features/auth/presentation/pages/onboarding_page.dart` (major rewrite) |
| New step widgets | New widget files for Steps 2–5 (or single page with PageView) |
| Router | `lib/core/router/app_router.dart` (onboarding route may need sub-routes) |
| User model | `lib/features/auth/data/models/user_model.dart` (add tracking fields) |
| User entity | `lib/features/auth/domain/entities/user.dart` (add fields) |
| Repository | `lib/features/auth/data/repositories/user_repository_impl.dart` (update `completeOnboarding`) |
| Home empty state | `lib/features/items/presentation/pages/items_list_page.dart` (add connect card) |
| BLE reuse | `lib/features/bluetooth/` (import scan/connect/permission logic, don't duplicate) |

### Design Approach

- Single `OnboardingPage` with a `PageView` managing steps internally, not separate routes per step
- Reuse BLE scan/connect/permission widgets from `bluetooth/` feature — extract into shared components if needed
- Keep onboarding self-contained in `features/auth/` since it's part of the auth flow
- Item creation in Step 4 should call the same use case as the full item form, just with fewer fields

### Test Scenarios

- Complete full flow: profile → intro → scan → pair → create item → done → home
- Skip at Step 1 → verify use case = "skipped", still see intro
- Skip at Step 3 (pairing) → onboarding complete, home shows connect card, Step 4 skipped
- Skip at Step 4 (item creation) → device paired but no items, home shows empty state, Step 5 skipped (go straight to home)
- Complete Steps 3–4 → Step 5 (Done) shown with device and item info
- Device already paired (returning user, incomplete onboarding) → handshake returns `in_sync` → proceed to item creation
- Wrong account device → error shown, user can go back or skip
- Bluetooth off → prompt to enable, can retry or skip
- Permissions denied → explanation shown, "Open Settings" option, can retry or skip
- Connection failure → retry option works, troubleshooting tips shown
- Back navigation through all steps preserves form state
- Use case suggestion in Step 4 matches Step 1 selection
