# Phase 5: Firmware Switch Guard & Display — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Guard item switching when the device is offline (not connected to the app) and display a two-line OLED message. Implement production `displayMessage()` rendering.

**Architecture:** Add an `isConnected` guard in the `cmd == 's'` handler (after the `total == 0` check). Implement `displayMessage()` to render text on the 128x64 SSD1306 OLED. No BLE protocol or payload format changes.

**Tech Stack:** C++ (Arduino/ESP32), SSD1306 OLED (128x64, I2C), Adafruit SSD1306 + Adafruit GFX libraries

**Important:** The current `displayMessage()` at line 369 is a debug-only stub (`DEBUG_LOG` only). This plan replaces it with actual OLED rendering. The OLED hardware integration (library includes, I2C init, display object) may need to be added if not already present.

---

### Task 1: Verify OLED Hardware Setup

**Files:**
- Read: `firmware/Trackwise_ESP32/Trackwise_ESP32.ino`

**Step 1: Check if SSD1306/display libraries are already included**

Search the firmware file for:
- `#include <Adafruit_SSD1306.h>` or `#include <SSD1306.h>` or similar
- `#include <Adafruit_GFX.h>`
- Any `display` object declaration
- I2C pin definitions for the OLED

If NOT present, this task adds them. If already present, skip to Task 2.

**Step 2: Add OLED library includes and display object (if needed)**

Near the top of the file with other includes:
```cpp
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>

#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
#define OLED_RESET -1  // No reset pin (shared with ESP32 reset)
#define SCREEN_ADDRESS 0x3C  // Common I2C address for 128x64 SSD1306

Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);
```

In `setup()`, add OLED initialization:
```cpp
  // Initialize OLED display
  if (!display.begin(SSD1306_SWITCHCAPVCC, SCREEN_ADDRESS)) {
    DEBUG_PRINTLN("⚠️ SSD1306 allocation failed");
  }
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);
  display.display();
```

**Step 3: Add library dependencies to platformio.ini (if using PlatformIO)**

```ini
lib_deps =
    adafruit/Adafruit SSD1306
    adafruit/Adafruit GFX Library
```

**Step 4: Compile to verify**

Run: PlatformIO build or Arduino IDE compile
Expected: Compiles without errors

**Step 5: Commit**

```
feat(firmware): add SSD1306 OLED display initialization
```

---

### Task 2: Implement Production `displayMessage()`

**Files:**
- Modify: `firmware/Trackwise_ESP32/Trackwise_ESP32.ino` (line 369)

**Step 1: Replace the stub with actual OLED rendering**

Replace the current stub (lines 369-371):
```cpp
void displayMessage(const char* msg) {
  DEBUG_LOG("📺 DISPLAY: %s\n", msg);
}
```

With a two-line-capable display function:
```cpp
// Display a message on the OLED screen.
// Supports two lines separated by '\n'. Text is centered on each line.
// Line 1: size 2 (large), Line 2: size 1 (small).
void displayMessage(const char* msg) {
  DEBUG_LOG("📺 DISPLAY: %s\n", msg);

  display.clearDisplay();

  // Split on newline if present
  const char* newline = strchr(msg, '\n');

  if (newline != NULL) {
    // Two-line mode
    char line1[32];
    int line1Len = newline - msg;
    if (line1Len > 31) line1Len = 31;
    strncpy(line1, msg, line1Len);
    line1[line1Len] = '\0';
    const char* line2 = newline + 1;

    // Line 1: large text, centered vertically in top half
    display.setTextSize(2);
    int16_t x1, y1;
    uint16_t w1, h1;
    display.getTextBounds(line1, 0, 0, &x1, &y1, &w1, &h1);
    display.setCursor((SCREEN_WIDTH - w1) / 2, 8);
    display.print(line1);

    // Line 2: small text, centered vertically in bottom half
    display.setTextSize(1);
    int16_t x2, y2;
    uint16_t w2, h2;
    display.getTextBounds(line2, 0, 0, &x2, &y2, &w2, &h2);
    display.setCursor((SCREEN_WIDTH - w2) / 2, 44);
    display.print(line2);
  } else {
    // Single-line mode: large centered text
    display.setTextSize(2);
    int16_t x1, y1;
    uint16_t w1, h1;
    display.getTextBounds(msg, 0, 0, &x1, &y1, &w1, &h1);
    display.setCursor((SCREEN_WIDTH - w1) / 2, (SCREEN_HEIGHT - h1) / 2);
    display.print(msg);
  }

  display.display();
}
```

**Step 2: Compile to verify**

Expected: Compiles without errors

**Step 3: Commit**

```
feat(firmware): implement OLED displayMessage with two-line support
```

---

### Task 3: Add Switch Guard When Offline

**Files:**
- Modify: `firmware/Trackwise_ESP32/Trackwise_ESP32.ino` (line 2383, cmd == 's' handler)

**Step 1: Add isConnected guard after total == 0 check**

Current code (lines 2383-2387):
```cpp
  } else if (cmd == 's') {
    if (total == 0) {
      nvsEndSafe();
      return;
    }
```

Change to:
```cpp
  } else if (cmd == 's') {
    if (total == 0) {
      nvsEndSafe();
      return;
    }

    // Fixed-task constraint: cannot switch items when offline
    if (!isConnected) {
      nvsEndSafe();
      displayMessage("SWITCH DISABLED\nSYNC TO APP");
      DEBUG_PRINTLN("⛔ Item switch blocked - device offline");
      return;
    }
```

Note: `nvsEndSafe()` must be called before `displayMessage()` because NVS prefs were opened at the start of `handleCommand()`. The display function doesn't need NVS access.

**Step 2: Compile to verify**

Expected: Compiles without errors

**Step 3: Commit**

```
feat(firmware): guard item switch behind isConnected flag
```

---

### Task 4: Update Existing displayMessage Calls

**Files:**
- Modify: `firmware/Trackwise_ESP32/Trackwise_ESP32.ino`

**Step 1: Audit all existing displayMessage calls**

Search for all `displayMessage(` calls in the firmware. Known calls:
- `displayMessage("SEE APP")` (conflict state, line ~379)
- Any others found during search

These existing calls should continue to work with the new implementation — they're single-line messages that will be centered on the OLED.

**Step 2: No code changes expected**

Existing calls use single-line strings, which the new `displayMessage()` handles in its single-line mode. No changes needed.

**Step 3: Compile full firmware**

Expected: Compiles without errors

---

### Task 5: Handle "No Item Selected" Display

**Files:**
- Modify: `firmware/Trackwise_ESP32/Trackwise_ESP32.ino`

**Step 1: Find where the device handles receiving an empty item list**

Search for where `item_total` is set to 0 (after receiving `set_items` with empty list). The device should display a "no item selected" message when it has no items.

Look in:
- The `set_items` BLE handler
- The `setSelectedItem` function (line ~656)

**Step 2: Add display call when item list becomes empty**

In the `setSelectedItem` function, after the `total == 0` branch sets `currentDeviceItemId = -1` (line ~658):
```cpp
    displayMessage("NO ITEMS\nSYNC TO APP");
```

**Step 3: Compile to verify**

Expected: Compiles without errors

**Step 4: Commit**

```
feat(firmware): display message when device has no items
```

---

### Task 6: Final Verification

**Step 1: Full compile**

Run full firmware compile.
Expected: Compiles without errors or warnings

**Step 2: Review all displayMessage calls work with new implementation**

Verify:
- "SEE APP" (conflict) → single-line centered
- "SWITCH DISABLED\nSYNC TO APP" (offline switch) → two-line
- "NO ITEMS\nSYNC TO APP" (empty list) → two-line

**Step 3: Commit and push**

```
git push -u origin feature/multi-device-ble
```

---

## Notes

- **No automated tests for firmware** — verification is compile + manual testing on device
- **OLED hardware dependency** — If the physical device doesn't have an OLED connected yet, Task 1 may need adjustments for the specific I2C pins and display model
- **displayMessage duration** — Messages persist on screen until the next display update (count change, item switch, etc.). No auto-clear timer needed — the normal display loop will overwrite when appropriate.
