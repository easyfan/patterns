---
name: patterns
description: |
  Use this skill when the user invokes /patterns or asks to list, instantiate, or patch workflow patterns for their Claude Code project. Triggers on: "/patterns", "list patterns", "load a pattern", "create workflow from pattern", "/patterns --patch", "patch missing hooks", "show available patterns", "instantiate workflow", "set up research workflow". Covers listing ~/.claude/patterns/, auto-filling kickoff prompts from project context, creating command/agent files, and patching existing commands with missing hook steps.
license: MIT
metadata:
  version: "1.1.0"
  author: cc-meta-project
  platforms: claude-code
  requires: "commands/patterns.md"
---

# patterns

Workflow pattern manager — lists pattern templates, instantiates them into project command/agent files, or patches existing instantiated commands with missing hook steps via `--patch`.

## Install

```bash
# Option A: Claude Code plugin marketplace
/plugin marketplace add easyfan/patterns

# Option B: npx
npx patterns

# Option C: clone and run install script
./install.sh              # macOS / Linux
.\install.ps1             # Windows

# Option D: manual copy
cp commands/patterns.md ~/.claude/commands/
cp patterns/agent-monitoring.md ~/.claude/patterns/
```

## Usage

```
/patterns                        # list all available patterns
/patterns <pattern_name>         # instantiate a workflow pattern
/patterns --patch [command_name] # patch missing hook steps in an instantiated command
```

## Built-in patterns

| Pattern | Description |
|---------|-------------|
| `agent-monitoring` | Runtime agent behavior monitoring — triggers agent-monitor review after high-risk tasks |

## Requirements

- Claude Code CLI
- `find`, `stat` (system)
