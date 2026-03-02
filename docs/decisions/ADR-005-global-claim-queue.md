# ADR-005: Global Claim Queue Instead of Per-Device Queues

**Status:** Accepted
**Date:** 2026-03-01
**Context:** `_claimQueue` in `bluetooth_bloc.dart`

## Problem

When two devices switch items nearly simultaneously, per-device claim queues allow concurrent Firestore transactions that read stale `claimed_by` state. Device B's release hasn't committed when Device A's claim reads the document, causing `ClaimConflictException` and app-device desync.

## Decision

Replace per-device `Map<String, Future<void>> _claimQueues` with a single `Future<void> _claimQueue` that serializes ALL claim operations across all devices.

## Alternatives Considered

### 1. Retry on ClaimConflictException
Re-read Firestore and retry the claim after conflict. Rejected because:
- Adds complexity for 3+ device edge cases (cascading retries)
- Retry timing is hard to tune — too fast wastes quota, too slow feels sluggish
- Doesn't prevent the race, just recovers from it

### 2. Firestore-side serialization (Cloud Function)
Move claim logic to a Cloud Function with server-side locking. Rejected because:
- Adds infrastructure dependency and latency (~200ms cold start)
- Overkill — claims are already rare events, global queue is sufficient

## Consequences

- **Positive:** Eliminates all cross-device claim race conditions
- **Negative:** Adds ~50ms latency per claim when multiple devices claim simultaneously (one waits for the other). Acceptable because item switching is infrequent (~seconds apart) and the latency is imperceptible.
- **Neutral:** Per-device cleanup (`_claimQueues.remove(deviceId)`) is no longer needed on disconnect/unpair, simplifying cleanup code.
