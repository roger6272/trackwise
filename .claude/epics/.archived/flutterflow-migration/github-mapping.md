---
created: 2026-01-14T08:23:23Z
updated: 2026-01-14T08:23:23Z
---

# GitHub Issue Mapping

This file maps local task files to GitHub issues for the `flutterflow-migration` epic.

## Epic Issue

| Local File | GitHub Issue | Title |
|------------|--------------|-------|
| epic.md | [#1](https://github.com/roger6272/trackwise/issues/1) | Epic: FlutterFlow Migration |

## Task Issues

| Local File | GitHub Issue | Title | Status | Parallel |
|------------|--------------|-------|--------|----------|
| 2.md | [#2](https://github.com/roger6272/trackwise/issues/2) | Restyle Auth Pages | open | true |
| 3.md | [#3](https://github.com/roger6272/trackwise/issues/3) | Restyle Main/Items Pages | open | true |
| 4.md | [#4](https://github.com/roger6272/trackwise/issues/4) | Restyle Profile and Navigation | open | true |
| 5.md | [#5](https://github.com/roger6272/trackwise/issues/5) | Wire Main and Integration Test | open | false |
| 6.md | [#6](https://github.com/roger6272/trackwise/issues/6) | Delete FlutterFlow Files | open | false |

## Dependencies

```
#2, #3, #4 (parallel) → #5 → #6
```

- Tasks #2, #3, #4 can run in parallel
- Task #5 depends on #2, #3, #4 completing
- Task #6 depends on #5 completing
