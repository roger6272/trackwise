# ADR-009: Auto-reconnect drops a reset or re-owned device silently

**Status:** Accepted
**Date:** 2026-09-28
**Context:** BluetoothBloc reconnect handling after a handshake returns `uninitialized` or `wrong_account`

## Problem

After a factory reset the device has no owner until someone completes Set Up — whoever does it first owns it. The previous owner's app keeps retrying the connection in the background (backoff capped at 60s, no attempt limit) and, on reaching the device, showed the Set Up dialog (`uninitialized`) or the wrong-account dialog (`wrong_account`).

Both caused harm when the device was changing hands:
- A Set Up dialog on the **old** owner's phone invites them to re-claim a device someone else is setting up.
- The firmware accepts one connection and only re-advertises on disconnect, so the old phone holding the link — waiting on a dialog the old owner may never see — blocks the new owner from connecting.

## Decision

When a connection was started by a **background reconnect timer** and the handshake returns `uninitialized` or `wrong_account`, the app shows nothing: it disconnects as a manual disconnect (no further retries) and releases the device's claims. `ConnectToDevice.isAutoReconnect` carries the origin; `DeviceOwnershipLost` does the drop.

When the **user** taps Connect, behavior is unchanged: Set Up dialog or wrong-account dialog.

## Rationale

The person who reset the device knows they did it. The person who didn't reset it is exactly the one who must not be prompted to set it up. So the prompt only adds value when the user asked to connect.

Alternatives rejected:
- **A notice ("device was reset — tap to set up").** Shown to the old owner it's the same invitation to re-claim, one tap removed. Saves one tap in the self-reset case only.
- **Physical confirmation on the device (button press to accept Set Up).** Closes the race fully, but is a firmware + protocol change for the nRF port, for a mild nuisance on a tally counter.

The OTA-reboot reconnect is deliberately **not** marked auto: it continues an update the user started.

## Consequences

### Positive
- The new owner is never blocked by the old owner's phone.
- The old owner is never prompted to take back a device they gave away.

### Negative
- Self-reset takes one extra step: the device shows as disconnected and the user taps Connect before Set Up appears.
- If the device was reset *without* the old owner knowing, they get no explanation — it just stays disconnected in Paired Devices until they tap Connect (which then shows the real status) or unpair it.

### Neutral
- The device stays in the old owner's Paired Devices list; nothing removes it automatically.

## References

- `BluetoothBloc._performInitialSync`, `_onDeviceOwnershipLost`
- `docs/TROUBLESHOOTING.md` §10.15
- `docs/BLE_PROTOCOL.md` §4.2 (handshake status → app action)
