# ADR-006: Allow BLE Messages During Handshaking State

**Status:** Accepted (refined 2026-05-15 — see Refinement section)
**Date:** 2026-03-04
**Context:** BLE sync state machine in bluetooth_bloc.dart

## Problem

The BLE message handler (`_onMessageReceived`) gates incoming device messages based on the device's sync status. The original gate blocked all messages when `!deviceState.isOnline` (i.e., when `syncStatus != synced`). This caused a deadlock:

1. Device sends handshake response → app sets status to `handshaking`
2. Firmware automatically sends prefs 100ms after handshake response
3. App receives prefs but drops it because status is `handshaking` (not `synced`)
4. Prefs receipt is what transitions status to `synced`
5. Deadlock: can't receive prefs until synced, can't sync until prefs received

## Decision

Allow BLE messages through during the `handshaking` state. Block messages only during states where device data is known to be unreliable:

- `staleClaim` — device has stale counts from items released while offline
- `setup` — device is being initialized
- `wrongAccount` — device belongs to a different user
- `syncing` — override is in progress, counts are being overwritten

## Rationale

**Why not block during handshaking?**
- Prefs messages during handshaking contain the device's current counts, which the app needs to reconcile with Firestore
- The handshake response itself confirms device identity and protocol version — prefs arriving after this are trustworthy
- In the legacy sync path (no internet/timeout), prefs receipt is the *only* way to reach `synced` status

**Why still block during other states?**
- `staleClaim`: counts reflect items the device no longer owns — syncing them would overwrite correct Firestore values
- `setup`/`wrongAccount`: device data is invalid for this user
- `syncing` (override): app is actively pushing data to device — incoming counts would race with the override

**Alternative considered:** Adding a separate "awaiting prefs" sub-state within handshaking. Rejected as over-engineered — the existing `handshaking` state already captures this semantic.

## Consequences

### Positive
- Fixes deadlock in legacy sync path
- Fixes race condition where prefs arrive before `HandshakeCompleted` event is processed
- No new states or complexity added

### Negative
- If firmware sends prefs with stale data during handshaking (before the handshake response confirms identity), those counts could briefly be applied. In practice this doesn't happen — firmware only sends prefs after the handshake response.

### Neutral
- The asymmetric gating (handshaking allowed, other non-synced states blocked) may surprise future developers — this ADR documents the reasoning

## References

- `lib/features/bluetooth/presentation/bloc/bluetooth_bloc.dart` lines 897-908
- `docs/TROUBLESHOOTING.md` §9.19, §10.13
- `lib/features/bluetooth/domain/entities/device_connection_state.dart` (isOnline getter)

## Refinement (2026-05-15)

The "Negative" section above predicted: *"If firmware sends prefs with stale data during handshaking (before the handshake response confirms identity), those counts could briefly be applied. In practice this doesn't happen — firmware only sends prefs after the handshake response."* This prediction was wrong.

**The case missed:** A user-initiated Path A unpair (three-dot menu → Unpair) only removes the device from the app's `paired_devices` array — it does **not** clear `paired_uid` on the device (the BLE `unpair` command is only sent during account deletion). When the user re-connects the device, its handshake returns `in_sync` because `paired_uid` matches the current user. ~100ms later firmware sends `notifyPrefsToApp` + `notifyLogsToApp` carrying the *old* item list and *old* `selectedDeviceItemId`. The handshaking-allowed gate let those messages through; `_syncDeviceData` mapped the old `deviceItemId` to a still-existing Firestore item and dispatched `ClaimItem`; `atomicClaimSwap` wrote `claim_by` back onto the just-unpaired device. The "in_sync but not in `pairedDevices` → `DeviceSetupRequired`" route at `_onHandshakeCompleted` (line 1610) raced the prefs and lost.

**Refinement applied:** A `pairedDevices` membership guard now runs at the top of `_onMessageReceived`, **before** the `syncStatus` gate decided in this ADR. The handshaking-allow rule still holds — but only for devices the app currently considers paired. Unknown devices (re-pair, unpair stragglers, or any other case where `state.pairedDevices` doesn't list the sender) have their messages dropped entirely.

This narrows ADR-006's "allow handshaking" rule from *unconditional* to *conditional on `pairedDevices` membership*. The original rationale (avoid legacy-sync deadlock, handle prefs-before-HandshakeCompleted) still applies for known devices.

**Why this didn't surface earlier:** The race depends on the user-initiated Unpair path leaving `paired_uid` set on the device. The original ADR was written when account-deletion (which DOES send the `unpair` BLE command) was the only unpair surface; UI-button Unpair was added later (see `bluetooth_page.dart:457`).
