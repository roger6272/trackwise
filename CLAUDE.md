# CLAUDE.md

> Think carefully and implement the most concise solution that changes as little code as possible.

## Project-Specific Instructions

This is a Flutter app (Trackwise) being migrated from FlutterFlow to clean architecture.

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

1. **Re-read the relevant PRD** before continuing work
2. **Review current task definitions** and verify they align with PRD
3. **If tasks contradict PRD**, flag this to the user before proceeding
4. **Don't assume previous context was correct** - verify against source of truth

## Testing

Always run tests before committing:
- `flutter test` for unit/widget tests
- `flutter build apk --debug` to verify build succeeds

## Code Style

Follow existing patterns in the codebase.
- Use BLoC pattern for state management
- Follow clean architecture structure in `features/`
- Match FlutterFlow visual styling exactly during migration
