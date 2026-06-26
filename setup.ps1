# setup.ps1 — Install claude-config into ~/.claude/
# Safe to run multiple times (idempotent).

$repo   = $PSScriptRoot
$claude = "$env:USERPROFILE\.claude"

Write-Host "Installing claude-config to $claude ..." -ForegroundColor Cyan

# 1. CLAUDE.md
Copy-Item "$repo\CLAUDE.md" "$claude\CLAUDE.md" -Force
Write-Host "  [OK] CLAUDE.md"

# 2. grasshopper-components/
$dest = "$claude\grasshopper-components"
if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Path $dest | Out-Null }
Copy-Item "$repo\grasshopper-components\*" $dest -Recurse -Force
Write-Host "  [OK] grasshopper-components/"

# 3. memory/ — goes into the project memory folder for ~/.claude itself
# Claude Code encodes the path as: C--Users-{username}--claude
$encoded = "C--Users-$env:USERNAME--claude"
$memDest = "$claude\projects\$encoded\memory"
if (-not (Test-Path $memDest)) { New-Item -ItemType Directory -Path $memDest -Force | Out-Null }
Copy-Item "$repo\memory\*" $memDest -Recurse -Force
Write-Host "  [OK] memory/ -> projects\$encoded\memory\"

Write-Host ""
Write-Host "Done. Next step (if not already done):" -ForegroundColor Green
Write-Host "  claude mcp add --transport http cordyceps http://127.0.0.1:26929/mcp"
Write-Host ""
Write-Host "Verify with: claude mcp list"
