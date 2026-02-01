# User Guide & Product Overview Documentation Update

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Update USER_GUIDE.md and PRODUCT_OVERVIEW.md to accurately reflect the current state of the app, firmware, and multi-device features.

**Architecture:** Direct documentation edits based on three code reviews that identified 59 discrepancies between docs and codebase. Changes are grouped by document section for efficient editing.

**Source of truth:** App code in `lib/`, firmware in `firmware/`, BLE protocol in `docs/BLE_PROTOCOL.md`.

---

## Task 1: Global Branding Fix — Rename "Traxogic" to "Traxelos"

**Files:**
- Modify: `docs/USER_GUIDE.md` (all occurrences)
- Modify: `docs/PRODUCT_OVERVIEW.md` (all occurrences)

**Step 1: Replace all occurrences in USER_GUIDE.md**

Find-and-replace (case-sensitive):
- `Traxogic` → `Traxelos` (covers "Traxogic User Guide", "What is Traxogic?", "Traxogic is a", "Traxogic device", etc.)
- `Traxogic_device` → `Traxelos_device` (device name example)

**Evidence:** `lib/core/utils/constants.dart:9` → `appName = 'Traxelos'`; `lib/core/utils/bluetooth_constants.dart:94` → `deviceNamePrefix = 'Traxelos_device'`

**Step 2: Replace all occurrences in PRODUCT_OVERVIEW.md**

Same find-and-replace: `Traxogic` → `Traxelos`

**Step 3: Fix PRODUCT_OVERVIEW.md inaccuracies while editing**

- Line 42: Change "Track unlimited items" → "Track up to 100 items" (per `items_list_page.dart` `_maxItems = 100`)
- Line 38: Change "Vibration motor for haptic feedback on button press and reminders" → "Vibration motor for haptic feedback on reminders" (vibration only fires for reminders, not every press — per firmware `Trackwise_ESP32.ino:2196-2201`)
- Line 62: Remove "Auto-reconnect if connection drops" or change to "Auto-reconnect on unexpected disconnection during active session" (no auto-connect on app launch)
- Line 68: Change "Statistics: total, average, min, max" → "Statistics: period totals, percent change vs prior period" (matches `item_detail_page.dart` actual display)

**Step 4: Commit**

```
git add docs/USER_GUIDE.md docs/PRODUCT_OVERVIEW.md
git commit -m "docs: rename Traxogic to Traxelos across user guide and product overview"
```

---

## Task 2: Section 2 — Fix Getting Started (Signup, Onboarding)

**Files:**
- Modify: `docs/USER_GUIDE.md` (Section 2, lines ~41-66)

**Changes:**

1. **Remove name field from signup steps** — Signup has no name field (`signup_page.dart:159-161` only has Email, Password, Confirm Password)

2. **Add Confirm Password step** — Missing from guide (`signup_page.dart:325`)

3. **Change "Sign Up" button to "Create Account"** — (`signup_page.dart:434`)

4. **Clarify Apple sign-in is iOS only** — (`signup_page.dart:477` wraps Apple button in `if (Platform.isIOS)`)

5. **Add Onboarding subsection** — After signup, users see OnboardingPage (`onboarding_page.dart`) collecting:
   - Display name (optional)
   - Primary use case (required): Inventory Tracking, Habit Tracking, Fitness & Exercise, Manufacturing, Other
   - How you heard about us (optional)
   - Can be skipped

**New Section 2 content:**

```markdown
## 2. Getting Started

### Step 1: Download the App

Download Traxelos from the App Store (iOS) or Google Play (Android).

### Step 2: Create an Account

1. Open the app
2. Tap **Create Account**
3. Enter your email address
4. Create a password and confirm it
5. Tap **Create Account**

*You can also sign in with Google (or Apple on iOS) for faster setup.*

### Step 3: Complete Onboarding

After creating your account, you'll see a welcome screen:

1. Enter your name (optional)
2. Select your primary use case (e.g., Habit Tracking, Inventory)
3. Indicate how you heard about us (optional)
4. Tap **Complete**

*You can skip this step and go straight to the app.*

### Step 4: Sign In

If you already have an account:
1. Enter your email and password
2. Tap **Sign In**

### Step 5: Pair Your Device

See [Connecting Your Device](#3-connecting-your-device) below.
```

**Step: Commit**

```
git add docs/USER_GUIDE.md
git commit -m "docs: fix signup flow and add onboarding to user guide"
```

---

## Task 3: Section 3 — Fix Connecting Your Device

**Files:**
- Modify: `docs/USER_GUIDE.md` (Section 3, lines ~69-113)

**Changes:**

1. **Fix device name example** — Change `"Traxogic_device"` → `"Traxelos_device"` (already handled by Task 1 global replace, but verify)

2. **Fix "Find Device" flow** — Search page auto-starts scanning (`bluetooth_search_page.dart:41-49`). On connect, navigates to home (`bluetooth_search_page.dart:82`), not showing "Connected" on search page.

3. **Fix Reconnecting section** — No auto-connect on app launch. Auto-reconnect only works after unexpected disconnect during active session (`bluetooth_bloc.dart:73-91`, `534-557`). Reconnect on Bluetooth re-enable does work (`bluetooth_bloc.dart:185-201`).

4. **Fix Disconnecting section** — Remove "Manage Device" reference. Disconnect button is directly on Bluetooth page (`bluetooth_page.dart:120`).

**New Section 3 content:**

```markdown
## 3. Connecting Your Device

### First-Time Pairing

1. **Turn on your Traxelos device**
   - The device should be charged and powered on

2. **Open the Bluetooth tab** in the app
   - Tap the Bluetooth icon in the bottom navigation

3. **Grant Bluetooth permissions** (if prompted)
   - Tap "Grant Permissions"
   - Allow Bluetooth and Location access

4. **Tap "Find Device"**
   - The app will open the search page and automatically scan for nearby devices
   - Your device will appear in the list (e.g., "Traxelos_device")

5. **Select your device**
   - Tap the device name to connect
   - If this is a new device, you'll see a **"New Device Detected"** setup dialog — tap **"Set Up"** to pair

6. **You're connected!**
   - The app returns to the home screen
   - Check the Bluetooth tab to verify — it will show "Connected"

### Reconnecting

If your device disconnects unexpectedly during a session, the app will automatically try to reconnect. If it doesn't reconnect:

1. Go to the **Bluetooth tab**
2. Tap **"Find Device"**
3. Select your device from the list

### Disconnecting

To manually disconnect:
1. Go to the **Bluetooth tab**
2. Tap **"Disconnect"**
```

**Step: Commit**

```
git add docs/USER_GUIDE.md
git commit -m "docs: fix device connection flow and remove Manage Device references"
```

---

## Task 4: Section 4 — Fix Creating & Managing Items

**Files:**
- Modify: `docs/USER_GUIDE.md` (Section 4, lines ~116-159)

**Changes:**

1. **Add device connection requirement** — Create/edit/delete all require connection (`items_list_page.dart:270, 1545, 1563`)

2. **Fix field list** — Correct order and labels per `item_form_page.dart:187-487`:
   - Item Name (required, max 30 characters)
   - Category (optional)
   - Initial Value (create only, default 0, range 0-999,999)
   - Goal (optional)
   - Count Per Press (default 1, range 1-100) — NOT "Increment By"
   - Reminder (Vibration) (optional): None, At Target Count, Every X Increments
   - Reminder Value (if reminder set)

3. **Fix Editing section** — No edit button on detail page. Edit via swipe left on items list. Button says "Update" not "Save" (`item_form_page.dart:531`).

4. **Fix Deleting section** — Remove "Option 2: From item detail" (no delete on detail page). Document all 4 swipe actions: Activate, Move to Top, Edit, Delete (`items_list_page.dart:1447-1590`).

5. **Fix Reordering section** — Reorder is within category, not across categories. Does not immediately sync to device (`item_repository_impl.dart:227-280` only updates Firestore).

6. **Add Search** — Search icon in top-right filters items by name.

7. **Add item limit** — Max 100 items.

**New Section 4 content:**

```markdown
## 4. Creating & Managing Items

> **Note:** Your Traxelos device must be connected via Bluetooth to create, edit, or delete items.

### Creating Your First Item

1. Go to the **Home tab** (Items)
2. Tap the **+ button** in the top right
3. Fill in the details:
   - **Item Name** (required, max 30 characters) - e.g., "Push-ups"
   - **Category** (optional) - e.g., "Fitness"
   - **Initial Value** (create only) - Starting count (default: 0)
   - **Goal** (optional) - Target count
   - **Count Per Press** - How much to add per button press (default: 1)
   - **Reminder (Vibration)** (optional) - Choose a vibration alert type:
     - "None" - No vibration
     - "At Target Count" - Vibrate when reaching your goal
     - "Every X Increments" - Vibrate at regular intervals
   - **Reminder Value** - The count that triggers the vibration
4. Tap **Create**

You can track up to **100 items**.

### Editing an Item

1. On the items list, **swipe left** on the item
2. Tap the **edit icon** (pencil)
3. Make your changes
4. Tap **Update**

*Note: You cannot change the initial value after creation.*

### Deleting an Item

1. On the items list, **swipe left** on the item
2. Tap the **delete icon** (trash)
3. Confirm deletion

**Don't worry!** Deleted items go to "Recently Deleted" for 90 days. You can restore them anytime (device connection required).

### Swipe Actions

Swiping left on any item reveals four actions:

| Icon | Action | Description |
|------|--------|-------------|
| **Pin** | Activate | Set as the active item on your physical device |
| **Arrow up** | Move to Top | Move item to the top of its category |
| **Pencil** | Edit | Open the item edit form |
| **Trash** | Delete | Delete the item (with confirmation) |

### Searching Items

Tap the **search icon** in the top right to filter items by name.

### Reordering Items

1. **Long press** on an item
2. **Drag** it to the new position within its category
3. **Release** to save

Your custom order is saved and will appear on the device next time items are synced.
```

**Step: Commit**

```
git add docs/USER_GUIDE.md
git commit -m "docs: fix item management section with correct fields, swipe actions, and requirements"
```

---

## Task 5: Section 5 — Fix Physical Counter Usage

**Files:**
- Modify: `docs/USER_GUIDE.md` (Section 5, lines ~163-200)

**Changes:**

1. **Fix vibration claim** — Vibration does NOT happen on every press. Only fires for reminders (`Trackwise_ESP32.ino:2196-2201`). This is the most misleading claim in the guide.

2. **Fix button table** — Use BLE protocol terminology (increment/switch/reset per `BLE_PROTOCOL.md` Section 6.2). Note that "Reset" also starts a new cycle (`Trackwise_ESP32.ino:2258`).

3. **Keep midnight reset description** — Firmware confirms local date comparison with 60-second check interval. "Midnight (local time)" is adequate.

**New Section 5 content:**

```markdown
## 5. Using Your Physical Counter

### Basic Counting

1. Make sure your device is connected (check the Bluetooth tab)
2. Press the **count button** on your device
3. The app updates automatically

*If you have a reminder configured (see Section 7), you'll feel a vibration when the reminder condition is met.*

### What the Buttons Do

| Button | Action |
|--------|--------|
| **Count (Increment)** | Add to your current item's count |
| **Switch** | Change to the next item |
| **Reset** | Reset current item to zero and start a new tracking cycle |

### Understanding Your Counts

Each item tracks two numbers:

- **Total Count** - All-time total since you created the item
- **Today Count** - Count since midnight (resets daily)

### What Happens at Midnight?

Every night at midnight (local time):
- Your "Today Count" resets to 0
- Your "Total Count" stays the same
- This happens automatically on the device

### Counting Without Your Phone

Your device works independently! You can:
- Count without your phone nearby
- Counts are stored on the device
- Everything syncs when you reconnect
```

**Step: Commit**

```
git add docs/USER_GUIDE.md
git commit -m "docs: fix physical counter section - vibration, buttons, and reset behavior"
```

---

## Task 6: Section 6 — Fix Categories

**Files:**
- Modify: `docs/USER_GUIDE.md` (Section 6, lines ~203-234)

**Changes:**

1. **Fix create button label** — Dialog says "Create" not "Save" (`category_form_dialog.dart:107`)
2. **Fix delete mechanism** — Uses 3-dot popup menu with Rename/Delete, not standalone trash icon (`manage_categories_page.dart:152`). Add confirmation dialog mention.

**New Section 6 content:**

```markdown
## 6. Organizing with Categories

Categories help you group related items together.

### Creating a Category

1. Go to **Account tab**
2. Tap **"Manage Categories"**
3. Tap the **+ Add** icon in the top right
4. Enter a name (e.g., "Fitness", "Work", "Health")
5. Tap **Create**

### Assigning Items to Categories

When creating or editing an item:
1. Tap the **Category** dropdown
2. Select a category
3. Save your item

*Tip: The category dropdown also has a "Manage Categories" shortcut at the bottom.*

### Reordering Categories

1. Go to **Manage Categories**
2. **Long press** a category
3. **Drag** to reorder
4. Release to save

### Renaming or Deleting a Category

1. Tap the **three-dot menu** next to the category
2. Choose **Rename** or **Delete**
3. Confirm if deleting

*Items in a deleted category become "Uncategorized" (they're not deleted).*
```

**Step: Commit**

```
git add docs/USER_GUIDE.md
git commit -m "docs: fix category management - button labels and delete mechanism"
```

---

## Task 7: Section 7 — Fix Reminders

**Files:**
- Modify: `docs/USER_GUIDE.md` (Section 7, lines ~238-265)

**Changes:**

1. **Fix reminder type label** — "At Target Count" not "Target Count" (`item_form_page.dart:423`)
2. **Clarify vibration behavior** — Only device vibrates, only when condition met

**Updated reminder types table:**

```markdown
| Type | How It Works | Example |
|------|--------------|---------|
| **None** | No vibration alerts | - |
| **At Target Count** | Vibrates when you reach your goal | Vibrate at 100 push-ups |
| **Every X Increments** | Vibrates every N counts | Vibrate every 10 counts |
```

**Step: Commit**

```
git add docs/USER_GUIDE.md
git commit -m "docs: fix reminder type labels and vibration behavior"
```

---

## Task 8: Section 8 — Fix Viewing Data

**Files:**
- Modify: `docs/USER_GUIDE.md` (Section 8, lines ~268-324)

**Changes:**

1. **Fix Statistics description** — App shows period totals and percent change vs prior period, not "average, min, max" (`item_detail_page.dart:677-683`)
2. **Note item name in AppBar** — Detail page shows the item name as the page title (`item_detail_page.dart:478`)

Replace the Statistics bullet:
```markdown
- **Statistics** - Period total, percent change vs prior period
```

**Step: Commit**

```
git add docs/USER_GUIDE.md
git commit -m "docs: fix statistics description to match actual detail page"
```

---

## Task 9: Section 9 — Fix Exporting Data

**Files:**
- Modify: `docs/USER_GUIDE.md` (Section 9, lines ~328-358)

**Changes:**

1. **Fix navigation label** — "Export My Data" not "Export Data" (`profile_page.dart:198`)
2. **Fix button label** — "Export to Email" not "Send Export" (`export_page.dart:428`)
3. **Add default values** — Default range is last 30 days (`export_page.dart:29-30`), default aggregation is Daily (`export_page.dart:31`)

**Step: Commit**

```
git add docs/USER_GUIDE.md
git commit -m "docs: fix export section labels and add defaults"
```

---

## Task 10: Section 10 — Fix Account Management + Add Paired Devices

**Files:**
- Modify: `docs/USER_GUIDE.md` (Section 10, lines ~362-411)

**Changes:**

1. **Change "Profile tab" → "Account tab"** throughout — Page title is "Account" (`profile_page.dart:82`), bottom nav has no text labels (`app_shell.dart:67-81`)

2. **Fix "Logout" → "Log Out"** — (`profile_page.dart:418`). Confirmation button says "Sign Out" (`profile_page.dart:658`)

3. **Add "Requires device connection" note** to Start New Cycle — (`profile_page.dart:188-191`)

4. **Add Paired Devices subsection** — New feature at `/profile/paired-devices` (`paired_devices_page.dart`):
   - View all paired devices
   - See which device is currently connected (green indicator)
   - Rename devices (popup menu)
   - Unpair devices (popup menu)

5. **Add "Requires device connection" note** to Recently Deleted restore — (`deleted_items_page.dart:303`)

6. **Fix Help & Support reference** — Section is titled "Quick Tips" not "FAQ" (`help_support_page.dart:163`)

**New Paired Devices subsection:**

```markdown
### Managing Paired Devices

View and manage all devices paired to your account:

1. Go to **Account tab**
2. Tap **"Paired Devices"**

On this page you can:
- See all paired devices and their pairing date
- Identify the currently connected device (green indicator)
- **Rename a device** - Tap the three-dot menu > Rename
- **Unpair a device** - Tap the three-dot menu > Unpair

*After unpairing, factory reset the device before pairing it to another account.*
```

**Step: Commit**

```
git add docs/USER_GUIDE.md
git commit -m "docs: fix account section, add paired devices, fix button labels"
```

---

## Task 11: Section 11 — Fix Tips & Tricks

**Files:**
- Modify: `docs/USER_GUIDE.md` (Section 11, lines ~414-442)

**Changes:**

1. **Remove "Sync Time" tip** — No manual sync time UI exists. Time syncs automatically on connect.

2. **Remove "Keyboard Shortcuts" subsection entirely** — No double-press or long-press detection in firmware (`Trackwise_ESP32.ino:2157-2330` only handles single character commands).

3. **Keep Battery Saving** — Accurate per firmware and BLE protocol.

**Step: Commit**

```
git add docs/USER_GUIDE.md
git commit -m "docs: remove nonexistent sync time and keyboard shortcuts from tips"
```

---

## Task 12: Section 12 — Fix Troubleshooting

**Files:**
- Modify: `docs/USER_GUIDE.md` (Section 12, lines ~445-500)

**Changes:**

1. **Fix "counts aren't syncing"** — Remove "Manage Device > Sync Items". Replace with "Disconnect and reconnect your device to trigger a fresh sync."

2. **Fix "time on device is wrong"** — Remove "Bluetooth > Manage Device > Sync Time". Replace with "Time syncs automatically when your device connects. If the time seems wrong, disconnect and reconnect."

3. **Fix "Help & Support" reference** — Change "FAQ section" to "Quick Tips section".

**Step: Commit**

```
git add docs/USER_GUIDE.md
git commit -m "docs: fix troubleshooting - remove Manage Device references"
```

---

## Task 13: Quick Reference Card — Fix All Entries

**Files:**
- Modify: `docs/USER_GUIDE.md` (Quick Reference Card, lines ~505-536)

**Changes:**

1. **Fix navigation tab name** — "Account" not "Profile"

2. **Fix "Edit item"** — Change "Tap item > Edit" → "Swipe left > Edit icon" (edit is via swipe, not on detail page)

3. **Fix "Delete item"** — Change "Swipe left on item" → "Swipe left > Trash icon > Confirm"

4. **Fix "Sync time"** — Change "Bluetooth > Manage Device > Sync Time" → "Automatic on device connect"

5. **Add missing entries** — Paired Devices, Search, Activate item

**Updated Quick Reference tables:**

```markdown
### Navigation

| Tab | Icon | What It Does |
|-----|------|--------------|
| **Home** | House | View and manage all items |
| **Bluetooth** | Bluetooth | Connect and manage your device |
| **Account** | Person | Account, settings, export, support |

### Device Buttons

| Button | Action |
|--------|--------|
| Count (Increment) | Add to count |
| Switch | Change item |
| Reset | Reset to zero, start new cycle |

### Key Features

| Feature | Where to Find It |
|---------|------------------|
| Create item | Home > + button (requires device) |
| Edit item | Swipe left on item > Edit icon |
| Delete item | Swipe left on item > Trash icon |
| Activate item | Swipe left on item > Pin icon |
| Search items | Home > Search icon (top right) |
| Reorder | Long press & drag |
| Categories | Account > Manage Categories |
| Paired Devices | Account > Paired Devices |
| Export | Account > Export My Data |
| Restore deleted | Account > Recently Deleted |
| Connect device | Bluetooth > Find Device |
| Sync time | Automatic on device connect |
```

**Step: Commit**

```
git add docs/USER_GUIDE.md
git commit -m "docs: fix quick reference card with correct labels, actions, and new entries"
```

---

## Task 14: Final Review and Verify

**Step 1:** Read the entire updated `docs/USER_GUIDE.md` end-to-end.

**Step 2:** Grep for any remaining occurrences of stale terms:
```bash
grep -n "Traxogic\|Manage Device\|Profile tab\|Send Export\|Increment By\|Sign Up\|Logout" docs/USER_GUIDE.md
```

Expected: Zero matches.

**Step 3:** Grep for stale terms in PRODUCT_OVERVIEW.md:
```bash
grep -n "Traxogic" docs/PRODUCT_OVERVIEW.md
```

Expected: Zero matches.

**Step 4:** Verify all "Account tab" references are consistent:
```bash
grep -n "Account tab\|Profile tab" docs/USER_GUIDE.md
```

Expected: Only "Account tab" matches.

**Step 5:** If any issues found, fix and amend the last commit. Otherwise, push.

```bash
git push
```

---

## Summary

| Task | Section | Key Changes |
|------|---------|-------------|
| 1 | Global | Traxogic → Traxelos (both docs) + PRODUCT_OVERVIEW fixes |
| 2 | Sec 2 | Fix signup, add onboarding |
| 3 | Sec 3 | Fix device connection flow, remove Manage Device |
| 4 | Sec 4 | Fix fields, swipe actions, add search, item limit |
| 5 | Sec 5 | Fix vibration, button names, reset behavior |
| 6 | Sec 6 | Fix category create/delete flow |
| 7 | Sec 7 | Fix reminder type labels |
| 8 | Sec 8 | Fix statistics description |
| 9 | Sec 9 | Fix export labels and defaults |
| 10 | Sec 10 | Fix account section, add paired devices |
| 11 | Sec 11 | Remove nonexistent tips |
| 12 | Sec 12 | Fix troubleshooting |
| 13 | QR Card | Fix all entries |
| 14 | Final | Verify no stale terms remain |
