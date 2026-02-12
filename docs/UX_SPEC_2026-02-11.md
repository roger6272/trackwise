# Traxelos UX Specification

> Generated from codebase on 2026-02-11 using `docs/UX_SPEC_TEMPLATE.md`.

## 1. App Overview

Traxelos is an Android/iOS Flutter app that pairs with a physical ESP32 Bluetooth counting device. Users track counts for multiple items via button presses on the device, with data syncing to the app over BLE. The app provides item management, analytics charts, cycle-based history, category organization, goal tracking, and CSV data export. It uses Firebase for authentication and cloud backup.

---

## 2. Navigation Map

### Tab Structure

| Tab | Index | Icon | Label | Root Route |
|-----|-------|------|-------|------------|
| Home | 0 | `home_rounded` | "Home" | `/` |
| Bluetooth | 1 | `bluetooth_connected` | "Bluetooth" | `/bluetooth` |
| Account | 2 | `person_rounded` | "Account" | `/profile` |

### Route Hierarchy

```
(Auth — no bottom nav)
/login                    LoginPage
/signup                   SignupPage
/forgot-password          ForgotPasswordPage
/onboarding               OnboardingPage (4-step wizard)

(Main app — bottom nav shell)
/                         ItemsListPage
  /items/form             ItemFormPage (create/edit)
  /items/:id              ItemDetailPage
/bluetooth                BluetoothPage
  /bluetooth/search       BluetoothSearchPage
  /bluetooth/test         BluetoothTestPage (temporary, dev-only)
/profile                  ProfilePage
  /profile/edit           EditProfilePage
  /profile/export         ExportPage
  /profile/deleted-items  DeletedItemsPage
  /profile/help           HelpSupportPage
  /profile/categories     ManageCategoriesPage
  /profile/paired-devices PairedDevicesPage
  (modal push)            PrivacyPolicyPage
```

### Modals and Bottom Sheets (not full pages)

- CycleSelectionBottomSheet — select/rename reset cycles (from ItemDetailPage)
- Date picker bottom sheet — calendar date selection (from ItemDetailPage, ExportPage)
- Item picker bottom sheet — multi-select items (from ExportPage)
- CategoryFormDialog — create/edit category (from ManageCategoriesPage)
- DeviceSetupDialog — pair new device (global, from main.dart)
- SyncConflictDialog — resolve sync mismatch (global, from main.dart)
- WrongAccountDialog — device paired to different account (global, from main.dart)

---

## 3. Per-Screen Specification

---

### LoginPage `/login`

**Purpose:** Sign in with email/password or social providers.

**Entry points:** Auto-redirect when not authenticated; "Sign in here" link from SignupPage.

**Layout:**
- Gradient background (primary to tertiary, diagonal)
- "Traxelos" logo text (white, headlineLarge)
- White card (max 570px, rounded 12px, shadow):
  - Title: "Welcome Back"
  - Subtitle: "Fill out the information below in order to access your account."
  - Email text field
  - Password text field (obscured, visibility toggle)
  - "Sign In" button (full-width, primary)
  - Divider: "Or sign in with"
  - "Continue with Google" button (always shown)
  - "Continue with Apple" button (iOS only)
  - "Don't have an account? **Create Account**" link
  - "Forgot password?" button (outlined, full-width)

**Interactive elements:**

| Element | Action |
|---------|--------|
| Email field | Text input, keyboard next to password |
| Password field | Text input, keyboard done submits form |
| Visibility toggle (eye icon) | Show/hide password |
| "Sign In" button | Validate form, sign in with email/password |
| "Continue with Google" | Sign in with Google |
| "Continue with Apple" | Sign in with Apple (iOS only) |
| "Create Account" link | Navigate to `/signup` |
| "Forgot password?" button | Navigate to `/forgot-password` |

**States:**
- **Default:** Form editable, button enabled
- **Loading:** Button shows white spinner (20x20), all inputs disabled
- **Error:** SnackBar with error message, password field cleared

**Validation:**
- Email: required, must match email format
- Password: required

---

### SignupPage `/signup`

**Purpose:** Create a new account with email/password or social providers.

**Entry points:** "Create Account" link from LoginPage.

**Layout:**
- Same gradient background and card style as LoginPage
- Title: "Get Started"
- Subtitle: "Create an account by using the form below."
- Email field, Password field, Confirm Password field
- "Create Account" button (full-width, primary)
- Divider: "Or sign up with"
- Google/Apple social buttons
- "Already have an account? **Sign in here**" link

**Interactive elements:**

| Element | Action |
|---------|--------|
| Email field | Text input, next to password |
| Password field | Text input, next to confirm password |
| Confirm Password field | Text input, done submits form |
| "Create Account" button | Validate form, create account |
| Social buttons | Sign in with Google/Apple |
| "Sign in here" link | Pop back to LoginPage |

**States:**
- **Default:** Form editable
- **Loading:** Button shows spinner, all disabled
- **Error:** SnackBar with error, both password fields cleared
- **Success:** Navigate to `/onboarding`

**Validation:**
- Email: required, valid email format
- Password: required, minimum 6 characters
- Confirm Password: required, must match password

---

### ForgotPasswordPage `/forgot-password`

**Purpose:** Send a password reset email.

**Entry points:** "Forgot password?" from LoginPage.

**Layout:**
- Same gradient background and card style
- Back button (arrow icon, top-left of card)
- Title: "Forgot Password"
- Subtitle: "Please fill out your email below in order to receive a reset password link."
- Email field
- "Send Reset Link" button (full-width, primary)

**Interactive elements:**

| Element | Action |
|---------|--------|
| Back button | Pop to LoginPage |
| Email field | Text input, done submits |
| "Send Reset Link" button | Validate, send reset email |

**States:**
- **Default:** Form editable
- **Loading:** Button shows spinner
- **Error:** SnackBar with error message
- **Success:** SnackBar "Password reset email sent! Check your inbox.", auto-navigates back after 2 seconds

**Validation:**
- Email: required, valid email format

---

### OnboardingPage `/onboarding`

**Purpose:** 4-step wizard for new users: profile setup, product intro, device pairing, completion.

**Entry points:** Auto-redirect after signup or social sign-in when onboarding not completed.

**Layout:**
- Top bar: back button (steps 2-3 only), progress dots (4 dots, active dot wider and primary-colored)
- PageView (non-scrollable, controlled programmatically)
- Bottom: primary action button + optional skip button

#### Step 1: Profile

- Title: "Tell us about yourself"
- Subtitle: "Help us personalise your experience."
- Name field (placeholder: "Your name (optional)")
- Use case selection (required): 5 radio cards
  - "Inventory Tracking" -- "Track stock, supplies, or materials"
  - "Habit Tracking" -- "Build and maintain daily habits"
  - "Fitness & Exercise" -- "Count reps, sets, or workouts"
  - "Manufacturing" -- "Track production or quality counts"
  - "Other" -- "Something else" (shows text field: "Tell us more...")
- Referral source (optional): 5 choice chips
  - Friend or Colleague, Social Media, Search Engine, App Store, Other
  - "Other" shows text field: "Tell us more..."
- Bottom: "Continue" button + "Skip for now" link

#### Step 2: Product Intro

- Hero icon: `devices` (80px)
- Title: "Welcome to Traxelos One"
- Three info sections with icons:
  - "How it works" (`touch_app`): "A physical counting device that pairs with this app via Bluetooth to track anything you need."
  - "What you need" (`bluetooth`): "Your Traxelos One device nearby with Bluetooth enabled on your phone."
  - "What's next" (`rocket_launch`): "We'll help you pair your device so you can start counting right away."
- Bottom: "Continue" button (no skip)

#### Step 3: Device Pairing

Layout varies by Bluetooth state:
- **Permissions required:** Banner "Bluetooth permissions required" with "Grant" button; center icon `bluetooth_disabled`
- **Bluetooth disabled:** Banner "Bluetooth is disabled. Please enable it in settings."; center icon `bluetooth_disabled`
- **Connecting:** Spinner + "Connecting..."
- **Syncing:** Spinner + "Setting up device..." / "Transferring your data"
- **Ready/Scanning:** Title "Find Your Device", subtitle "Make sure your Traxelos One is powered on and nearby", scan button "Scan for Devices" / "Scanning..." (blinking), device list sorted by signal strength
- Bottom: "I don't have a device yet" skip link (no primary button -- step handles its own flow)

#### Step 4: Done

- Success icon: `check_circle_outline` (80px, success color)
- Title: "You're All Set!"
- Device info card (if paired): Bluetooth icon + device name
- Subtitle: "Your device is ready to count. Press the button on your Traxelos One to start!"
- Bottom: "Get Started" button

**States per step:** Loading, error (SnackBar), success (advances to next step or completes)

---

### ItemsListPage `/`

**Purpose:** Main screen displaying all tracked items with filtering, search, and device sync status.

**Entry points:** Home tab in bottom navigation.

**Layout:**
- App bar: title "Items", leading Bluetooth indicator (blue dot when connected), search icon, create item icon (when items exist)
- Active item chip (when device connected and item selected): item name with pin icon, dismiss button
- Sync banners:
  - Disconnected: gray, "Device Disconnected"
  - Syncing: blue with spinner, "Syncing with device..."
- Search field (toggled): placeholder "Search items...", clear button
- Category dropdown: "All Items" or specific category, includes "Manage Categories" option
- Item list: grouped by category with dividers, reorderable via long-press drag (when connected), swipeable left for actions
- Empty states:
  - No items: "No items yet" / "Create your first item to start tracking" / "Create Item" button
  - No search results: "No items match your search"
  - Connect device card: purple card with "Connect your device" / "Tap to connect and sync your data" / "Connect" button / dismiss

**Interactive elements:**

| Element | Action |
|---------|--------|
| Search icon (app bar) | Toggle search field |
| Create icon (app bar) | Open ItemFormPage (create mode) |
| Item tile tap | Open ItemDetailPage |
| Item tile swipe left | Reveal: "Update" (edit), "Increment" (manual +1), "Delete" (soft-delete) |
| Long-press + drag | Reorder items (device connected only) |
| Category dropdown | Filter by category or navigate to ManageCategoriesPage |
| Active item chip dismiss | Deselect active item |
| Connect device card | Navigate to BluetoothPage |

**States:**
- **Loading:** Circular progress indicator
- **Empty:** Icon + message + action button
- **Populated:** Scrollable item list
- **Searching:** Filtered results
- **Syncing:** Blue banner with spinner
- **Disconnected:** Gray banner

**Dialogs:**
- Delete confirmation: Title "Delete Item", message "Are you sure you want to delete '{name}'? This action can be undone within 90 days.", actions "Cancel" / "Delete" (red)

---

### ItemDetailPage `/items/:id`

**Purpose:** Detailed analytics, charts, cycle history, and notes for a single item.

**Entry points:** Tap item in ItemsListPage.

**Layout:**
- App bar: back button, item name as title
- Pull-to-refresh on entire scroll view
- Cycle selector chip (sticky): filter icon + cycle label (e.g., "Current Cycle", "All Time"), dropdown arrow; below: "Updated [time]"
- Static header card:
  - Goal ring (190x190): current count center (52pt bold), ring colored purple (with goal), teal-green (complete), gray (no goal/historical)
  - Goal stats pill: "75% -- 25 to goal" or "Complete!"
  - Date info: "Started [date]" or "[start] -> [end] -- X days"
  - Config stats row: Per Press "+X", Reminder "@ X" / "Every X" / "None"
- Cycle note section (hidden for All Time):
  - Label "CYCLE NOTE"
  - CycleNoteCard: display "Add a note..." placeholder or note text; tap to edit (3-line text field, 250 char max, "Done" button)
- Activity section:
  - Label "ACTIVITY"
  - Chart controls: aggregation pills "1D" / "7D" / "30D", date picker with prev/next arrows
  - Chart header: "+X increments", trend badge ("+X% vs Y DoD/WoW/MoM"), toggle "Add" (bar) / "Sum" (cumulative)
  - Chart display (200px): bars with y-axis, x-axis labels, tap for tooltip
- Cycle history table:
  - Label "CYCLE HISTORY"
  - Header: "Cycle", "Count", "Avg/day", "Duration"
  - All Time row (top, gray, infinity icon) + individual cycle rows
  - Selected row: purple left border + highlight
  - Max 6 visible rows, scrollable

**Interactive elements:**

| Element | Action |
|---------|--------|
| Pull down | Refresh data |
| Cycle selector chip | Open CycleSelectionBottomSheet |
| Note card | Tap to edit, blur/Done to save |
| Aggregation pills (1D/7D/30D) | Change chart time window |
| Date picker arrows | Navigate prev/next period |
| Date picker center text | Open calendar bottom sheet |
| Chart toggle (Add/Sum) | Switch bar vs cumulative chart |
| Chart bars | Tap to show tooltip |
| Cycle history rows | Tap to select cycle |

**States:**
- **Loading:** Shimmer skeletons for chart and stats
- **Loaded:** All sections populated
- **Empty (no events):** Chart shows zeros
- **Current cycle:** Ring colored, stats full opacity
- **Historical cycle:** Ring gray, stats dimmed (40% opacity)
- **All Time:** Ring gray, "Total" label

**Validation:**
- Note: max 250 characters, whitespace trimmed
- Cycle rename: max 20 characters

**Dialogs & sheets:**
- CycleSelectionBottomSheet: handle bar, title "Select Cycle" with close button, cycle rows (radio + green dot for current + name + edit icon, subtitle with cycle number/dates/presses), edit mode (text field + check), All Time row at bottom
- Date picker bottom sheet: handle bar, "Select Date" / "Select End Date", calendar widget, "Cancel" / "Confirm"

---

### ItemFormPage `/items/form`

**Purpose:** Create new items or edit existing items.

**Entry points:** Create icon in ItemsListPage app bar; "Update" swipe action on item; "Create Item" button in empty state.

**Layout:**
- App bar: back button, title "Create Item" or "Edit Item"
- Scrollable form:
  - "Item Name" field (placeholder "Enter item name...", max 30 chars with counter)
  - "Category (optional)" dropdown ("Uncategorized", category names, "Manage Categories")
  - "Initial Value" field (create only, placeholder "Enter initial count...", digits only)
  - "Goal (optional)" field (placeholder "Enter target goal...", digits only)
  - "Count Per Press" field (placeholder "e.g. 1, 5, 10...", digits only)
  - "Reminder (Vibration)" dropdown ("None", "At Target Count", "Every X Increments")
  - "Reminder Value" field (shown when reminder != None, placeholder "Enter reminder value...")
  - Button row: "Cancel" (gray outlined) / "Create" or "Update" (primary filled)

**Interactive elements:**

| Element | Action |
|---------|--------|
| Text fields | Input with validation |
| Category dropdown | Select category or navigate to ManageCategoriesPage |
| Reminder dropdown | Select reminder type, shows/hides reminder value field |
| "Cancel" button | Close without saving |
| "Create"/"Update" button | Validate, check duplicate names, save |

**States:**
- **Idle:** All fields editable
- **Loading:** Buttons disabled, spinner on submit button
- **Validation errors:** Red text below invalid fields

**Validation:**
- Item Name: required, max 30 chars, no duplicate names (case-insensitive, checks active and deleted)
- Initial Value (create only): required, 0--999,999
- Goal: optional, 0--999,999
- Count Per Press: required, 1--1,000
- Reminder Value (when reminder selected): required, 0--9,999

---

### PrivacyPolicyPage (modal push from ProfilePage)

**Purpose:** Display the app's privacy policy from a bundled markdown file.

**Entry points:** "Privacy & Security" in ProfilePage.

**Layout:**
- App bar: back button, title "Privacy Policy"
- Markdown content rendered from `assets/privacy_policy.md`

**States:**
- **Loading:** Center spinner
- **Loaded:** Rendered markdown
- **Error:** "Error loading privacy policy: {error}"
- **Empty:** "Privacy policy not available"

---

### BluetoothTestPage `/bluetooth/test` (temporary)

**Purpose:** Developer test page for verifying BLE hardware communication. Not exposed in production UI -- marked for removal.

---

### DeletedItemsPage `/profile/deleted-items`

**Purpose:** View and restore soft-deleted items within 90-day retention.

**Entry points:** "Recently Deleted" in ProfilePage.

**Layout:**
- App bar: back button, title "Recently Deleted"
- Header: "X item(s) will be permanently deleted after 90 days"
- Disconnected banner (if not connected): "Connect to restore items", tap to navigate to BluetoothPage
- Item cards: item name, "Deleted [relative time]", "X days remaining" (red if <=7 days), "Restore" button (disabled when disconnected)
- Empty state: delete icon (64px), "No Deleted Items", "Items you delete will appear here for 90 days before being permanently removed."

**Interactive elements:**

| Element | Action |
|---------|--------|
| "Restore" button | Restore item, sync to device |
| Disconnected banner | Navigate to BluetoothPage |

**States:**
- **Loading:** Circular progress indicator
- **Empty:** Icon + message
- **Populated:** List of deleted items
- **Restoring:** Button shows spinner, disabled
- **Success:** SnackBar "Item restored successfully" (green)
- **Error:** SnackBar with error (red)

---

### BluetoothPage `/bluetooth`

**Purpose:** Main Bluetooth hub showing connection status and actions.

**Entry points:** Bluetooth tab in bottom navigation.

**Layout:**
- App bar: title "Bluetooth", no back button
- Status card (icon + title + subtitle):
  - Connected: green `bluetooth_connected`, "Connected", "Connected to [device name]"
  - Connecting: orange `bluetooth_searching`, "Connecting", "Establishing connection..."
  - Ready: blue `bluetooth`, "Ready to Connect", "Search for your ESP32 device"
  - Permissions required: orange `security`, "Permissions Required", "Grant Bluetooth permissions to connect"
  - Bluetooth disabled: red `bluetooth_disabled`, "Bluetooth Disabled", "Enable Bluetooth in settings"
- Action buttons (vary by state):
  - Connected: "Disconnect" (outlined, red, `bluetooth_disabled` icon)
  - Connecting: "Connecting..." (disabled, spinner)
  - Ready: "Find Device" (elevated, `bluetooth_searching` icon)
  - Permissions: "Find Device" (disabled) + "Grant Permissions" (outlined, `security` icon)
  - BT disabled: "Find Device" (disabled)
- Info card "About ESP32 Connection": three status rows
  - "Bluetooth": "Enabled" (green) / "Disabled" (red)
  - "Permissions": "Granted" (green) / "Required" (orange)
  - "Device": device name (green) / "Not connected"

**Interactive elements:**

| Element | Action |
|---------|--------|
| "Find Device" button | Navigate to BluetoothSearchPage |
| "Disconnect" button | Disconnect from device |
| "Grant Permissions" button | Request BLE permissions |

---

### BluetoothSearchPage `/bluetooth/search`

**Purpose:** Scan for and connect to BLE devices.

**Entry points:** "Find Device" from BluetoothPage; "Connect" from ItemsListPage empty state.

**Layout:**
- App bar: back button, title "Find Device"
- Status banner (conditional): orange "Bluetooth permissions required" with "Grant" button, or red "Bluetooth is disabled..."
- Scan button (full-width): "Scan for Devices" / "Scanning..." (blinking when active), `bluetooth_searching` icon
- Device list:
  - Scanning + empty: spinner + "Searching for devices..." + "[N] device(s) found"
  - Not scanning + empty: `bluetooth_disabled` icon + "No devices found. Tap 'Scan' to search."
  - Devices found: list of BleDeviceListTile widgets sorted by signal strength

**Interactive elements:**

| Element | Action |
|---------|--------|
| Back button | Pop to BluetoothPage |
| "Grant" button | Request permissions |
| Scan button | Toggle scan start/stop |
| Device tile | Connect to device |

**States:**
- **Scanning:** Blinking button text, spinner in list
- **Devices found:** Static button, device list
- **No devices:** Static button, empty state
- **Connecting:** Selected device shows spinner
- **Connected:** Auto-navigates to ItemsListPage

---

### PairedDevicesPage `/profile/paired-devices`

**Purpose:** Manage all Traxelos devices paired to the account.

**Entry points:** "Paired Devices" in ProfilePage.

**Layout:**
- App bar: back button, title "Paired Devices"
- Device list:
  - Connected device: green border, watch icon in green circle, name, "Connected", "ID: [deviceInstanceId]", 3-dot menu
  - Paired (not connected): no border, watch icon in gray circle, name, "Paired [relative date]", "ID: [deviceInstanceId]", 3-dot menu
- Empty state: `devices_outlined` icon, "No devices paired", "Connect to a Traxelos device to pair it with your account."

**Interactive elements:**

| Element | Action |
|---------|--------|
| 3-dot menu | Shows "Rename" and "Unpair" options |

**Dialogs:**
- Rename: title "Rename Device", field "Device Name" (hint "e.g., Office Counter, Home Device", max 32 chars), "Cancel" / "Save"
- Unpair: title "Unpair Device", "To complete unpairing, factory reset the device.", info box "On device: Hold B button for 10 seconds.", "Cancel" / "Remove from List" (red)

---

### ProfilePage `/profile`

**Purpose:** Account settings hub with sections for appearance, data management, support, and account actions.

**Entry points:** Account tab in bottom navigation.

**Layout:**
- App bar: title "Account"
- Profile header: display name (or "No name set"), email
- Divider
- **Appearance** section: "Dark Mode" toggle (Switch.adaptive)
- **Account Settings** section:
  - "Edit Profile" (chevron)
  - "Privacy & Security" (chevron, opens markdown viewer)
- **Data Management** section:
  - "Manage Categories" (chevron)
  - "Paired Devices" (chevron)
  - "Start New Cycle" (chevron, disabled when disconnected, subtitle "Requires device connection")
  - "Export My Data" (chevron)
  - "Recently Deleted" (chevron)
- **Support** section: "Help & Support" (chevron)
- Divider
- "Log Out" button (full-width, error-colored, `logout` icon)
- **Danger Zone** section: "Delete Account" card (red border, warning icon, subtitle "Permanently delete your account and all data")
- App version: "v{version} ({buildNumber})"

**Interactive elements:**

| Element | Action |
|---------|--------|
| Dark Mode toggle | Switch theme |
| "Edit Profile" | Navigate to EditProfilePage |
| "Privacy & Security" | Open privacy policy viewer |
| "Manage Categories" | Navigate to ManageCategoriesPage |
| "Paired Devices" | Navigate to PairedDevicesPage |
| "Start New Cycle" | Open confirmation dialog (connected only) |
| "Export My Data" | Navigate to ExportPage |
| "Recently Deleted" | Navigate to DeletedItemsPage |
| "Help & Support" | Navigate to HelpSupportPage |
| "Log Out" button | Open sign-out confirmation |
| "Delete Account" card | Open delete confirmation flow |

**States:**
- **Loading / Deleting:** Center spinner
- **Loaded:** Full content
- **Error:** Error SnackBar

**Dialogs:**
- Sign out: "Sign Out?" / "Are you sure you want to sign out?" / "Cancel" / "Sign Out"
- Start new cycle: "Start New Cycle" / bullet list (counts set to 0, new cycle begins, historical data preserved) / "This action cannot be undone." / "Cancel" / "Start New Cycle"
- Delete account (step 1): "Delete Account?" / lists what will be deleted (profile, items, event logs, account) / "This action cannot be undone." / device warning / "Cancel" / "Delete"
- Delete account (step 2): "Final Confirmation" / text field "Type DELETE" / "Cancel" / "Delete Account" (only proceeds if text matches "DELETE")
- Reauthentication: "Session Expired" / "For security, please sign in again to delete your account." / "Cancel" / "Sign In & Delete"

---

### EditProfilePage `/profile/edit`

**Purpose:** Edit user display name.

**Entry points:** "Edit Profile" in ProfilePage.

**Layout:**
- App bar: back button, title "Edit Profile", "Save" text button (enabled only when changes exist)
- "Display Name" label + text field (hint "Enter your name")
- "Email" label + read-only container showing email
- Helper: "Email cannot be changed"

**Interactive elements:**

| Element | Action |
|---------|--------|
| Display Name field | Edit name |
| "Save" button | Save profile, shows spinner when saving |

**States:**
- **No changes:** Save disabled (secondary color)
- **Changes exist:** Save enabled (primary color)
- **Saving:** Save shows spinner
- **Success:** SnackBar "Profile updated successfully", pops back
- **Error:** SnackBar with error

---

### HelpSupportPage `/profile/help`

**Purpose:** FAQ and contact support.

**Entry points:** "Help & Support" in ProfilePage.

**Layout:**
- App bar: back button, title "Help & Support"
- **Quick Tips** section: 6 expandable FAQ panels (radio mode, one open at a time):
  1. "How do I connect my device?"
  2. "How do I add a new item to track?"
  3. "How do I reset my count?"
  4. "How do I export my data?"
  5. "What happens to deleted items?"
  6. "How do I reorder my items?"
- **Contact Support** section:
  - `support_agent_rounded` icon (48px)
  - "Need more help?"
  - "Our support team is here to help you with any questions or issues."
  - "Email Support" button (full-width, primary) -- opens mailto:support@digi1st.com with subject "Traxelos Support Request"
  - Email address displayed: "support@digi1st.com"
- App info: "Traxelos" + "v{version} ({buildNumber})"

---

### ManageCategoriesPage `/profile/categories`

**Purpose:** Create, edit, delete, and reorder item categories.

**Entry points:** "Manage Categories" in ProfilePage; "Manage Categories" in item form/list dropdown.

**Layout:**
- App bar: back button, title "Manage Categories", add button (`add_rounded` icon)
- Helper: "Drag to reorder categories. Tap to edit."
- Reorderable list of category tiles: drag handle, name, edit icon, delete icon
- Info card: "Items without a category appear as 'Uncategorized' in the filter."
- Empty state: `category_outlined` icon, "No categories yet", "Create categories to organize your items", "Create Category" button

**Interactive elements:**

| Element | Action |
|---------|--------|
| Add button (app bar) | Open create category dialog |
| "Create Category" button (empty state) | Open create category dialog |
| Category tile tap / edit icon | Open edit category dialog |
| Delete icon | Open delete confirmation |
| Drag handle | Long-press and drag to reorder |

**Dialogs:**
- Create/Edit: title "New Category" / "Edit Category", field "Category Name" (hint "e.g., Electronics, Office Supplies", max length per AppConstants), "Cancel" / "Create" or "Save"
- Delete: "Delete Category" / "Are you sure you want to delete '{name}'? Items in this category will become uncategorized." / "Cancel" / "Delete"

**Validation:**
- Category name: required, cannot be empty/whitespace

---

### ExportPage `/profile/export`

**Purpose:** Configure and export item data as CSV via email.

**Entry points:** "Export My Data" in ProfilePage.

**Layout:**
- App bar: back button, title "Export Data"
- **Aggregation Level** section (icon badge + title):
  - Three ChoiceChips: "Raw", "By Day", "By Cycle" (selected: primary background, white text)
  - Description:
    - Raw: "Export each individual event with timestamp."
    - By Day: "Group button presses by day. Resets and initial counts are not included."
    - By Cycle: "Total button presses per reset cycle. Initial counts are not included."
- **Cycle Scope** section (By Cycle only):
  - Two ChoiceChips: "All Cycles", "Latest Cycle"
  - Description: "Export data from all reset cycles." / "Export only data from the most recent reset cycle."
- **Date Range** section (Raw/By Day only):
  - Start date tile + arrow + End date tile (tap opens date picker)
  - Summary: "{days} day(s) selected"
- **Items** section:
  - Selector showing "All items" or "{count} of {total} items", tap opens item picker bottom sheet
- **Email Address** section:
  - Email field (hint "Enter your email address...", prefix `alternate_email_rounded` icon)
  - Helper: "The CSV file will be sent to this email address."
- **Export Preview** card:
  - Rows: cycle scope or date range, aggregation level, item count, email
- "Export to Email" button (full-width, 56px, `send_rounded` icon)

**Interactive elements:**

| Element | Action |
|---------|--------|
| Aggregation chips | Select raw/daily/byCycle |
| Cycle scope chips | Toggle all cycles / latest cycle |
| Date tiles | Open date picker |
| Item selector | Open item picker bottom sheet |
| Email field | Text input |
| "Export to Email" button | Validate form, send export |

**States:**
- **Default:** Form visible, button enabled if valid
- **Exporting:** Button shows spinner + "Exporting...", loading text "Generating and sending export..."
- **Success:** SnackBar "Export sent! Check your email.", pops back
- **Error:** SnackBar with error

**Validation:**
- Email: required, valid email format
- At least one item must be selected

**Dialogs & sheets:**
- Item picker bottom sheet: handle bar, "Select Items" title, "Select All" / "Deselect All" toggle, search field "Search items...", checkbox list (item name + category), "No items match your search." empty state

---

## 4. Shared Components

### Item Card
- Displays: item name, "Today: X -- Total: Y", increment badge "+X", reminder type indicator (colored vertical bar: purple=target, blue=interval, gray=none)
- Tap: opens ItemDetailPage for that item
- Swipe left: reveals Update/Increment/Delete actions
- Used in: ItemsListPage

### BleDeviceListTile
- Displays: device name (or "Unknown Device"), device ID, "Signal: [rssi] dBm", signal strength icon (green >-50, orange -70 to -50, red <-70)
- Trailing: chevron (or spinner when connecting)
- Tap: connect to device
- Used in: BluetoothSearchPage, OnboardingPage (Step 3)

### BleStatusBanner
- Full-width colored banner with message + optional action button
- Used in: BluetoothSearchPage (permissions/BT disabled), OnboardingPage (Step 3)

### BlinkingWidget
- Wraps any widget with fade in/out animation (800ms, opacity 1.0 to 0.3)
- Used in: scan button text/icon during BLE scanning

### Social Sign-In Button
- Google: white background, official Google "G" logo, "Continue with Google"
- Apple: black background, Apple icon, "Continue with Apple" (iOS only)
- Used in: LoginPage, SignupPage

### Goal Ring
- Circular progress ring (190x190) with count in center
- Colors: purple (in-progress), teal-green (complete), gray (no goal/historical)
- Used in: ItemDetailPage static header

### Bar Chart / Cumulative Chart
- Purple bars, gray initial-count stacking, y-axis labels, x-axis labels (hour/day), tap for tooltip
- Tooltip shows date + breakdown (total, earned, initial, activity)
- Used in: ItemDetailPage activity section

### Periods Table
- Table with columns: Cycle, Count, Avg/day, Duration
- All Time row on top (gray, infinity icon), individual cycles below
- Selected row: purple border + highlight
- Used in: ItemDetailPage cycle history section

---

## 5. Data Entities

### Item

| Field | Type | User-Facing | Constraints |
|-------|------|-------------|-------------|
| name | String | Editable | Required, max 30 chars, unique |
| count | int | Visible | Total cumulative count |
| todayCount | int | Visible (ItemCard only) | Resets at midnight, shown as "Today: X" in list |
| incrementBy | int | Editable | 1--1,000 |
| reminder | ReminderType | Editable | none / target / interval |
| reminderValue | int | Editable | 0--9,999 |
| goal | int? | Editable | Optional, 0--999,999 |
| categoryId | String? | Editable | References Category |
| initialCount | int | Internal | Starting count for calculations |
| resetNumber | int | Visible | Cycle counter |
| lastResetTime | DateTime? | Visible | Last reset timestamp |
| cycleNames | Map | Editable | Custom cycle names (max 20 chars each) |
| cycleNotes | Map | Editable | Cycle notes (max 250 chars each) |
| deletedAt | DateTime? | Internal | Soft-delete (90-day retention) |
| order | int | Internal | Display order (drag-to-reorder) |

**Relationships:** belongs to Category (via categoryId), has many EventLog entries (via itemId)

### Category

| Field | Type | User-Facing | Constraints |
|-------|------|-------------|-------------|
| name | String | Editable | Required, max per AppConstants |
| order | int | Internal | Display order (drag-to-reorder) |

**Relationships:** has many Items

### EventLog

| Field | Type | User-Facing | Constraints |
|-------|------|-------------|-------------|
| createdTime | DateTime | Visible | Event timestamp |
| eventName | String | Visible | "increment" / "decrement" / "switch" / "reset" / "created" |
| increment | int | Visible | Amount changed |
| currentCount | int | Visible | Count after event |
| resetNumber | int | Visible | Cycle number |

**Relationships:** belongs to Item (via itemId)

### User / UserProfile

| Field | Type | User-Facing | Constraints |
|-------|------|-------------|-------------|
| email | String | Visible (read-only) | From Firebase Auth |
| displayName | String? | Editable | Optional |
| pairedDevices | List | Visible | Max 10 devices |
| onboardingCompleted | bool | Internal | Tracks wizard completion |

### PairedDevice

| Field | Type | User-Facing | Constraints |
|-------|------|-------------|-------------|
| deviceInstanceId | String | Visible | UUID, regenerates on factory reset |
| deviceName | String | Editable | Default "Traxelos One", max 32 chars |
| pairedAt | DateTime | Visible | Pairing timestamp |

### BleDevice (discovered, not persisted)

| Field | Type | User-Facing | Constraints |
|-------|------|-------------|-------------|
| name | String | Visible | Device name or "Unknown Device" |
| id | String | Visible | Platform-specific BLE ID |
| rssi | int | Visible | Signal strength in dBm |

---

## 6. Theme & Styling

### Color Palette

| Name | Purpose |
|------|---------|
| `primary` | Brand purple, buttons, active states, selected chips |
| `primaryLight` | Lighter purple for dark mode (via `primaryAdaptive()`) |
| `secondary` | Teal accent |
| `tertiary` | Orange accent, gradient endpoint |
| `success` | Green -- success feedback, connected states, goal complete |
| `warning` | Yellow -- warning banners, permissions required |
| `error` | Red -- errors, delete actions, danger zone |
| `positive` | Dark green -- positive trend indicators |
| `negative` | Dark red -- negative trend indicators |
| `neutral` | Gray -- flat/no-change indicators |
| `chartInitial` | Gray -- initial count bars in charts |
| `disabled` | Gray -- disabled button backgrounds |
| `actionDelete` | Red -- swipe delete action |
| `actionActivate` | Purple -- swipe activate action |
| `actionMoveToTop` | Cyan -- swipe move-to-top action |

### Typography Scale

| Style | Font | Weight | Usage |
|-------|------|--------|-------|
| displayLarge/Medium/Small | Inter Tight | 600 | Auth page titles, large displays |
| headlineLarge/Medium/Small | Inter Tight | 600 | Section headings, onboarding titles |
| titleLarge/Medium/Small | Inter Tight | 600 | App bar titles, card titles, labels |
| labelLarge/Medium/Small | Inter | 400 | Labels, hints, small text |
| bodyLarge/Medium/Small | Inter | 400 | Body text, descriptions, field values |

### Dark/Light Mode

- Theme persists to SharedPreferences; toggle on ProfilePage
- Light: white cards on light gray scaffold, dark text
- Dark: dark gray cards on near-black scaffold, white text
- Primary color adapts via `primaryAdaptive()` (brighter in dark mode)
- All semantic colors (success, error, warning) stay consistent across modes
- Borders/dividers use `alternate` color which adapts per mode
