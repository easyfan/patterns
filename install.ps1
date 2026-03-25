# install.ps1 — patterns Claude Code plugin installer (Windows)
#
# Usage:
#   .\install.ps1              # install to $HOME\.claude\
#   .\install.ps1 -DryRun      # preview without writing
#   .\install.ps1 -Uninstall   # remove installed files

param(
  [switch]$DryRun,
  [switch]$Uninstall,
  [string]$ClaudeDir = "$HOME\.claude"
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

function Write-Ok   { param($msg) Write-Host "  v $msg" -ForegroundColor Green }
function Write-Skip { param($msg) Write-Host "  - $msg (up to date)" -ForegroundColor DarkGray }
function Write-Info { param($msg) Write-Host "  $msg" }
function Write-Warn { param($msg) Write-Host "  ! $msg" -ForegroundColor Yellow }

$version = (Get-Content "$ScriptDir\package.json" | Select-String '"version"')[0] -replace '.*"version":\s*"([^"]+)".*','$1'

Write-Host ""
Write-Host "  patterns — Claude Code plugin v$version"
Write-Host "  Target: $ClaudeDir"
if ($DryRun) { Write-Host "  Mode: DRY RUN (no files modified)" }
Write-Host ""

# Check Claude CLI
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
  Write-Warn "'claude' not found. Install Claude Code: https://claude.ai/code"
  Write-Host ""
}

$files = @{
  "commands\patterns.md"          = "commands\patterns.md"
  "patterns\agent-monitoring.md"  = "patterns\agent-monitoring.md"
}

if ($Uninstall) {
  Write-Host "  Uninstalling..."
  foreach ($entry in $files.GetEnumerator()) {
    $dst = Join-Path $ClaudeDir $entry.Value
    if (Test-Path $dst) {
      if (-not $DryRun) { Remove-Item $dst }
      Write-Ok "Removed $dst"
    } else {
      Write-Skip (Split-Path -Leaf $dst)
    }
  }
  Write-Host ""
  Write-Host "  Uninstall complete."
  Write-Host ""
  exit 0
}

$changed = 0
foreach ($entry in $files.GetEnumerator()) {
  $src = Join-Path $ScriptDir $entry.Key
  $dst = Join-Path $ClaudeDir $entry.Value
  $dstDir = Split-Path -Parent $dst

  if (-not (Test-Path $dstDir)) {
    if (-not $DryRun) { New-Item -ItemType Directory -Path $dstDir -Force | Out-Null }
  }

  $needsUpdate = $true
  if ((Test-Path $dst) -and ((Get-FileHash $src).Hash -eq (Get-FileHash $dst).Hash)) {
    $needsUpdate = $false
  }

  if (-not $needsUpdate) {
    Write-Skip (Split-Path -Leaf $dst)
  } else {
    if (Test-Path $dst) {
      Write-Info "Updating  $($entry.Key)..."
    } else {
      Write-Info "Installing $($entry.Key)..."
    }
    if (-not $DryRun) { Copy-Item $src $dst -Force }
    Write-Ok "$(Split-Path -Leaf $dst) → $dst"
    $changed++
  }
}

Write-Host ""
if ($DryRun) {
  Write-Host "  [dry-run] $changed file(s) would be modified."
} else {
  Write-Host "  Done! $changed file(s) installed."
  Write-Host ""
  Write-Host "  Quick start:"
  Write-Host "    /patterns                        # list available patterns"
  Write-Host "    /patterns agent-monitoring       # instantiate runtime monitoring workflow"
  Write-Host "    /patterns --patch                # patch missing hooks in existing commands"
}
Write-Host ""
