---
issue: 2
title: Restyle Auth Pages
analyzed: 2026-01-14T08:29:00Z
streams: 1
parallel: false
---

# Issue #2 Analysis: Restyle Auth Pages

## Summary

This task involves restyling 3 auth pages (login, signup, forgot password) to match FlutterFlow designs exactly. The pages share common styling patterns, so a single stream working sequentially is most efficient.

## Styling Differences Identified

### Login Page (`login_page.dart` vs `auth2_login_widget.dart`)

| Element | Current (Clean Arch) | Target (FlutterFlow) |
|---------|---------------------|---------------------|
| Logo top padding | `SizedBox(height: 48)` | `Padding top: 70.0` |
| Card padding | `EdgeInsets.all(24)` | `EdgeInsets.all(32)` |
| Card max-width | none | `maxWidth: 570.0` |
| Card box-shadow | `blurRadius: 10, offset: (0,4)` | `blurRadius: 4.0, offset: (0,2)` |
| Card border radius | `16` | `12.0` |
| Subtitle text | "Sign in to continue tracking" | "Fill out the information below..." |
| Text field fill | No fill color | `fillColor: primaryBackground` |
| Text field border width | 1 | 2.0 |
| "Forgot password" position | Right-aligned text button | Full-width button at bottom |
| "OR" divider text | "OR" | "Or sign in with" |
| Social buttons | Column of outlined buttons | Full-width button with border |
| Animation | None | FadeIn + MoveUp + Scale + Tilt |

### Key FF Styling Patterns to Apply

1. **Card styling**: `maxWidth: 570.0`, `borderRadius: 12.0`, `padding: 32`, `shadow: blur 4, offset (0,2)`
2. **Input fields**: Filled with `primaryBackground`, border width 2.0, all 4 border states defined
3. **Primary button**: Height 44, elevation 3, rounded 12
4. **Secondary button**: Height 44, elevation 0, border 2, hover color
5. **Font**: `GoogleFonts.interTight` for display/title, `GoogleFonts.inter` for body/label

## Work Streams

### Stream A: Auth Pages Restyling (Single Stream)

**Rationale**: All 3 pages share:
- Same layout structure
- Same form field styling
- Same button styling
- Same animation patterns

Working sequentially allows copying patterns between pages efficiently.

**Scope**:
- `lib/features/auth/presentation/pages/login_page.dart`
- `lib/features/auth/presentation/pages/signup_page.dart`
- `lib/features/auth/presentation/pages/forgot_password_page.dart`

**Reference Files**:
- `lib/account_profile_creation/auth_2_login/auth2_login_widget.dart`
- `lib/account_profile_creation/auth_2_create/auth2_create_widget.dart`
- `lib/account_profile_creation/auth_2_forgot_password/auth2_forgot_password_widget.dart`

**Work Order**:
1. Login page (largest, establishes patterns)
2. Signup page (similar to login)
3. Forgot password page (simplest)

**Deliverables**:
- [ ] Login page matches FF design
- [ ] Signup page matches FF design
- [ ] Forgot password page matches FF design
- [ ] All form fields styled identically
- [ ] Button heights = 44
- [ ] Card animation added (optional - can skip for initial parity)

## Dependencies

None - can start immediately.

## Estimated Effort

- Stream A: 3-4 hours
- Total: 3-4 hours
