# ADR-003: Debounce Updates Signature Without Sending

**Status:** Accepted
**Date:** 2026-02-01
**Context:** App-side device sync deduplication in `items_list_page.dart`

## Problem

The app tracks a `_lastSyncedSignature` to avoid sending duplicate `set_items` commands to the device. A 500ms debounce prevents rapid-fire syncs. The question: when a sync is debounced (skipped), should the signature be updated?

Two valid-sounding approaches:
1. **Don't update signature during debounce** — so the debounced change gets retried on the next `buildWhen`
2. **Always update signature** — so future comparisons use the latest known state

## Decision

Always update `_lastSyncedSignature` and `_lastSyncedCategoryId`, even when the send is debounced.

## Rationale

Approach 1 (the original code) caused a subtle bug:

1. Item move triggers sync → signature updated → `_lastSyncTime` set
2. Firestore stream confirms the move within 500ms → `buildWhen` fires → debounce skips send → **signature NOT updated**
3. Firestore confirmation has slightly different `categoryOrder` values than the optimistic state
4. `_lastSyncedSignature` is now stale (from step 1, not step 2)
5. Next unrelated state change (e.g., count increment) → debounce expired → stale signature mismatches → **unnecessary duplicate sync**

The core insight: the signature tracks "what state does the device have?" not "what state did we last send?" After the first sync in step 1, the device already has the correct items. The Firestore confirmation in step 2 doesn't change what the device has — it just changes internal `categoryOrder` numbering. Updating the signature acknowledges this without re-sending.

## Rejected Alternative

"Don't update signature during debounce" sounds correct in isolation — debounce should defer work, not discard it. But in this case, the debounced state (Firestore confirmation) doesn't represent a *new* change that needs syncing. It's the *same* change confirmed by the server, potentially with trivial field differences. Treating it as "deferred work" causes a false positive on the next real change.

## Consequences

- Debounced Firestore confirmations no longer cause stale signature mismatches
- If a *real* change arrives during debounce and has identical signature to the debounced state, it will be skipped — but this is correct because the device already has equivalent data from the first sync
