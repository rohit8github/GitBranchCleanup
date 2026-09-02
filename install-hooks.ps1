$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path .).Path

Write-Host "Configuring Git hooks for repository: $repoRoot"

# Keep versioned hooks as source of truth
& git config core.hooksPath .github/hooks

$gitHooksDir = Join-Path $repoRoot '.git/hooks'
if (-not (Test-Path $gitHooksDir)) {
    New-Item -ItemType Directory -Path $gitHooksDir -Force | Out-Null
}

$shimPath = Join-Path $gitHooksDir 'pre-commit'
$shim = @(
    '#!/bin/sh'
    'set -eu'
    'REPO_ROOT="$(git rev-parse --show-toplevel)"'
    'exec "$REPO_ROOT/.github/hooks/pre-commit" "$@"'
) -join "`n"

[System.IO.File]::WriteAllText($shimPath, $shim + "`n", [System.Text.UTF8Encoding]::new($false))

Write-Host 'Installed .git/hooks/pre-commit shim -> .github/hooks/pre-commit'
Write-Host 'Done.'
