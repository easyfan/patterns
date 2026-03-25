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

工作流模式引导器 — 列出 pattern 模板、实例化为项目 command/agent 文件，或通过 `--patch` 修补已实例化命令缺失的 hook 步骤。

## 安装

```bash
# 方式一：Claude Code 原生插件
/plugin marketplace add easyfan/patterns

# 方式二：npx
npx patterns-cc

# 方式三：克隆后运行安装脚本
./install.sh              # macOS / Linux
.\install.ps1             # Windows

# 方式四：手动复制
cp commands/patterns.md ~/.claude/commands/
cp patterns/agent-monitoring.md ~/.claude/patterns/
```

## 用法

```
/patterns                        # 列出所有可用 pattern
/patterns <pattern_name>         # 引导建立对应工作流
/patterns --patch [command_name] # 修补已实例化命令缺失的 hook 步骤
```

## 内置 Pattern

| Pattern | 说明 |
|---------|------|
| `agent-monitoring` | 运行时 agent 行为监控，在高风险任务后触发 agent-monitor 审查 |

## 依赖

- Claude Code CLI
- `find`、`stat`（系统自带）
