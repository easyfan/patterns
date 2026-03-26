# patterns

Workflow pattern manager for Claude Code — lists, instantiates, and patches workflow patterns in your project.

```
/patterns                        # list all available patterns
/patterns <pattern_name>         # instantiate a workflow pattern
/patterns --patch [command_name] # patch missing hook steps in existing commands
```

---

## What it does

**List mode** (`/patterns`): Reads `~/.claude/patterns/` and outputs a catalog with description and last-modified date. Includes a `💡` hint at the bottom to remind users of the `--patch` option. In meta-projects, also surfaces unprocessed pending proposals.

**Instantiate mode** (`/patterns <name>`): Loads the pattern template, auto-detects project info (from `CLAUDE.md` if available, falling back to shell probes), pre-fills the kickoff prompt, then creates the corresponding `.claude/commands/` and `.claude/agents/` files. All generated files include `generated-from: <pattern_name>` in their YAML front-matter for traceability. If a target file already exists, presents a three-way choice (overwrite / skip / view then decide) — never silently overwrites. Ends with an optional `/skill-review` quality gate, triggered only when command or agent files were written.

**Patch mode** (`/patterns --patch`): Scans existing instantiated commands for missing hook steps using exact title-line matching (e.g., checks for `#### 最终步骤：质量门` rather than bare keyword search to avoid false positives from comments). Detects, previews a patch plan, waits for confirmation, then appends the missing steps. Reports a positive "all hooks complete" confirmation when nothing needs patching.

---

## Install

### Option A — Claude Code plugin (recommended)

```
/plugin marketplace add easyfan/patterns
/plugin install patterns@patterns
```

> **Note**: `/plugin` is a Claude Code REPL built-in command and cannot be invoked via `claude -p` (returns `Unknown skill: plugin`). Automated test pipelines (skill-test Stage 5) do not cover this install path — run it manually in a Claude Code session.

<!--
### Option B — npx (not yet published)

```bash
npx patterns-cc
```
-->

### Option B — install script

```bash
# macOS / Linux
git clone https://github.com/easyfan/patterns
cd patterns
./install.sh

# Windows
.\install.ps1
```

```bash
# Options
./install.sh --dry-run      # preview changes without writing
./install.sh --uninstall    # remove installed files
CLAUDE_DIR=/custom ./install.sh   # custom Claude config path
```

### Option C — manual

```bash
cp commands/patterns.md        ~/.claude/commands/
cp patterns/agent-monitoring.md ~/.claude/patterns/
```

---

## Usage

```
/patterns [pattern_name | --patch [command_name]]
```

| Argument | Description |
|----------|-------------|
| _(none)_ | List all patterns in `~/.claude/patterns/` |
| `<name>` | Instantiate the named pattern for the current project |
| `--patch` | Scan all known commands and patch missing hook steps |
| `--patch <cmd>` | Patch only the specified command |

**Examples:**

```
/patterns                              # catalog (with --patch hint at bottom)
/patterns agent-monitoring             # set up runtime agent monitoring
/patterns --patch research-module      # add missing quality gate hook
/patterns --patch                      # patch all known commands
```

---

## Files installed

```
~/.claude/
├── commands/
│   └── patterns.md              # /patterns slash command
└── patterns/
    └── agent-monitoring.md      # runtime agent monitoring pattern
```

---

## Requirements

- **Claude Code** CLI
- **find**, **stat** (system) — used for pattern scanning and timestamps
- No other dependencies

---

## Architecture

```
/patterns (coordinator)
│
├── No args:   Bash — find ~/.claude/patterns/*.md → list with descriptions + --patch hint
│              (meta-project only) Bash — scan pending proposals
│
├── <name>:    Read pattern template
│              Bash — detect project info (CLAUDE.md or shell probe)
│              Fill kickoff prompt placeholders
│              Step 5a — check file existence → 3-way: overwrite/skip/view-then-decide
│              Write .claude/commands/<cmd>.md + agents if needed
│              → Step 7: /skill-review quality gate (only if .claude/commands/ or .claude/agents/ files written)
│
└── --patch:   Bash — find installed command files
               Grep — detect missing hook steps by exact title-line match
               Show patch plan → wait for confirm
               Edit — append missing hook steps
               Report healthy state if nothing to patch
```

---

## Living Example: From Pattern to Runtime Safety

On 2026-03-24, the `agent-monitoring` pattern was created after `/news-digest` surfaced an OpenAI Engineering post about runtime agent monitoring. One session later, `/patterns agent-monitoring` was run in the meta-project:

1. **Pattern loaded**: `agent-monitoring.md` read from `~/.claude/patterns/`
2. **Project detected**: `CLAUDE.md` found → project context filled automatically, no shell probes needed
3. **Files created**:
   - `~/.claude/commands/agent-monitoring-workflow.md` — coordinator command for triggering post-task audits
4. **Quality gate**: User ran `/skill-review agent-monitoring-workflow` — 3 recommendations, all applied in the same session

The full loop from pattern instantiation to reviewed, production-ready command took under 10 minutes. This is the intended workflow: `/patterns` bridges the gap between reusable design templates and live, project-specific tools.

---

## License

MIT
