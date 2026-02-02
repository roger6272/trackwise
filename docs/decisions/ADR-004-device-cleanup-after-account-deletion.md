# ADR-004: Device Cleanup After Account Deletion, Not Before

**Status:** Accepted
**Date:** 2026-02-01
**Context:** Delete account flow in `profile_page.dart`

## Problem

When a user deletes their account, the connected device should be factory reset (unpaired). Two valid-sounding approaches:

1. **Clean up device BEFORE `user.delete()`** — guarantees the page is still mounted and BLE commands can be sent
2. **Clean up device AFTER `user.delete()` succeeds** — avoids wiping the device if deletion fails

The original code used approach 1. This caused a critical bug: email/password users hit `requires-recent-login` from Firebase, the re-auth flow failed, and the user was stuck with a wiped device but an account that still exists.

## Decision

Clean up the device AFTER successful account deletion, in the `BlocConsumer` listener that handles the `AccountDeleted` state. Suppress the GoRouter auth redirect during cleanup using `AuthStateNotifier.updateNotifyOnAuthChange(false)`.

## Rationale

- `user.delete()` can fail with `requires-recent-login` for email/password users. Wiping the device before knowing deletion will succeed is destructive and unrecoverable.
- After `user.delete()` succeeds, Firebase's `authStateChanges()` fires, which normally triggers GoRouter to redirect to `/login` and unmount the profile page before BLE cleanup finishes (~800ms).
- `notifyOnAuthChange = false` suppresses exactly one auth state notification (the one from `user.delete()`). The flag auto-resets to `true` inside `updateAuthState()` at line 76 of `auth_state_notifier.dart`, so it's a one-shot suppression.
- If cleanup fails after deletion (device disconnected, BLE error), it's caught silently. The account is already deleted, so a manual factory reset is acceptable.
- The error path re-enables `notifyOnAuthChange` in case deletion fails and no auth state change fires.

## Why not clean up before deletion?

A future developer might think: "just move cleanup back to before deletion — it's simpler." Don't. The `requires-recent-login` failure is common for email/password users and leaves them with a wiped device and no way to delete their account without re-pairing.

## Key files

- `lib/features/profile/presentation/pages/profile_page.dart` — cleanup in `BlocConsumer` listener, suppress in delete confirmation and re-auth dialog
- `lib/core/auth/auth_state_notifier.dart` — `notifyOnAuthChange` flag and auto-reset behavior
