# ADR-001: Separate event and item_delta Notifications

**Status:** Accepted
**Date:** 2026-01-27
**Context:** BLE Protocol - Device to App notifications

## Problem

When a user presses a button on the device, the firmware sends TWO notifications to the app:

1. `event` - Contains: event type, timestamp, itemId, count, increment, resetNumber
2. `item_delta` - Contains: id, count, todaycount, lastResetTime, resetNumber

Both contain `count` and `resetNumber`, appearing redundant. Should we merge them into a single notification to reduce BLE traffic?

## Decision

Keep them as separate notifications. Do NOT merge them.

## Rationale

### They serve different purposes

| Notification | Purpose | Consumer |
|--------------|---------|----------|
| `event` | Record what happened | History, logging, analytics |
| `item_delta` | Sync current state | UI display, state management |

### They contain different fields

| Field | `event` | `item_delta` | Why |
|-------|:-------:|:------------:|-----|
| timestamp | ✓ | ✗ | Only matters for history |
| event type | ✓ | ✗ | Only matters for history |
| increment | ✓ | ✗ | Only matters for history |
| **todaycount** | ✗ | ✓ | Needed for daily progress UI |
| **lastResetTime** | ✗ | ✓ | Needed to detect daily resets |

### They have different sending patterns

- **increment/reset button:** Both `event` AND `item_delta` sent
- **switch button:** Only `event` sent (no state change for switched-from item)
- **set_selected command:** Only `item_delta` sent (no action occurred)

### Alternatives considered

1. **Merge all fields into `event`**
   - Rejected: Bloats every event with UI state fields
   - `event` becomes a hybrid concept (action + state)

2. **Have app compute todaycount locally**
   - Rejected: App would need to track lastResetTime and apply timezone logic
   - Device is source of truth for counts - should also be source for derived values

## Consequences

### Positive
- Clear separation of concerns (action vs state)
- Each notification is focused and minimal
- `item_delta` can be reused for non-action scenarios (set_selected response)
- Easier to add fields to one without affecting the other

### Negative
- Two notifications per button press (~2x BLE traffic for button events)
- Developers may initially think they're redundant

### Neutral
- App code needs to handle both notification types
- Both are small payloads (~100-150 bytes each), so traffic impact is minimal

## References

- `firmware/Trackwise_ESP32/Trackwise_ESP32.ino` - `notifyEvent()` and `notifyItemDelta()` functions
- `docs/BLE_PROTOCOL.md` - Sections 5.2 and 5.3
