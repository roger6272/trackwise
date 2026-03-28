# Traxelos UX Specification

> Complete reference for every screen, interaction, and user flow in the Traxelos mobile app.

**Last updated:** 2026-03-04

---

## Table of Contents

1. [Design System](#1-design-system)
2. [Navigation Structure](#2-navigation-structure)
3. [Authentication Flow](#3-authentication-flow)
4. [Onboarding](#4-onboarding)
5. [Items List (Home)](#5-items-list-home)
6. [Item Detail](#6-item-detail)
7. [Item Form (Create/Edit)](#7-item-form-createedit)
8. [Bluetooth](#8-bluetooth)
9. [Device Search](#9-device-search)
10. [Profile / Account](#10-profile--account)
11. [Edit Profile](#11-edit-profile)
12. [Data Export (CSV)](#12-data-export-csv)
13. [Recently Deleted](#13-recently-deleted)
14. [Manage Categories](#14-manage-categories)
15. [Help & Support](#15-help--support)
16. [Privacy Policy](#16-privacy-policy)
17. [Global Dialogs](#17-global-dialogs)
18. [State Management Summary](#18-state-management-summary)

---

## 1. Design System

### 1.1 Color Palette

**Brand Colors**

| Token | Hex | Usage |
|-------|-----|-------|
| `primary` | `#4B39EF` | Main brand purple, buttons, links, app bar (light) |
| `primaryLight` | `#8B7FFF` | Purple for dark mode (via `primaryAdaptive()`) |
| `secondary` | `#39D2C0` | Teal accent |
| `tertiary` | `#EE8B60` | Orange accent |

**Semantic Colors**

| Token | Hex | Usage |
|-------|-----|-------|
| `success` | `#249689` | Connected states, success snackbars |
| `warning` | `#F9CF58` | Warning badges (darker `#B8860B` in light mode for readability) |
| `error` | `#FF5963` | Error states, destructive actions, delete |
| `disabled` | `#9E9E9E` | Disconnected device icons |

**Surface Colors**

| | Light | Dark |
|---|---|---|
| Primary background | `#F1F4F8` | `#14181B` |
| Secondary background | `#FFFFFF` | `#1D2428` |
| Alternate (borders/dividers) | `#E0E3E7` | `#262D34` |
| Primary text | `#14181B` | `#FFFFFF` |
| Secondary text | `#57636C` | `#95A1AC` |

**Trend Colors**

| Token | Hex | Usage |
|-------|-----|-------|
| `positive` | `#017400` | Up-trend badge |
| `negative` | `#9F0202` | Down-trend badge |
| `neutral` | `#6B7280` | Flat trend badge |

**Device Colors (10-color palette)**

Assigned to paired BLE devices for visual distinction:
- Light: Blue `#1565C0`, Green `#2E7D32`, Orange `#E65100`, Purple `#6A1B9A`, Red `#C62828`, Teal `#00695C`, Pink `#AD1457`, Amber `#F57F17`, Indigo `#283593`, Brown `#4E342E`
- Dark: Lighter pastel equivalents

### 1.2 Typography

Two font families via Google Fonts:

| Role | Font | Weight | Sizes |
|------|------|--------|-------|
| Headings & titles | Inter Tight | Semi-bold (w600) | 16–64pt |
| Body & labels | Inter | Regular | 12–16pt |

| Text Style | Font | Size | Color |
|------------|------|------|-------|
| `displayLarge` | Inter Tight w600 | 64 | primaryText |
| `displayMedium` | Inter Tight w600 | 44 | primaryText |
| `displaySmall` | Inter Tight w600 | 36 | primaryText |
| `headlineLarge` | Inter Tight w600 | 32 | primaryText |
| `headlineMedium` | Inter Tight w600 | 28 | primaryText |
| `headlineSmall` | Inter Tight w600 | 24 | primaryText |
| `titleLarge` | Inter Tight w600 | 20 | primaryText |
| `titleMedium` | Inter Tight w600 | 18 | primaryText |
| `titleSmall` | Inter Tight w600 | 16 | primaryText |
| `labelLarge` | Inter | 16 | secondaryText |
| `labelMedium` | Inter | 14 | secondaryText |
| `labelSmall` | Inter | 12 | secondaryText |
| `bodyLarge` | Inter | 16 | primaryText |
| `bodyMedium` | Inter | 14 | primaryText |
| `bodySmall` | Inter | 12 | primaryText |

### 1.3 Component Themes

| Component | Key Properties |
|-----------|---------------|
| AppBar | Light: `primary` bg, white fg. Dark: `darkSecondaryBackground` bg. Centered title, no elevation |
| ElevatedButton | `primary` bg, white fg, 8dp radius, h:24 v:12 padding |
| OutlinedButton | `primary` border/text, same radius and padding |
| Cards | Secondary bg, elevation 2, 12dp radius |
| Input fields | Filled, secondary bg, 8dp radius, `primary` 2px focused border |
| Dialogs | Secondary bg, 12dp radius |
| Bottom sheets | Secondary bg, 16dp top radius |
| Snackbars | Floating, 8dp radius. Error: `error` bg. Success: `success` bg |

### 1.4 Spacing Patterns

| Pattern | Value |
|---------|-------|
| Page horizontal padding | 16dp |
| Input content padding | h:16 v:12 |
| Card border radius | 12dp |
| Small radius (inputs, buttons) | 8dp |
| Bottom sheet top radius | 16dp |
| Bottom nav bar radius | 15dp |
| Section gap | 10–12dp |
| Tight gap | 4–8dp |

### 1.5 Loading States

Custom shimmer skeleton system (no third-party package):
- Light shimmer: base `#E0E0E0`, highlight `#F5F5F5`
- Dark shimmer: base `#2A2A2A`, highlight `#3D3D3D`
- 1500ms animation, `easeInOutSine` curve
- Primitives: `ShimmerBox`, `ShimmerText`, `ShimmerCircle`
- Composed into `HeroStatsSkeleton`, `ChartSkeleton`, etc.

### 1.6 Feedback

- Error snackbar: `AppColors.error` background, 4s duration (6s with action)
- Success snackbar: `AppColors.success` background
- Info snackbar: default theme styling
- All snackbars dismiss current before showing new

---

## 2. Navigation Structure

### 2.1 Router (GoRouter)

```
/login                     LoginPage           (no bottom nav)
/signup                    SignupPage           (no bottom nav)
/forgot-password           ForgotPasswordPage   (no bottom nav)
/onboarding                OnboardingPage       (no bottom nav)

[ShellRoute — AppShell with bottom nav]
  /                        ItemsListPage
    /items/form            ItemFormPage
    /items/:id             ItemDetailPage
  /bluetooth               BluetoothPage
    /bluetooth/search      BluetoothSearchPage
    /bluetooth/test        BluetoothTestPage (debug only)
  /profile                 ProfilePage
    /profile/export        ExportPage
    /profile/deleted-items DeletedItemsPage
    /profile/edit          EditProfilePage
    /profile/help          HelpSupportPage
    /profile/categories    ManageCategoriesPage
```

### 2.2 Auth Redirect Logic

| Condition | Redirect |
|-----------|----------|
| Not authenticated | `/login` |
| Authenticated, onboarding incomplete | `/onboarding` |
| Authenticated, onboarding complete | `/` |

### 2.3 Bottom Navigation Bar

Custom floating pill-shaped bar (not standard `BottomNavigationBar`):
- Height: 69dp, 15dp radius, shadow (blur:8, offset:0/-2)
- 3 icon-only tabs (35dp icons):

| Tab | Icon | Adaptive behavior |
|-----|------|-------------------|
| Home | `home_rounded` | Static |
| Bluetooth | `bluetooth` / `bluetooth_searching` / `bluetooth_connected` | Icon and color change with BLE state |
| Account | `person_rounded` | Static |

- Bluetooth tab: connected = `success` green icon; searching = animated icon
- All icons wrapped in `Semantics` for accessibility

---

## 3. Authentication Flow

### 3.1 Login Page (`/login`)

**Layout:** Full-screen diagonal gradient (`primary` → `tertiary`), centered card (max 570dp width)

**Form Fields:**
- Email (email keyboard, autofill)
- Password (obscured, visibility toggle, submits on Enter)

**Actions:**
- **Sign In** — full-width ElevatedButton, shows spinner while loading
- **Google Sign In** — social button (always shown)
- **Apple Sign In** — social button (iOS only)
- **Create Account** — text link → pushes `/signup`
- **Forgot Password** — OutlinedButton → pushes `/forgot-password`

**States:**
- Loading: all buttons disabled, Sign In shows spinner
- Error: error snackbar, password field cleared

### 3.2 Sign Up Page (`/signup`)

Same gradient + card layout as Login.

**Form Fields:**
- Email
- Password (min 6 chars, visibility toggle)
- Confirm Password (must match, submits on Enter)

**Actions:**
- **Create Account** — ElevatedButton
- Google / Apple social sign-up
- **Sign In** — text link → pops back

**Navigation:** On success → `/onboarding`

### 3.3 Forgot Password Page (`/forgot-password`)

**Form:** Email field only

**Actions:**
- **Send Reset Link** — ElevatedButton
- Back arrow (top-left)

**States:**
- Success: "Password reset email sent!" snackbar + auto-pop after 2s
- Error: error snackbar

---

## 4. Onboarding

### OnboardingPage (`/onboarding`)

4-step `PageView` with programmatic navigation only (no swipe).

**Progress indicator:** Animated dots at top (current step = wider filled pill)

**Step 1 — Profile:**
- Name text field (optional)
- Use case selection (radio/chip group)
- "Other" text field if selected
- Referral source selection
- Buttons: "Continue", "Skip for now"

**Step 2 — Product Introduction:**
- Static content explaining the product
- Button: "Continue"

**Step 3 — Device Pairing:**
- BLE scanning/pairing flow inline
- Skip: "I don't have a device yet"
- Back arrow available

**Step 4 — Done:**
- Success confirmation
- Button: "Get Started" → completes onboarding → redirects to `/`

---

## 5. Items List (Home)

### ItemsListPage (`/`)

**App Bar:**
- Title: "Items" (centered)
- Search icon (right)
- Circular "+" add button (primary color, right)

**Body (top to bottom):**

1. **Category filter dropdown** (visible when categories exist)
   - Options: "All", each category name, "Manage Categories"
   - "Manage Categories" navigates to `/profile/categories`

2. **Search field** (conditional, when search active)
   - Debounced text input (300ms) with clear button

3. **Active item chips** (conditional, when BLE connected)
   - One chip per connected device showing currently selected item
   - Tap to release/reassign

4. **Connection/sync banners** (conditional)
   - Disconnected: "Connect Your Device" banner
   - Syncing: "Syncing..." banner

5. **Today/Total toggle divider**
   - Shows "Today" or "Total" label

6. **ReorderableListView** (main content)
   - Items grouped by category with sticky headers (in "All" view)
   - Drag handles for reorder (long-press + drag, haptic feedback)

**Item Tile (per row):**
- `Slidable` with:
  - Swipe left: Activate/Release item on device (when connected)
  - Swipe right: Edit (pencil) and Delete (trash) actions
- Tap: navigate to Item Detail
- Shows: item name, count (today or total), category, device indicator

**Empty States:**
- No items: icon + "Create your first item" + Create button
- No search results: "No items match" message
- Item limit (100): dialog blocks creation

**First-run Hints (shown once):**
- Activation hint: tooltip on how to activate an item
- Reorder hint: animated lift effect on first item

---

## 6. Item Detail

### ItemDetailPage (`/items/:id`)

**App Bar:**
- Back arrow (left)
- Item name title (centered)
- Export icon (right) → pushes `/profile/export` with item preselected

**Body (`CustomScrollView` with pull-to-refresh):**

1. **Cycle Selector** (top-center pill)
   - Shows current cycle name (e.g., "Period 3", "All Time")
   - Tap opens `CycleSelectionBottomSheet`
   - "Updated X ago" timestamp below

2. **Static Header**
   - Circular progress ring (count vs goal)
   - Current count (large number)
   - Initial count, goal, reset number, increment value
   - Reminder configuration
   - Cycle start/end dates

3. **Cycle Note** (hidden for "All Time")
   - Editable text area for per-cycle notes

4. **Activity Section**
   - **Chart card:**
     - Cumulative / incremental toggle
     - Aggregation selector: 1D, 7D, 30D
     - Date picker
     - Period total + % change vs prior period
     - Bar or line chart
   - **Cycle History table:** all cycles with counts, dates, duration
   - **Stats section:** trend, average per day, streak, etc.

**Loading:** Shimmer skeletons for chart and stats

### CycleSelectionBottomSheet

- Lists all cycles: "All Time" + numbered periods
- Each row: cycle name (user-defined or "Period N"), count, date range
- Tap to select → updates detail view
- Long-press or rename button → inline rename

---

## 7. Item Form (Create/Edit)

### ItemFormPage (`/items/form`)

Dual-purpose: create (no item passed) or edit (item passed via route extra).

**App Bar:** "Create Item" or "Edit Item", back arrow

**Form Fields (scrollable):**

| Field | Type | Constraints | Notes |
|-------|------|-------------|-------|
| Item Name | Text | Required, max 30 chars, word caps | Duplicate name check |
| Category | Dropdown | Optional | Lists categories + "Uncategorized" + "Manage Categories" |
| Initial Value | Numeric | 0 to max | Create mode only |
| Goal | Numeric | Optional | |
| Count Per Press | Numeric | 1–1000, default 1 | |
| Reminder | Dropdown | None / At Target / Every X | |
| Reminder Value | Numeric | Conditional (shown if reminder != None) | |

**Buttons (bottom row):**
- "Cancel" OutlinedButton → pop
- "Create" / "Update" ElevatedButton → validate, save, pop

---

## 8. Bluetooth

### BluetoothPage (`/bluetooth`)

**App Bar:** "Bluetooth" title, search icon → `/bluetooth/search` (only when paired devices exist)

**Empty State (no paired devices):**
- Watch icon
- "No devices paired" text + description
- "Find Device" ElevatedButton → `/bluetooth/search`
- "Grant Permissions" OutlinedButton (conditional)

**With Paired Devices:**
- Status banners (BT disabled / permissions missing with "Grant" action)
- Summary bar: "X of Y connected" + status dots
- Device list:

**Device Tile (per device):**
- Leading: colored watch icon (device color) or spinner (connecting)
- Title: device name
- Subtitle: "Connected" (green), "Connecting...", or "Paired [date]" + device ID
- Trailing: battery indicator + three-dot menu
- Connected tile: green-tinted background + border
- Tap disconnected tile: connects

**Three-dot Menu:**
- Connect (disabled at 5-device limit)
- Disconnect
- Rename → form dialog (max 32 chars)
- Change Color → color picker dialog (10 options)
- Unpair → confirmation dialog ("Hold B button for 10 seconds")

---

## 9. Device Search

### BluetoothSearchPage (`/bluetooth/search`)

**App Bar:** "Find Device", back arrow

**Body:**
- Status banner (permissions / BT state)
- "Scan for Devices" / "Scanning..." button (full width, blinking icon while active)
- Auto-starts scan on page open if ready

**Scan Results:**
- Scanning: spinner + "Searching for devices..." + found count
- Empty (post-scan): BT icon + "No new devices found"
- Devices found: list sorted by signal strength (strongest first)
  - Each tile: device name, RSSI indicator, tap to connect
  - Disabled when at 5-device limit

**Navigation:** On new device connecting → navigates to `/` (home)

---

## 10. Profile / Account

### ProfilePage (`/profile`)

**App Bar:** "Account" (centered)

**Body (scrollable sections):**

1. **Profile Header:** Display name + email

2. **Appearance:** Dark Mode toggle switch

3. **Account Settings:**
   - Edit Profile → `/profile/edit`
   - Privacy & Security → Privacy Policy page

4. **Data Management:**
   - Manage Categories → `/profile/categories`
   - Paired Devices → `/bluetooth`
   - Start New Cycle → confirmation dialog
   - Export My Data → `/profile/export`
   - Recently Deleted → `/profile/deleted-items`

5. **Support:**
   - Help & Support → `/profile/help`

6. **Log Out** — ElevatedButton (error color with border)

7. **Danger Zone:** "Delete Account" card (error border)

8. **App version** (bottom, faded)

**Start New Cycle Dialog:**
- Lists what will happen (reset all counts, increment cycle number)
- Blocked if any paired device is disconnected (shows "Devices Disconnected" dialog)
- On confirm: resets all items, syncs devices if connected

**Delete Account (two-step):**
1. Warning dialog: lists data to be deleted + device warning
2. Final confirmation: "Type DELETE" text field required
- If session expired: reauthentication dialog with "Sign In & Delete"

**Sign Out:**
- Confirmation dialog → disconnects all BLE devices → signs out → redirects to `/login`

---

## 11. Edit Profile

### EditProfilePage (`/profile/edit`)

**App Bar:** "Edit Profile", back arrow, "Save" text button (primary when changes exist)

**Fields:**
- Display Name (editable text field)
- Email (read-only, styled container with "Email cannot be changed" note)

**Behavior:** Save disabled until changes detected; spinner replaces "Save" while saving; auto-pops on success

---

## 12. Data Export (CSV)

### ExportPage (`/profile/export`)

**App Bar:** "Export Data", back arrow

**Form (scrollable):**
- Item selection checkboxes (pre-selected if navigated from Item Detail)
- Date range: start + end date pickers
- Aggregation level dropdown (hourly, daily, weekly, monthly)
- Latest cycle only toggle
- Email address field
- "Send Export" button

**States:** Initial → In Progress (spinner) → Success (snackbar) / Error (snackbar)

---

## 13. Recently Deleted

### DeletedItemsPage (`/profile/deleted-items`)

**App Bar:** "Recently Deleted", back arrow

**Header:** "X items will be permanently deleted after 30 days"

**When BLE disconnected:** "Connect to restore items" chip (tappable → `/bluetooth`)

**Item Cards:**
- Item name
- "Deleted [date]" (relative)
- "X days remaining" (red + bold if ≤ 7 days)
- "Restore" button (80dp, disabled when not connected, spinner while restoring)

**Empty State:** Delete icon + "No Deleted Items" + explanation text

---

## 14. Manage Categories

### ManageCategoriesPage (`/profile/categories`)

**App Bar:** "Manage Categories", back arrow, "+" add icon

**Hint text:** "Drag to reorder categories. Tap to edit."

**Category List (ReorderableListView):**
- Drag handle + category name per row
- Tap → edit dialog
- Delete icon → confirmation ("Items will become uncategorized")

**"Uncategorized" info box** at bottom

**CategoryFormDialog (create/edit):** Text field with character counter, duplicate name validation

**Empty State:** Category icon + "No categories yet" + "Create Category" button

---

## 15. Help & Support

### HelpSupportPage (`/profile/help`)

**App Bar:** "Help & Support", back arrow

**Quick Tips:** Expandable FAQ (radio-style, one open at a time):
1. How do I connect my device?
2. How do I add a new item to track?
3. How do I reset my count?
4. How do I export my data?
5. What happens to deleted items?
6. How do I reorder my items?

**Contact Support:** Support icon + description + "Email Support" button (mailto link)

**Footer:** App name + version

---

## 16. Privacy Policy

### PrivacyPolicyPage

**App Bar:** "Privacy Policy", back arrow

**Body:** Markdown rendered from `assets/privacy_policy.md`

**States:** Loading (spinner), Error (message), Empty ("Privacy policy not available")

---

## 17. Global Dialogs

These appear over any screen, triggered by BLE state changes from `main.dart`.

### DeviceSetupDialog
- **Trigger:** New/factory-reset device detected (status: `uninitialized`)
- **Title:** "New Device Detected"
- **Content:** Pairing explanation
- **Actions:** "Cancel" (disconnects) | "Set Up" (triggers pairing)
- Non-dismissible (`barrierDismissible: false`)

### StaleClaimDialog
- **Trigger:** Device reconnects with items released while offline (status: `staleClaim`)
- **Title:** "Items Released"
- **Content:** Device name + list of released items + warning about unsynced counts
- **Actions:** "Keep Offline" | "Sync Now"
- Non-dismissible

### WrongAccountDialog
- **Trigger:** Device paired to a different user account (status: `wrongAccount`)
- **Title:** "Wrong Account"
- **Content:** Instructions to factory reset
- **Actions:** "OK" (dismisses and disconnects)
- Non-dismissible

### DeviceSelectorSheet (Bottom Sheet)
- **Trigger:** Multiple devices connected, user needs to assign item to specific device
- **Title:** "Select Device" with drag handle
- **Content:** List of connected devices (colored watch icon + name)
- Tap to select

---

## 18. State Management Summary

### BLoCs

| BLoC | Scope | Key States |
|------|-------|------------|
| AuthBloc | Global (main.dart) | Initial → Loading → Authenticated / Unauthenticated / Error |
| ItemsBloc | Provided in ShellRoute | Initial → Loading → Loaded(items, categoryFilter) / Error |
| DeletedItemsBloc | Provided per page | Initial → Loading → Loaded → Restoring → Restored / Error |
| CategoriesBloc | Provided in ShellRoute | Initial → Loading → Loaded(categories) / Error |
| BluetoothBloc | Global singleton | Status: initial → checkingPermissions → ready → scanning/connecting. Per-device: handshaking → syncing → synced/staleClaim/wrongAccount/setup |
| EventsBloc | Provided per page | Initial → Loading → Loaded(events, dateRange) / Error |
| ChartsBloc | Provided per page | Initial → Loading → Loaded(chartData, chartType) / Error |
| ExportBloc | Provided per page | Initial → InProgress → Success / Error |
| ProfileBloc | Global (main.dart) | Initial → Loading → Loaded / Updated / DataExported / AccountDeleting → AccountDeleted / Error |

### Persistent UI State (AppUiState)

| Field | Persisted | Purpose |
|-------|-----------|---------|
| `activeItemId` | SharedPrefs | Currently claimed item ID |
| `selectedCategoryId` | Memory | Current category filter |
| `isTodayToggle` | Memory | Today vs total count display |
| `hasShownReorderHint` | SharedPrefs | First-run reorder tutorial |
| `hasShownActivationHint` | SharedPrefs | First-run activate tutorial |

### Theme Persistence

Theme mode stored in SharedPreferences as bool. Defaults to `ThemeMode.system`.

---

## Appendix: Navigation Graph

```
/login
  ├── push → /signup
  ├── push → /forgot-password
  └── on auth → / or /onboarding

/onboarding
  └── on complete → /

/ (ItemsListPage)
  ├── push → /items/form (create)
  ├── push → /items/:id (ItemDetailPage)
  │            └── push → /profile/export (preselected)
  └── dropdown → /profile/categories

/bluetooth
  └── push → /bluetooth/search
               └── on connect → /

/profile
  ├── push → /profile/edit
  ├── push → /profile/export
  ├── push → /profile/deleted-items
  ├── push → /profile/help
  ├── push → /profile/categories
  ├── go   → /bluetooth (Paired Devices)
  └── push → PrivacyPolicyPage (MaterialPageRoute)

/items/form
  └── popup → /profile/categories (then returns)
```
