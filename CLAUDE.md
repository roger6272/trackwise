# CLAUDE.md

> Think carefully and implement the most concise solution that changes as little code as possible.

## Project-Specific Instructions

This is a Flutter app (Traxogic) being migrated from FlutterFlow to clean architecture.

## Cross-Codebase Awareness

**CRITICAL: Always consider ALL THREE codebases when making enhancements or troubleshooting:**

1. **New App Code** (clean architecture)
   - Location: `lib/features/`, `lib/core/`, `lib/backend/`
   - This is the target architecture we're migrating to
   - Uses BLoC pattern and clean architecture principles

2. **Old App Code** (FlutterFlow)
   - Location: `lib/flutter_flow/`, `lib/auth/`, `lib/custom_code/`
   - Reference for existing behavior and business logic
   - Check here to understand how features currently work

3. **Firmware** (ESP32)
   - Location: `firmware/Trackwise_ESP32/`
   - BLE protocol, commands, and device behavior
   - **Essential for BLE-related issues** - always check firmware to understand expected data formats, command sequences, and timing

4. **BLE Protocol Specification**
   - Location: `docs/BLE_PROTOCOL.md`
   - **Source of truth** for app-device communication
   - Contains: UUIDs, commands, notifications, timing, sync sequences
   - **Check this FIRST** when debugging BLE issues before reading firmware code

**Before any change:**
- Check if the issue spans app ↔ firmware communication
- Verify BLE command/response formats match between app and firmware
- Review existing FlutterFlow implementation for reference behavior
- Ensure new code maintains compatibility with firmware protocol

## Epics and Tasks (CCPM)

**PRD is the source of truth, not the task list.**

1. Epics are stored in `.claude/epics/`
2. PRDs are stored in `.claude/prds/`
3. CCPM framework is in `.claude/ccpm/` (don't edit directly)
4. Before starting any task, **verify it aligns with the relevant PRD**
5. If a task contradicts the PRD, **flag this to the user** before proceeding
6. Don't blindly execute tasks - they may have been incorrectly defined

## Migration Work

**CRITICAL: Before any migration-related changes:**

1. **Read the PRD** at `.claude/prds/trackwise-app-migration.md`
2. **Verify the task/epic aligns** with the PRD's phased approach
3. **Check that feature flags exist** in `lib/core/config/migration_flags.dart` before switching implementations
4. **Use feature flags** to toggle between old and new implementations
5. **Keep FF pages as fallback** until new pages are fully tested

The PRD specifies:
- Phase 1: Wire up existing code (enable migration flags one by one)
- Phase 2: Complete missing pages (implement remaining pages)
- Phase 3: Cleanup (remove FF imports, delete FF directories)

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
- Match FlutterFlow visual styling exactly during migration
