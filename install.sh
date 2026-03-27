#!/usr/bin/env bash
# install.sh — patterns Claude Code plugin installer
# ✅ Verified by automated tests: this install path is covered by the skill-test pipeline (looper Stage 5).
#
# Usage:
#   ./install.sh              # install to ~/.claude/
#   ./install.sh --dry-run    # preview without writing
#   ./install.sh --uninstall  # remove installed files
#   CLAUDE_DIR=/path ./install.sh  # custom target (also used by looper/packer)

set -euo pipefail

# ── Resolve real script dir (symlink-safe) ────────────────────────────────────
SCRIPT_PATH="$0"
while [ -L "$SCRIPT_PATH" ]; do
  link_dir="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
  SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
  [[ "$SCRIPT_PATH" != /* ]] && SCRIPT_PATH="$link_dir/$SCRIPT_PATH"
done
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

# ── Config ────────────────────────────────────────────────────────────────────
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
DRY_RUN=false
UNINSTALL=false

for arg in "$@"; do
  case "$arg" in
    --dry-run)    DRY_RUN=true ;;
    --uninstall)  UNINSTALL=true ;;
    --target=*)   CLAUDE_DIR="${arg#--target=}" ;;
    --help|-h)
      echo "Usage: ./install.sh [--dry-run] [--uninstall] [--target=<path>]"
      echo "  CLAUDE_DIR=/path ./install.sh   # custom Claude config dir (env var)"
      echo "  ./install.sh --target=/path     # custom Claude config dir (flag)"
      exit 0 ;;
  esac
done

# ── Helpers ───────────────────────────────────────────────────────────────────
info()  { printf "  %s\n" "$*"; }
ok()    { printf "  \033[32m✓\033[0m %s\n" "$*"; }
skip()  { printf "  \033[2m– %s (up to date)\033[0m\n" "$*"; }
warn()  { printf "  \033[33m! %s\033[0m\n" "$*"; }
run()   { $DRY_RUN || "$@"; }

# ── Files to install: "src_rel|dst_rel" pairs (bash 3.2 compatible)
FILES=(
  "commands/patterns.md|commands/patterns.md"
  "patterns/agent-monitoring.md|patterns/agent-monitoring.md"
)

# ── Header ────────────────────────────────────────────────────────────────────
echo ""
echo "  patterns — Claude Code plugin v$(grep '"version"' "$SCRIPT_DIR/package.json" | head -1 | grep -o '[0-9.]*')"
echo "  Target: $CLAUDE_DIR"
$DRY_RUN && echo "  Mode: DRY RUN (no files modified)"
echo ""

# ── Check Claude Code ─────────────────────────────────────────────────────────
if ! command -v claude &>/dev/null; then
  warn "'claude' CLI not found. Install Claude Code first: https://claude.ai/code"
  echo ""
fi

# ── Uninstall ─────────────────────────────────────────────────────────────────
if $UNINSTALL; then
  echo "  Uninstalling..."
  for pair in "${FILES[@]}"; do
    rel_dst="${pair#*|}"
    dst="$CLAUDE_DIR/$rel_dst"
    if [ -f "$dst" ]; then
      run rm "$dst"
      ok "Removed $dst"
    else
      skip "$(basename "$dst") (not found)"
    fi
  done
  echo ""
  echo "  Uninstall complete."
  echo ""
  exit 0
fi

# ── Install ───────────────────────────────────────────────────────────────────
changed=0

for pair in "${FILES[@]}"; do
  rel_src="${pair%%|*}"
  rel_dst="${pair#*|}"
  src="$SCRIPT_DIR/$rel_src"
  dst="$CLAUDE_DIR/$rel_dst"
  dst_dir="$(dirname "$dst")"

  [ -d "$dst_dir" ] || run mkdir -p "$dst_dir"

  if [ -f "$dst" ] && diff -q "$src" "$dst" &>/dev/null; then
    skip "$(basename "$dst")"
  else
    [ -f "$dst" ] && info "Updating  $rel_src..." || info "Installing $rel_src..."
    run cp "$src" "$dst"
    ok "$(basename "$dst") → $dst"
    changed=$((changed + 1))
  fi
done

# ── Footer ────────────────────────────────────────────────────────────────────
echo ""
if $DRY_RUN; then
  echo "  [dry-run] $changed file(s) would be modified."
else
  echo "  Done! $changed file(s) installed."
  echo ""
  echo "  Quick start:"
  echo "    /patterns                        # list available patterns"
  echo "    /patterns agent-monitoring       # instantiate runtime monitoring workflow"
  echo "    /patterns --patch                # patch missing hooks in existing commands"
fi
echo ""
