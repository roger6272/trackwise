# Traxelos One User Guide

Welcome to Traxelos One! This guide will help you get the most out of your physical counter device and companion app.

---

## Table of Contents

1. [What is Traxelos One?](#1-what-is-traxelos-one)
2. [Getting Started](#2-getting-started)
3. [Connecting Your Device](#3-connecting-your-device)
4. [Creating & Managing Items](#4-creating--managing-items)
5. [Using Your Traxelos One Counter](#5-using-your-traxelos-one-counter)
6. [Organizing with Categories](#6-organizing-with-categories)
7. [Setting Goals](#7-setting-goals)
8. [Setting Reminders](#8-setting-reminders)
9. [Viewing Your Data](#9-viewing-your-data)
10. [Exporting Your Data](#10-exporting-your-data)
11. [Managing Your Account](#11-managing-your-account)
12. [Tips & Tricks](#12-tips--tricks)
13. [Troubleshooting](#13-troubleshooting)

---

## 1. What is Traxelos One?

Traxelos One is a **physical counter device** paired with a **mobile app** that makes tracking habits, inventory, or any countable activity effortless.

**How it works:**
- Press the button on your device to count
- Your counts sync automatically to the app
- View analytics, set goals, and export data from your phone

**What you can track:**
- Daily habits (water intake, exercise reps, meditation minutes)
- Inventory counts (stock levels, audit tallies)
- Work tasks (completed items, customer interactions)
- Anything you want to count!

---

## 2. Getting Started

### Step 1: Download the App

Download Traxelos One from the App Store (iOS) or Google Play (Android).

### Step 2: Create an Account

1. Open the app
2. Tap **Create Account**
3. Enter your email address
4. Create a password and confirm it
5. Tap **Create Account**

*You can also sign in with Google (or Apple on iOS) for faster setup.*

### Step 3: Complete Onboarding

After creating your account, a guided setup walks you through four steps:

1. **Your Profile** — Enter your name, select your primary use case (e.g., Habit Tracking, Inventory), and how you heard about us. All fields are optional.
2. **Welcome to Traxelos One** — A quick overview of how it works, what you need, and what comes next.
3. **Find Your Device** — The app scans for your Traxelos One via Bluetooth. Tap your device in the list to connect and pair it. *(Tap "I don't have a device yet" to skip.)*
4. **You're All Set!** — A confirmation screen showing your paired device. Tap **Get Started** to enter the app. *(Only shown if you paired a device in the previous step.)*

*You can skip any step — tap "Skip for now" to move on or finish early.*

### Step 4: Sign In

If you already have an account:
1. Enter your email and password
2. Tap **Sign In**

### Step 5: Pair Your Device

See [Connecting Your Device](#3-connecting-your-device) below.

---

## 3. Connecting Your Device

### First-Time Pairing

1. **Turn on your Traxelos One device**
   - The device should be charged and powered on

2. **Open the Bluetooth tab** in the app
   - Tap the Bluetooth icon in the bottom navigation

3. **Grant Bluetooth permissions** (if prompted)
   - Tap "Grant Permissions"
   - Allow Bluetooth and Location access

4. **Tap "Find Device"**
   - The app will open the search page and automatically scan for nearby devices
   - Your device will appear in the list (e.g., "Traxelos_One")

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

---

## 4. Creating & Managing Items

> **Note:** Your Traxelos One device must be connected via Bluetooth to create, edit, or delete items.

### Creating Your First Item

1. Go to the **Home tab** (Items)
2. Tap the **+ button** in the top right
3. Fill in the details:
   - **Item Name** (required, max 30 characters) - e.g., "Push-ups"
   - **Category** (optional) - Select from the dropdown (see [Organizing with Categories](#6-organizing-with-categories))
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

Your custom order is saved and synced to your device.

---

## 5. Using Your Traxelos One Counter

### Basic Counting

1. Make sure your device is connected (check the Bluetooth tab)
2. Press the **count button** on your device
3. The app updates automatically

> When you first connect, a brief **"Syncing..."** indicator appears on the items list while your counts update from the device. This disappears once sync is complete.

*You'll feel a triple vibration when you reach an item's goal, or a single vibration when a reminder condition is met (see [Setting Reminders](#8-setting-reminders)).*

*The maximum count for any item is **9,999**. When you reach this limit, the device will display "MAX REACHED" and give a double vibration on each press. Reset the item to continue counting.*

### Device Buttons

#### Arduino IDE (Serial Monitor)

| Key | Action |
|-----|--------|
| **U** | Increment — Add to your current item's count |
| **S** | Switch — Change to the next item |
| **R** | Reset — Reset current item to zero and start a new tracking cycle |
| **F** | Factory Reset — Erase all data and restore device to factory settings |

#### Traxelos One Device

**Button A**

| Interaction | Location | Action |
|-------------|----------|--------|
| Press | Main Item View | Add to your current item's count |
| Press | Item Menu View | Confirm item selection (Menu view) |
| Press | Sleep Mode | Awake the device |
| Press & Hold 3 seconds | Main Item View | Display time, Current Category, and Current Item for 10 seconds or until a button is pressed |

**Button B**

| Interaction | Location | Action |
|-------------|----------|--------|
| Press | Main Item View | Enter item menu view |
| Press | Item Menu View | Next item in the menu |
| Press | Sleep Mode | Awake the device |
| Press & Hold | Item Menu View | Rapidly loop through the items in the menu |
| Press & Hold 3 seconds | Main Item View | Reset the selected item's count (Enter the next cycle) |

**Automatic Behaviors**

| Trigger | Location | Action |
|---------|----------|--------|
| 5 secs of inactivity | Item Menu View | Leave the menu to the Main Item View |
| 5 mins of inactivity | Main Item View | Enter Power Saving mode (Display Off) |
| Turn on device | When device is on before pairing | Show "Welcome" on the display |

**Factory Reset**

To erase all data and restore the device to its original state, hold **both A and B buttons for 7 seconds**. The device will clear all items, counts, and pairing information.

**When to factory reset:**
- Before pairing a device to a different account
- After unpairing or deleting your account while the device was not connected
- If the device is behaving unexpectedly and reconnecting doesn't resolve it

*After a factory reset, the device will show "Welcome" and is ready to be paired as a new device.*

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

For best results, sync regularly by opening the app near your device — this backs up your data to the cloud and keeps everything up to date.

---

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

---

## 7. Setting Goals

Goals let you set a target count for any item and track your progress visually.

### Adding a Goal

1. Create or edit an item
2. Enter a number in the **Goal** field (e.g., 100)
3. Save

### Viewing Goal Progress

On the **Item Detail Page** (tap any item), you'll see:
- A **progress ring** showing how close you are to your goal
- Your current count vs. your target

*When you reach a goal, your device gives a distinctive **triple vibration** so you know you've hit your target without looking at the screen.*

---

## 8. Setting Reminders

Reminders make your physical device vibrate to keep you on track — no need to check your phone.

### Types of Reminders

| Type | How It Works | Example |
|------|--------------|---------|
| **None** | No vibration alerts | - |
| **At Target Count** | Vibrates when you reach your goal | Vibrate at 100 push-ups |
| **Every X Increments** | Vibrates every N counts | Vibrate every 10 counts |

### Setting Up a Reminder

1. Create or edit an item
2. Choose **Reminder (Vibration)** type:
   - "At Target Count" — vibrates when goal reached
   - "Every X Increments" — vibrates at intervals
3. Enter the **Reminder Value** (the count that triggers vibration)
4. Save

### How Reminders Work

- Your **device vibrates** (not your phone)
- Single vibration when a reminder condition is met (reaching target or hitting interval)
- Triple vibration when you reach an item's goal (takes priority over reminders)
- Works even without your phone nearby

---

## 9. Viewing Your Data

### Item Detail Page

Tap any item to see detailed analytics (the page title shows the item name):

- **Count Card** - Large count with goal progress ring, date info, and config stats (Per Press, Reminder)
- **Cycle Note** - Optional text note for each cycle (tap to edit, 250 character limit)
- **Activity** - Charts showing visual trends over time
- **Cycle History** - Table of all your tracking periods with counts and durations

When viewing a historical cycle, the count card shows that cycle's total and date range. Config stats (Per Press, Reminder) appear grayed out since they only apply to the current cycle.

### Understanding Reset Cycles

Every time you reset an item's count, a new **cycle** begins. This lets you track progress in separate periods.

**Example:** If you track push-ups and reset weekly, you'll have:
- Cycle 1: Week 1 counts
- Cycle 2: Week 2 counts
- Current Cycle: This week's counts

You can **name your cycles** and **add notes** to remember what each period was about (e.g., "Training block A" or "Started new routine").

### Filtering by Reset Cycle

Tap the **cycle selector chip** at the top of the item detail page to open a bottom sheet where you can:

- **Select a cycle** to view its data
- **Rename cycles** by tapping the edit icon next to any cycle name
- **See All Time** summary across all cycles

| Option | What It Shows |
|--------|---------------|
| **All Time** | Complete history across all cycles |
| **Current Cycle** | Only counts since your last reset |
| **Previous cycles** | A specific named or numbered cycle |

The charts, statistics, and cycle note update based on your selected cycle.

### Cycle Notes

Each cycle can have an optional text note (up to 250 characters). Use notes to record context like why you started a new cycle or what changed.

- Tap the **"Add a note..."** area below the count card to start writing
- Tap **Done** or tap outside the text field to save
- Notes are saved per-cycle and hidden when viewing All Time
- Notes sync with your account and persist across devices

### Understanding the Charts

**Bar Chart** (Activity)
- Shows how much you counted each day/hour
- Taller bars = more activity
- Tap a bar to see exact values

**Cumulative Chart** (Running Total)
- Shows your total count growing over time
- Bars grow taller as you count more
- Good for seeing overall progress

### Changing the Time Range

| Time Range | What It Shows |
|------------|---------------|
| **1D** | Hourly breakdown for one day |
| **7D** | Daily breakdown for one week |
| **30D** | Daily breakdown for one month |

### Refreshing Data

Pull down on the screen to refresh and get the latest data.

---

## 10. Exporting Your Data

Export your tracking data as a CSV file (opens in Excel, Google Sheets, etc.).

### How to Export

1. Go to **Account tab**
2. Tap **"Export My Data"**
3. Configure your export:
   - **Data Scope** - Total (all data) or Latest Cycle only
   - **Date Range** - Select start and end dates (only shown when "Total" is selected)
   - **Aggregation** - Raw or Daily (default: Daily)
   - **Items** - Tap to open a searchable picker and select which items to include (all selected by default)
4. Enter your **email address**
5. Review the **Export Preview** card to confirm your settings
6. Tap **"Export to Email"**

### Aggregation Options

| Level | What You Get |
|-------|--------------|
| **Raw** | Every single count event |
| **Daily** | Totals for each day |

### What's in the Export?

Your CSV file includes:
- Item names and categories
- Date column — labeled **"Date"** for daily or **"Timestamp"** for raw
- Event type and count values
- **Cycle number and cycle note** (raw export only) — if you've added notes to your cycles, they appear alongside each event

---

## 11. Managing Your Account

### Dark Mode

Toggle between light and dark themes:

1. Go to **Account tab**
2. Tap the **Dark Mode** switch

Your preference is saved automatically.

### Editing Your Profile

1. Go to **Account tab**
2. Tap **"Edit Profile"**
3. Update your name
4. Tap **Save**

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

### How Multi-Device Works

You can pair multiple Traxelos One devices to your account, but only **one device can be connected at a time**.

**Key points:**
- All your items automatically sync to whichever device is currently connected
- Items are tied to your **account**, not to a specific device — switching devices gives you the same items
- When you connect a different device, it receives the latest data from the app

> **Important:** If you count on Device A while offline, then connect Device B instead, Device A's offline counts become stale. The next time Device A connects, the app's data will overwrite Device A's local data. To avoid losing counts, always **sync your current device before switching to another one**.

### Starting a New Cycle

Reset all your counts to start fresh:

1. Connect your device (required — this option is disabled without a connection)
2. Go to **Account tab**
3. Tap **"Start New Cycle"**
4. Tap **"Start New Cycle"** to confirm

*This resets all counts to 0 on both app and device.*

### Restoring Deleted Items

1. Go to **Account tab**
2. Tap **"Recently Deleted"**
3. Find the item you want back
4. Tap **"Restore"** (device connection required)

Items stay in Recently Deleted for 90 days before permanent deletion.

*Note: Restored items are placed in "Uncategorized" regardless of their original category. You can reassign them to a category by editing the item after restoring.*

### Help & Support

1. Go to **Account tab**
2. Tap **"Help & Support"**

On this page you can:
- Browse **Frequently Asked Questions** about using your device
- Tap **"Email Support"** to contact us directly

**Support Email:** support@digi1st.com

### Logging Out

1. Go to **Account tab**
2. Scroll to bottom
3. Tap **"Log Out"**
4. Confirm by tapping **"Sign Out"**

### Deleting Your Account

**Warning: This is permanent!**

1. Go to **Account tab**
2. Scroll to "Danger Zone"
3. Tap **"Delete Account"**
4. Read the device notice and tap **"Delete"**
5. Type **DELETE** to confirm
6. Tap **"Delete Account"** — all your data will be permanently deleted

**Device behavior:**
- **Connected:** The device is automatically unpaired and reset, and can be paired to a new account immediately.
- **Not connected:** You must factory reset the device before it can be paired to another account. On device: hold **both A and B buttons for 7 seconds**.

---

## 12. Tips & Tricks

### Get the Most Out of Traxelos One

1. **Keep your device charged** - Low battery can cause connection issues

2. **Time syncs automatically** - Your device syncs its clock when it connects via Bluetooth. Keep your phone's clock accurate for correct timestamps.

3. **Use categories** - Organize items for easier filtering

4. **Set realistic goals** - Start small and increase over time

5. **Check your charts weekly** - Spot patterns and trends

6. **Export monthly** - Keep a backup of your data

### Battery Saving

Your device has two power modes:
- **Active** - Fast response when you're counting
- **Low Power** - Saves battery when idle for 5+ minutes

The device switches automatically - no action needed!

---

## 13. Troubleshooting

### "I can't find my device"

1. Make sure Bluetooth is **ON** on your phone
2. Check that your device is **powered on** and **charged**
3. Move closer to your device (within 10 feet / 3 meters)
4. Try **restarting the app**
5. Try **restarting your device** (power off and on)

### "My device keeps disconnecting"

1. Check battery level on your device
2. Stay within range (Bluetooth has limited distance)
3. Close other Bluetooth-heavy apps
4. On Android: Disable battery optimization for Traxelos One

### "My counts aren't syncing"

1. Check connection status in the Bluetooth tab
2. Disconnect and reconnect your device to trigger a fresh sync
3. Pull-to-refresh on the Items page

### "I lost my counts!"

Don't panic! Your counts are stored in multiple places:
- On your device (survives power loss)
- In the cloud (synced from app)
- In Recently Deleted (if you deleted an item)

Try:
1. Reconnect your device
2. Wait for sync to complete
3. Check Recently Deleted for missing items

### "The time on my device is wrong"

Time syncs automatically when your device connects via Bluetooth. If the time seems wrong:
1. Disconnect your device
2. Reconnect — time will sync automatically
3. Your device will update to your phone's time

### "I forgot my password"

1. On the login screen, tap **"Forgot password?"**
2. Enter your email
3. Check your inbox for a reset link
4. Create a new password

### Still Need Help?

1. Go to **Account > Help & Support**
2. Browse the FAQ section
3. Tap **"Email Support"** to contact us

**Support Email:** support@digi1st.com

---

## Quick Reference Card

### Navigation

| Tab | Icon | What It Does |
|-----|------|--------------|
| **Home** | House | View and manage all items |
| **Bluetooth** | Bluetooth | Connect and manage your device |
| **Account** | Person | Account, settings, export, support |

### Device Buttons — Arduino IDE (Serial Monitor)

| Key | Action |
|-----|--------|
| U | Increment — Add to count |
| S | Switch — Change item |
| R | Reset — Reset to zero, start new cycle |
| F | Factory Reset — Restore to factory settings |

### Device Buttons — Traxelos One Device

| Button | Interaction | Action |
|--------|-------------|--------|
| A | Press | Add to count / Confirm selection / Wake device |
| A | Hold 3s | Show time, category, and item info |
| B | Press | Enter menu / Next item |
| B | Hold | Rapidly loop through items |
| B | Hold 3s | Reset item count (new cycle) |

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
| Restore deleted | Account > Recently Deleted (requires device) |
| Connect device | Bluetooth > Find Device |
| Sync time | Automatic on device connect |

---

**Thank you for using Traxelos One!**

One button. Instant count. Full insights.
