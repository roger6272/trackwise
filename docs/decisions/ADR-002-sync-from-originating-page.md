# ADR-002: Sync Device from Originating Page, Not buildWhen

**Status:** Accepted
**Date:** 2026-01-28
**Context:** App → Device sync after cross-tab operations

## Problem

When a category is deleted from `manage_categories_page` (Profile tab), items in that category become uncategorized. If the device's selected item was in that category, the device needs updated items. But the reactive sync in `items_list_page` (Home tab) doesn't detect the change because:

1. `ShellRoute` disposes `items_list_page` on tab switch — the page and its BLoC don't exist during deletion
2. When the page is recreated on return, `_initSyncTracking` sets a baseline from the already-changed items — no diff detected, no sync fired

Why not just sync on every page creation? That causes unnecessary device traffic on every tab switch, and a duplicate `set_selected` command can reset the device's selection state.

## Decision

Sync the device from the page where the operation happens (`manage_categories_page`), not from `buildWhen` in `items_list_page`.

## Rationale

### buildWhen only works when the page is alive

`buildWhen` detects `ItemsLoaded → ItemsLoaded` transitions via signature comparison. This works for operations that happen while the items page is mounted (item create, edit, delete, drag, reset). It does NOT work for operations on other tabs because:

- `ShellRoute` (not `StatefulShellRoute`) disposes child pages on tab switch
- Tracking state (`_lastSyncedSignature`, `_lastSyncedCategoryId`) is lost on disposal
- `_initSyncTracking` on recreation sets baseline without syncing (by design — syncing on every page load causes duplicate traffic)

### The originating page knows what changed

`manage_categories_page` knows which category was deleted. It can:
1. Check if the device's selected item was in that category
2. Wait for the Firestore batch to propagate (500ms)
3. Fetch updated items and sync only if needed

This is targeted — no unnecessary syncs for unrelated category deletions.

### Pattern applies to any cross-tab operation

Any future operation on a non-Home tab that affects device state should follow this pattern:
- **Do the sync from the page where the operation happens**
- Don't rely on `buildWhen` detecting changes when the user returns

## Alternatives Considered

| Alternative | Why rejected |
|-------------|-------------|
| Always sync on page creation (`_initSyncTracking` with sync) | Causes unnecessary device traffic on every tab switch; duplicate `set_selected` resets device state |
| `StatefulShellRoute` to keep pages alive | Larger architectural change; pages would consume memory when not visible; other trade-offs |
| Listen to categories stream in `_initSyncTracking` | Complex; `_initSyncTracking` runs before categories are loaded; race condition prone |
| Store `_lastSyncedCategoryId` outside the page (e.g., AppUiState) | Leaks sync implementation details into global state; fragile across app lifecycle |

## Consequences

- Cross-tab operations that affect device state must include their own sync logic
- `syncItemsToDevice()` shared helper makes this straightforward (fetch items, fetch categories, call helper)
- `buildWhen` remains the primary sync mechanism for same-page operations
- `_initSyncTracking` remains baseline-only (no sync) to prevent duplicate traffic
