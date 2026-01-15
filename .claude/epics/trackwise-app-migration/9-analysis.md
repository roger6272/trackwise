---
issue: 9
title: Auth Flow Integration
analyzed: 2026-01-15T05:39:54Z
estimated_hours: 2
parallelization_factor: 1.5
---

# Parallel Work Analysis: Issue #9

## Overview

Wire up the existing auth pages (login, signup, forgot password) to the AppRouter and ensure all authentication providers (email, Google, Apple) work correctly. Most of the implementation is already complete - this task is primarily verification and small fixes.

## Current State Assessment

**Already Complete:**
- ✅ All 3 auth pages fully implemented with BLoC integration
- ✅ AuthBloc with all events (email, Google, Apple sign-in, sign-up, reset password)
- ✅ AppRouter has all auth routes with redirect guards
- ✅ AuthBloc provided at app level in main.dart
- ✅ `MigrationFlags.useNewRouter = true`

**Issues Found:**
- ⚠️ Login page navigates to `/items` on success, but route is `/` (line 509)
- ⚠️ Signup page navigates to `/items` on success, but route is `/` (line 559)
- ⚠️ `MigrationFlags.useNewAuthPages = false` but pages are being used

## Parallel Streams

### Stream A: Fix Navigation & Enable Flag
**Scope**: Fix post-auth navigation and enable migration flag
**Files**:
- `lib/features/auth/presentation/pages/login_page.dart`
- `lib/features/auth/presentation/pages/signup_page.dart`
- `lib/core/config/migration_flags.dart`
**Agent Type**: fullstack-specialist
**Can Start**: immediately
**Estimated Hours**: 0.5
**Dependencies**: none

### Stream B: Manual Testing
**Scope**: Test all auth flows with real accounts
**Files**: None (testing only)
**Agent Type**: manual
**Can Start**: after Stream A completes
**Estimated Hours**: 1.5
**Dependencies**: Stream A

**Tests Required:**
1. Email/password sign-in
2. Email/password sign-up
3. Google Sign-In
4. Apple Sign-In (iOS only)
5. Password reset email
6. Session persistence (restart app)
7. Auth state navigation (logout → login, login → home)

## Coordination Points

### Shared Files
None - Stream A works on auth pages, Stream B is manual testing.

### Sequential Requirements
1. Fix navigation issues before testing
2. Enable migration flag after fixes
3. Test each auth provider

## Conflict Risk Assessment
**Low Risk**: Single stream with sequential testing.

## Parallelization Strategy

**Recommended Approach**: Sequential

This task is small enough that parallelization provides no benefit. Execute Stream A, then Stream B.

## Expected Timeline

With sequential execution:
- Wall time: 2 hours
- Total work: 2 hours

## Notes

- The auth pages are already being used via the new router despite `useNewAuthPages = false`
- The migration flag is more of a documentation marker at this point
- Main work is verifying all auth providers work correctly
- Consider testing on both iOS (for Apple Sign-In) and Android
