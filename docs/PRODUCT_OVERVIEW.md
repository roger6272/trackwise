# Traxelos One Product Overview

## What is Traxelos One?

Traxelos One is a **physical counter device with companion mobile app** that enables hands-free tracking of habits, inventory, or any countable activity. Unlike app-only solutions, Traxelos One combines a dedicated ESP32-based hardware counter with a feature-rich Flutter app, allowing users to track with a physical button press while maintaining full analytics and cloud synchronization.

---

## The Problem

Traditional counting and habit tracking solutions have significant limitations:

- **App-only solutions** require pulling out your phone, unlocking it, and navigating to the app for each count - creating friction that leads to missed tracking
- **Mechanical tally counters** are simple but offer no data persistence, analytics, or synchronization
- **Smart devices** often lack the specialized features needed for serious counting workflows (goals, reminders, categories, export)

---

## The Solution

Traxelos One bridges the gap between physical simplicity and digital intelligence:

| Physical Device | Mobile App |
|----------------|------------|
| Instant button-press counting | Full data management |
| Haptic feedback on goals and reminders | Analytics and charts |
| Works without phone nearby | Cloud sync and backup |
| Daily auto-reset at midnight | CSV data export |
| Remembers counts through power loss | Goal tracking and reminders |

---

## Key Features

### 1. Hardware Counter Device
- **ESP32-based** BLE peripheral with button input
- **Real-Time Clock (DS3231)** for accurate timestamps and daily resets
- **Vibration motor** for haptic feedback on goals and reminders
- **Persistent storage** - counts survive power loss
- **Multi-item support** - switch between items directly on device

### 2. Multi-Item Tracking
- Track up to 100 items (habits, inventory, activities)
- Each item maintains:
  - **Cumulative count** (total across all time)
  - **Today count** (auto-resets at midnight)
  - **Reset history** with timestamps
  - **Custom increment value** (1-1000 per press)

### 3. Smart Reminders
- **Goal reached** - triple vibration when hitting your goal count
- **Target reminders** - vibrate when reaching a reminder target
- **Interval reminders** - vibrate every N increments
- Haptic feedback keeps you aware without looking at your phone

### 4. Organization with Categories
- Group items into categories (e.g., "Fitness", "Work", "Health")
- Filter and view items by category
- Drag-to-reorder for custom sorting

### 5. Real-Time BLE Synchronization
- Instant sync between device and app
- Auto-reconnect on unexpected disconnection during active session
- Time synchronization ensures accurate timestamps
- Works offline - syncs when reconnected

### 6. Analytics and Charts
- Bar charts with multiple aggregation levels (Hourly / Daily / Weekly / Monthly)
- Statistics: period totals, percent change vs prior period
- View trends and patterns over time

### 7. Data Export
- Export to CSV with customizable date range and aggregation
- Share via email or save locally

### 8. Cloud Backup
- All data stored in Firebase Firestore
- Multi-device access with same account
- 90-day soft delete recovery period

---

## Unique Differentiators

### vs. App-Only Solutions (Streaks, Habitica, etc.)
- **Lower friction** - single button press vs unlock/navigate/tap
- **Hands-free counting** - don't need your phone
- **Haptic feedback** - physical confirmation
- **Physical satisfaction** - tactile experience

### vs. Mechanical Tally Counters
- **Data persistence** and analytics
- **Multiple items** on one device
- **Cloud sync** and backup
- **Smart reminders** and goals

### vs. Smart Buttons (Flic, etc.)
- **Purpose-built** for counting workflows
- **Built-in analytics** app
- **On-device item switching**
- **Daily reset logic** built in

---

## Use Cases

- **Habit Tracking**: Water intake, exercise reps, meditation sessions
- **Inventory Management**: Stock counts, audit tallying, shipment tracking
- **Professional Counting**: Lab samples, event attendance, QC checks
- **Personal Productivity**: Pomodoro sessions, task completion

---

## Summary

**One button. Instant count. Full insights.**

Traxelos One solves the friction problem in habit and inventory tracking by combining the simplicity of a physical button with the intelligence of a modern app.
