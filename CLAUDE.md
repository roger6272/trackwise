# CLAUDE.md

> Think carefully and implement the most concise solution that changes as little code as possible.

## Project-Specific Instructions

This is a Flutter app (Traxelos) using clean architecture with BLoC pattern.

## Cross-Codebase Awareness

**CRITICAL: Always consider ALL codebases AND documentation when making enhancements, troubleshooting, or doing project reviews/analysis:**

1. **App Code**
   - Location: `lib/features/`, `lib/core/`
   - Uses BLoC pattern and clean architecture principles

2. **Firmware** (ESP32)
   - Location: `firmware/Trackwise_ESP32/`
   - BLE protocol, commands, and device behavior
   - **Essential for BLE-related issues** - always check firmware to understand expected data formats, command sequences, and timing

3. **BLE Protocol Specification**
   - Location: `docs/BLE_PROTOCOL.md`
   - **Source of truth** for app-device communication
   - Contains: UUIDs, commands, notifications, timing, sync sequences, edge cases
   - **ALWAYS read this doc** when the task involves:
     - Bluetooth/BLE code (app or firmware)
     - Protocol design, review, or optimization questions
     - Sync, notifications, or device communication
     - Any question about how app and device communicate
     - Whole-project reviews or architecture analysis
   - Read BEFORE diving into firmware code - the doc explains the "why" behind the implementation

4. **User Guide**
   - Location: `docs/USER_GUIDE.md`
   - **Non-technical user documentation** - how end users interact with the product
   - Contains: Feature explanations, user flows, troubleshooting, quick reference
   - **Consult when:** Making UI/UX changes, adding features, writing user-facing text, or creating other documentation
   - Ensures code changes align with documented user expectations

5. **Product Overview**
   - Location: `docs/PRODUCT_OVERVIEW.md`
   - **Business/product context** - what the product is and why it exists
   - Contains: Problem/solution, key features, differentiators, use cases
   - **Consult when:** Making architectural decisions or prioritizing features

6. **Architecture Decision Records (ADRs)**
   - Location: `docs/decisions/`
   - **Documents explaining WHY** non-obvious design decisions were made
   - **ALWAYS check here first** when questioning an existing design choice
   - If a decision seems wrong, read the ADR before suggesting changes
   - When making new significant decisions, create a new ADR
   - **What's "non-obvious"?** A decision where someone might ask "why didn't they just...?"
     - You rejected a simpler approach (e.g., "why two notifications instead of one?")
     - Multiple valid options existed (e.g., "why JSON over binary?")
     - It looks like a bug but isn't (e.g., "why does set_items ignore counts?")
     - Trade-offs were weighed (e.g., "why batch every 10 instead of every 1?")
     - It contradicts common patterns (e.g., "why device over cloud as source of truth?")
   - **Quick test:** If explaining "why" takes more than one sentence, consider an ADR. If no ADR exists for a non-obvious design, double check with user before making changes.

7. **Troubleshooting Playbook**
   - Location: `docs/TROUBLESHOOTING.md`
   - **Quick diagnostic guides** for common issues
   - Contains: Connection issues, sync problems, count mismatches, notification issues, daily reset problems
   - **Consult when:** Debugging BLE issues, investigating user-reported bugs, or understanding failure modes
   - Includes diagnostic commands and quick reference tables

8. **Data Flow & Sync Scenarios**
   - Location: `docs/DATA_FLOW.md`
   - **Visual guide** to how data moves through the system
   - Contains: Three-tier architecture, sync scenario diagrams, real-time event flow, multi-device sync, consistency rules
   - **Consult when:** Debugging sync issues, understanding source-of-truth decisions, or working on multi-device features
   - Includes ASCII sequence diagrams and decision trees

**Before any change:**
- Check if the issue spans app ↔ firmware communication
- Verify BLE command/response formats match between app and firmware
- Ensure new code maintains compatibility with firmware protocol

## Epics and Tasks (CCPM)

**PRD is the source of truth, not the task list.**

1. Epics are stored in `.claude/epics/`
2. PRDs are stored in `.claude/prds/`
3. CCPM framework is in `.claude/ccpm/` (don't edit directly)
4. Before starting any task, **verify it aligns with the relevant PRD**
5. If a task contradicts the PRD, **flag this to the user** before proceeding
6. Don't blindly execute tasks - they may have been incorrectly defined

## Continued Sessions

When resuming from a previous session:

1. **Sync with git first**:
   - Run `git status` to check for uncommitted changes
   - If clean, run `git pull` to get latest changes
   - If there are local changes, ask user how to proceed (commit, stash, or discard)
2. **Re-read the relevant PRD** before continuing work
3. **Review current task definitions** and verify they align with PRD
4. **If tasks contradict PRD**, flag this to the user before proceeding
5. **Don't assume previous context was correct** - verify against source of truth

## After Committing

Always push changes so they're available on other devices:
- Run `git push` after commits (or ask user if they want to push)
- Verify push succeeded before ending session

## Testing

Always run tests before committing:
- `flutter test` for unit/widget tests
- `flutter build apk --debug` to verify build succeeds

## Code Style

Follow existing patterns in the codebase.
- Use BLoC pattern for state management
- Follow clean architecture structure in `features/`
- Use `AppLogger.debug()` / `AppLogger.error()` for all logging — never raw `print()` or `debugPrint()`. Import from `core/utils/logger.dart`
- Firmware: use `DEBUG_LOG()` / `DEBUG_PRINTLN()` macros — never raw `Serial.print()`. Enable with `#define DEBUG` in `.ino`

### UI Standards

**Colors — use `AppColors` and theme context, never hardcode hex values:**
- Use `AppColors.primary`, `AppColors.error`, etc. — never `Color(0xFF...)` or `Colors.red`
- Use `AppColors` adaptive helpers (`primaryAdaptive()`, `primaryBackground()`, `secondaryText()`) for brightness-aware colors
- Add new semantic colors (e.g., positive/negative/neutral for stats) to `AppColors`, not per-widget

**Typography — use the TextTheme, not inline GoogleFonts:**
- Use `Theme.of(context).textTheme.titleLarge` etc. — never inline `GoogleFonts.interTight(...)` or `GoogleFonts.inter(...)`
- The theme already defines the full type scale with correct fonts and weights in `app_theme.dart`
- If a style doesn't exist in the theme, add it there — don't create one-off inline styles

**Accessibility:**
- Add `Semantics(label: '...')` to icon-only buttons (FABs, nav icons, icon actions)
- Never set `focusColor: Colors.transparent` — preserve default focus indicators
- Ensure touch targets are at least 48dp

**Feedback & errors:**
- Use `AppColors.error` for all error SnackBars — never `Colors.red`
- Use `AppColors.success` for success feedback
- Add debouncing (300ms) to search/filter inputs that trigger on every keystroke

## Codebase Gotchas

Non-obvious things that cost time if you don't know them.

**Adding a field to `Item` fans out further than you'd expect.** `ItemModel extends Item` (the model adds Firestore serialization). A new field must be added to: the entity, the model's constructor / `fromFirestore` / `toFirestore` / `copyWith`, and **every manual `ItemModel(...)` construction** — they're spread across `item_model.dart`, the repository impl, the datasource impl, `test_fixtures.dart`, and the item test files. Grep for `ItemModel(` and fix all of them; the count moves, so don't trust a number written anywhere.

**For a targeted field update** (not a whole-item write), the path is: abstract datasource → datasource impl → abstract repository → repository impl. Follow `cycleNames` / `cycleNotes` as the template.

**Firestore naming crosses a boundary:** `snake_case` in Firestore (`cycle_names`, `item_name`, `increment_by`), `camelCase` in Dart (`cycleNames`, `itemName`, `incrementBy`). `uid` is stored as a **`DocumentReference`, not a String**.

**Tests use `mocktail`, not `mockito`.** Follow the existing patterns — the `cycleNames` tests are a good template for any new `Map` field.

## Facts vs. copies — how this repo avoids doc drift

**Derive, never copy.** Do not write test counts, version numbers, or `file:line` references into any doc. They rot silently. Cite a *function or symbol name* instead of a line number, and compute counts when you need them.

This repo has been burned by this: `TROUBLESHOOTING.md` §1.6/§1.7 were committed a month before the code they described, citing line numbers for a fix that wasn't in the tree. `LAUNCH_CHECKLIST.md` still claims `847/847` tests.

**A corollary rule, which overrides the "when possible" below:** never commit docs describing behavior that isn't landing in the same commit.

**Where non-engineering facts go:** business/venture context (who owns what, costs, launch decisions, the nRF firmware arrangement) lives in Obsidian at `ObsidianVault/Traxelos/`, **not** in this repo. Don't mirror it here, and don't mirror repo docs there.

## Documentation Maintenance

**When making changes, always check if documentation needs updating.**

| If you change... | Update these docs |
|------------------|-------------------|
| BLE commands, notifications, protocol | `docs/BLE_PROTOCOL.md`, check `DATA_FLOW.md` for examples |
| Handshake request/response format | `docs/BLE_PROTOCOL.md`, `docs/DATA_FLOW.md` (has response examples) |
| Sync logic, data flow | `docs/DATA_FLOW.md` (the `.html` is generated — see below) |
| Firmware behavior | `docs/BLE_PROTOCOL.md`, `docs/DATA_FLOW.md` |
| Error handling, failure modes | `docs/TROUBLESHOOTING.md`, `docs/BLE_PROTOCOL.md` (error codes) |
| User-facing features, UI flows | `docs/USER_GUIDE.md` |
| Product capabilities, use cases | `docs/PRODUCT_OVERVIEW.md` |
| Non-obvious design decisions | Create new `docs/decisions/ADR-XXX.md` |

### `docs/*.html` are GENERATED. Never edit them by hand.

The HTML docs are **build output**, produced from the markdown by `scripts/build_docs.py`. They exist because the **firmware engineer reads them** — he doesn't have this repo, so they are how the spec reaches the person implementing the nRF port.

```bash
python scripts/build_docs.py           # regenerate after editing any docs/*.md
python scripts/build_docs.py --check   # exits 1 if any HTML is stale
```

**This rule used to say "update both."** It didn't hold, and the failure was severe: on 2026-07-12, `BLE_PROTOCOL.html` contained **zero** mentions of `ota_start` while the markdown had 17, and `TROUBLESHOOTING.html` had none of the OTA section. **The one person who most needed the OTA protocol was reading a copy that didn't contain it.** A hand-maintained second copy of a document is a drift generator — the markdown is the source of truth and the HTML is derived from it.

Only the six docs in `PUBLISHED` (in the script) are generated — deliberately *not* the launch checklist, store-setup guides, or UX specs, which are internal.

**Guidelines:**
- Update docs in the **same commit** as the code change when possible
- If a doc describes behavior you're changing, **update it or flag the inconsistency**
- When adding new features, check if they should be documented in User Guide
- Keep diagrams and examples in sync with actual implementation

**After fixing bugs:** Always add the pattern to `docs/TROUBLESHOOTING.md` if the root cause was non-obvious (took investigation to find, involved timing/state issues, or could recur). Include: symptoms, root cause, the fix, and a "key lesson" takeaway. This is not optional — treat it as part of the fix.

**After fixing bugs (ADR check):** If the fix involves a design decision that looks wrong at first glance or contradicts common patterns, create an ADR in `docs/decisions/`. The test: would a future developer reading this code think "this looks like a bug" and try to revert it? If yes, write an ADR. This is separate from the troubleshooting entry — troubleshooting explains the bug, ADR explains the counter-intuitive fix.
