# Session-close check: surface work that would otherwise die at a session boundary.
#
# Why this exists: on 2026-07-12 a BLE battery fix was found sitting uncommitted for
# three weeks while four unrelated commits shipped around it, and two commits sat
# unpushed for a month. CLAUDE.md already said "always push." A rule was not enough.
#
# Never blocks. Never fails the turn. Prints nothing when the tree is clean.
# ASCII-only output on purpose: PowerShell encoding mangles Unicode and corrupts the JSON.

$ErrorActionPreference = 'SilentlyContinue'

$repo = 'C:/Users/weich/Documents/FlutterProjects/trackwise'
if (-not (Test-Path $repo)) { exit 0 }

Push-Location $repo
try {
    # Tracked, uncommitted changes. Untracked files are excluded on purpose --
    # build dirs and scratch files are noise, not loose ends.
    $dirty = @(git status --porcelain --untracked-files=no 2>$null | Where-Object { $_ })

    # Unpushed commits. Fails harmlessly if there is no upstream.
    $ahead = @(git log --oneline '@{u}..HEAD' 2>$null | Where-Object { $_ })

    if ($dirty.Count -eq 0 -and $ahead.Count -eq 0) { exit 0 }

    $parts = @()
    if ($dirty.Count -gt 0) {
        $files = ($dirty | ForEach-Object { ($_ -replace '^\s*\S+\s+', '') }) -join ', '
        $parts += "$($dirty.Count) uncommitted tracked file(s): $files"
    }
    if ($ahead.Count -gt 0) {
        $parts += "$($ahead.Count) unpushed commit(s)"
    }

    $msg = "trackwise - loose ends: " + ($parts -join ' | ') + ". Commit and push before this drifts."
    @{ systemMessage = $msg } | ConvertTo-Json -Compress
}
finally {
    Pop-Location
}

exit 0
