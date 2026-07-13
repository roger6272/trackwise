# ADR-008: After `ota_verified`, the update is irreversible — treat silence as success

**Status:** Accepted
**Date:** 2026-07-12
**Context:** OTA firmware updates (app + firmware). Read before "fixing" anything in the post-verification path.

## Problem

Three changes made on 2026-07-12 look like bugs on first reading, and a future developer (or a linter, or me) will be tempted to revert all three:

1. **The app ignores a failed `reboot` write.** It calls `sendReboot()`, and if the write fails it *logs and continues* instead of raising an error. This looks like swallowing an error — the exact anti-pattern a code review flags.
2. **The firmware does NOT abort an OTA when the link drops**, if it is in `OTA_VERIFIED`. Every other OTA state aborts on disconnect. This looks like a missing case.
3. **The firmware reboots immediately on that disconnect**, rather than letting the existing 10s auto-reboot timer handle it. This looks redundant.

All three are deliberate, and each one prevents a real, observed failure.

## Decision

**Once the device has sent `ota_verified`, the update has already happened.** The image is hashed, validated, and `esp_ota_set_boot_partition()` has committed it. The device *will* come up on the new firmware on its next reset, whatever anyone does next.

Therefore, after `ota_verified`:

- **A transport failure is not an update failure.** A missing ACK, a dropped link, a timeout — none of them can un-commit the image. The app treats silence as "it's rebooting," not "it broke."
- **The device must not abort.** Aborting drops it to `OTA_IDLE`, which also disables the auto-reboot — leaving it running the *old* firmware with the *new* one committed, and the app unable to tell the two apart.
- **The device must not idle.** It reboots at once, because the app reconnects on a fixed interval and would otherwise re-handshake with the old firmware still running out its countdown, read the old version, and report a rollback that never happened.
- **`ota_abort` must be refused** (`reason: "already_committed"`). Honouring it would tell the app "cancelled" and then boot the new firmware anyway.

The only thing that can still legitimately change the outcome is a **rollback** — the new image crashing before it finishes starting up. That is detected by comparing the version the device reports after reconnecting against the version we installed, which is why `publish_firmware.sh` must guarantee those two numbers agree.

## Rationale

Every OTA bug found in this audit was the same mistake: **the app inferring failure from silence.**

- It inferred failure from a missing `reboot` ACK — but the device restarts *because* it got the command, too fast to reply. **Every single successful update reported as failed.**
- It inferred failure from a 60s absence — but nRF's bootloader bank-swaps and is legitimately gone for 30–60s. And its timeout message told the user to **power-cycle**, which mid-swap is the one action that can genuinely damage the device.
- It inferred success from a reconnect — but a rolled-back device also reconnects, on the old firmware.

Silence after `ota_verified` carries no information about whether the update worked, because **the update already worked.** The only trustworthy signal is the version the device reports when it comes back.

**Alternatives rejected:**
- *Keep raising an error on a failed `reboot` write, but make the message softer.* Rejected: the error is simply false. The device is fine.
- *Abort on disconnect and let the user retry.* Rejected: the image is already committed, so "retry" would re-flash a device that is about to boot the new firmware anyway — and in the meantime it reports a version that matches neither.
- *Rely on the 10s auto-reboot after a disconnect instead of rebooting immediately.* Rejected: that countdown starts at **verification**, not at disconnect, so up to 10s can remain — and the app reconnects after 5s. It would read the old version and cry rollback.

## Consequences

### Positive
- A successful update reports as successful. Previously, none did.
- A genuine rollback is now detected instead of being reported as "Complete."
- Every path after `ota_verified` converges on the same place: the device boots the new firmware.

### Negative
- The app can no longer distinguish "the reboot command was lost" from "the reboot command was delivered." It doesn't need to — the outcome is identical — but it does mean one less diagnostic signal.
- A rolled-back device is only detected on reconnect, so the user waits out the reboot window before seeing the failure.

### Neutral
- The rollback check depends on the device reporting the version it was **published** as. That is enforced by the version-drift guard in `publish_firmware.sh`. **If those two ever diverge again, this check reports false failures.** The two are load-bearing for each other.
- These are **behavioural requirements of the protocol**, not ESP32 implementation details. They are recorded in `BLE_PROTOCOL.md` §0, and the nRF port must honour all of them.
