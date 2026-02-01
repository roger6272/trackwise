# Traxelos One Device Display Reference

> **For developers:** This document describes the physical device's display states, layouts, and transitions. For app-device communication, see `BLE_PROTOCOL.md`. For end-user instructions, see `USER_GUIDE.md`.

---

## Device Layout

The Traxelos One is a handheld device with a large front-facing display and two buttons.

```
        ┌──────────────────────┐
        │  ┌────────────────┐  │
        │  │   [Button A]   │  │  ← Front face, above display
        │  │  (Count/Main)  │  │     Large, primary action button
        │  └────────────────┘  │
        │                      │
  [B] ──┤  ┌────────────────┐  │
        │  │                │  │
        │  │                │  │
        │  │    DISPLAY     │  │
        │  │                │  │
        │  │                │  │
        │  └────────────────┘  │
        │                      │
        └──────────────────────┘
```

### Button A — Front Face (Above Display)

- **Position:** Large button on the front face, above the display
- **Purpose:** Primary action — counting, confirming, waking
- **Design:** Big, tactile, satisfying to press repeatedly
- **Why here:** Thumb lands naturally on the front face when gripping the device. Direct downward press is ergonomic for high-frequency use (hundreds of presses per day).

### Button B — Left Side (Upper Edge)

- **Position:** Upper left side of the device (from the user's perspective)
- **Purpose:** Secondary action — menu navigation, reset
- **Design:** Slightly recessed/flush to prevent accidental presses
- **Why here:** Right-handed grip places the index finger naturally on the upper left edge. Distinct from A by feel. Recessed profile avoids accidental resets (B hold 3s triggers reset).

### Ergonomic Grip

When holding with the right hand:
- **Thumb** → Button A (front face)
- **Index finger** → Button B (left side)
- Both buttons operable without shifting grip

---

## Display States

### 1. Welcome / Pairing Screen

**When:** Device powers on before pairing.

**Display sequence:**
1. **"Welcome"** text — shown for 2-3 seconds as a greeting
2. **Bluetooth icon + "Pairing..."** — stays on screen until a Bluetooth connection is made

**Exits to:**
- Main Item View (on successful BLE connection)
- Sleep Mode (after 5 mins of inactivity if no connection is made)

---

### 2. Main Item View

**When:** Default view after pairing/connecting. Returns here after menu timeout.

**Display layout:**

```
┌──────────────────────────┐
│ Push..     🎯 📶 🔋       │  ← Top bar
│                          │
│                     x5   │  ← Count per press (small, right)
│          247             │  ← Count (large, centered)
│                          │
│                          │
└──────────────────────────┘
```

| Element | Position | Details |
|---------|----------|---------|
| Item name | Top left | Truncated to 5 characters + dot if longer (e.g., "Push..", "Water", "Squat") |
| Battery icon | Top right | Battery level indicator |
| Bluetooth icon | Top right | Shown when connected |
| Reminder icon | Top right | Indicates reminder type: none / target / interval |
| Count per press | Upper right (count area) | Shown as "x5" — hidden when default (1) |
| Count | Center | Large, takes up most of the display |

**States:**
- **Item active:** Shows layout above with count of the current selected item
- **No item active:** "Select an item" — shown when no item has been activated in the app yet (e.g., fresh pair, no items created)

*Note: Only items from the active item's category are synced to the device. The user selects an item in the app, which triggers the category's items to sync over.*

**Interactions:**
| Input | Result |
|-------|--------|
| A press | Increment count → display updates |
| A hold 3s | Switch to [Info Display](#4-info-display) |
| B press | Enter [Item Menu View](#3-item-menu-view) |
| B hold 3s | Reset current item count (new cycle) |
| 5 mins inactivity | Enter [Sleep Mode](#5-sleep-mode) |

---

### 3. Item Menu View

**When:** B pressed from Main Item View.

**Display layout:**

```
┌──────────────────────────┐
│ Fitness..            3/5 │  ← Category (10 char + dot) + position
│──────────────────────────│
│   Water                  │
│ ▸ Push-ups               │  ← Selected (arrow)
│   Squats                 │
│   Bench Press            │
│   Pull-ups               │
└──────────────────────────┘
```

| Element | Position | Details |
|---------|----------|---------|
| Category name | Top left | Truncated to 10 characters + dot if longer |
| Position counter | Top right | Current item / total items (e.g., "3/5") |
| Item list | Center | Up to 5 items visible at a time |
| Selected item | Center | Indicated by a small arrow (▸) at the start |
| Long item names | — | Carousel/scroll effect if name exceeds display width |

**Interactions:**
| Input | Result |
|-------|--------|
| A press | Confirm selection → return to [Main Item View](#2-main-item-view) with selected item |
| B press | Next item in menu (loops through list) |
| B hold | Rapidly loop through items |
| 5 secs inactivity | Auto-return to [Main Item View](#2-main-item-view) |

---

### 4. Info Display

**When:** A held for 3 seconds from Main Item View.

**Display layout:**

```
┌──────────────────────────┐
│ Cat: Fitness             │
│ Item: Push-ups           │
│ Goal: 100  Today: 45     │
│ Remind: 🎯 100           │
│ Cycle: 3        12:30 PM │
└──────────────────────────┘
```

| Element | Details |
|---------|---------|
| Category | Full name, carousel if too long |
| Item | Full name, carousel if too long |
| Goal | Target count (if set) |
| Today | Today's count |
| Reminder | Icon + value: 🎯 100 (target), 🔄 10 (interval), or "None" |
| Cycle | Current reset cycle number |
| Time | Current time (bottom right) |

**Duration:** 10 seconds or until any button is pressed.

**Exits to:** [Main Item View](#2-main-item-view)

---

### 5. Sleep Mode (Power Saving)

**When:** 5 minutes of inactivity from Main Item View.

**Display:** Off

**Interactions:**
| Input | Result |
|-------|--------|
| A or B press | Wake → return to [Main Item View](#2-main-item-view) |

---

### 6. Factory Reset

**When:** Both A and B held for 7 seconds.

**Display:**

```
┌──────────────────────────┐
│                          │
│   Factory Reset?         │
│   A=Yes  B=No            │
│                          │
└──────────────────────────┘
```

| Input | Result |
|-------|--------|
| A press | Confirm — erase all data, return to [Welcome / Pairing Screen](#1-welcome--pairing-screen) |
| B press | Cancel — return to [Main Item View](#2-main-item-view) |
| 10 secs inactivity | Auto-cancel — return to [Main Item View](#2-main-item-view) |

**Result (if confirmed):** All items, counts, and pairing information erased. Device returns to Welcome / Pairing Screen.

---

## State Transition Diagram

```
                    ┌─────────────┐
                    │  Welcome /  │
                    │  Pairing    │
                    └──┬───────┬──┘
              BLE pair │       │ 5min inact.
                       ▼       ▼
    ┌───────────────────────┐  ┌──────────┐
    │    Main Item View     │  │  Sleep   │
    │                       │◄─│  Mode    │ (A/B press = wake)
    └──┬──────┬─────────┬───┘  └──────────┘
       │      │         │            ▲
A hold │  B   │   5min  │            │
  3s   │press │  inact. │            │
       │      │         └────────────┘
       ▼      ▼
┌──────────┐  ┌─────────────────┐
│   Info    │  │   Item Menu     │
│ Display   │  │     View        │
└──────────┘  └────────┬────────┘
 (10s/press)     B press/hold
       │        (cycle items)
       │              │
       │         A press (confirm)
       │         or 5s timeout
       │              │
       └──────┬───────┘
              ▼
       Back to Main Item View

  A+B hold 7s (from any state)     Unpair command
              │                     (from any state)
              ▼                           │
       ┌─────────────┐                    │
       │  Factory    │──────► Welcome / Pairing ◄──┘
       │  Reset      │
       └─────────────┘
```

---

## Display Hardware

| Spec | Value |
|------|-------|
| Type | OLED (SSD1306) |
| Size | ~1.3" |
| Resolution | 128×64 pixels |
| Color | Monochrome (white on black) |

---

## Behavior Notes

### Increment Feedback
No animation or flash — the count simply updates on the display immediately.

### Vibration Feedback

| Event | Pattern | Details |
|-------|---------|---------|
| Reminder target hit | Single vibration (300ms) | Count equals reminder target value |
| Reminder interval hit | Single vibration (300ms) | Count is a multiple of the interval value |
| Goal reached | Triple vibration (3× 150ms, 100ms gap) | Count equals the item's goal |

Goal vibration takes priority — if the goal and a reminder trigger on the same press, only the triple vibration plays.

### Reset Feedback
No confirmation message — the count drops to 0 on the display immediately.

### Item Menu with Fewer Than 5 Items
Items are top-aligned. If the category has only 2 items, 2 rows are shown at the top with empty space below.

---

### Transient Notifications

These are brief overlay messages shown on the device display for ~3 seconds before auto-dismissing back to the previous state. They do not change the underlying display state.

| Notification | Trigger | Display | Duration |
|-------------|---------|---------|----------|
| **Connected** | BLE connection established | Bluetooth icon + "Connected" | 3 seconds |
| **Disconnected** | BLE connection lost | Crossed-out Bluetooth icon + "Disconnected" | 3 seconds |
| **Wrong Account** | A different account (not the paired one) connects | "Wrong Account" | 3 seconds |
| **Conflict / See App** | User presses button while a sync conflict exists | "Conflict" + "See App" (two lines) | 3 seconds |
| **Memory almost full** | NVS usage ≥ 90% | "Memory almost full. Please sync." | 3 seconds (once per wake) |
| **Storage full** | NVS usage = 100% | "Storage full. Sync now." | Shown on every A press (blocks counting) |

All transient notifications include a brief vibration. The device continues working offline after disconnection. Syncing via Bluetooth clears storage warnings.

### Unpair Command

When the device receives an unpair command from the app (e.g., account deletion or manual unpair):
- All items, counts, and pairing information are erased
- Device returns directly to [Welcome / Pairing Screen](#1-welcome--pairing-screen)

### Low Battery

No special warning or flashing. The battery icon on the main display already shows the current level — the user can see when it's low. The device powers off when the battery is depleted.
