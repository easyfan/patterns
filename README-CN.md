# patterns

Claude Code 工作流模式管理器——列出、实例化并补丁修复项目中的工作流模式。

```
/patterns                        # 列出所有可用模式
/patterns <pattern_name>         # 实例化一个工作流模式
/patterns --patch [command_name] # 修复已实例化命令中缺失的 hook 步骤
```

---

## 功能介绍

**列表模式**（`/patterns`）：读取 `~/.claude/patterns/` 目录，输出包含描述和最后修改时间的模式目录。底部附有 `💡` 提示，引导用户使用 `--patch` 选项。在元项目中，还会额外展示未处理的 pending proposals。

**实例化模式**（`/patterns <name>`）：加载模式模板，自动探测项目信息（优先从 `CLAUDE.md` 读取，无则通过 shell 探针获取），预填写初始化 prompt，然后生成对应的 `.claude/commands/` 和 `.claude/agents/` 文件。所有生成文件的 YAML front-matter 中均包含 `generated-from: <pattern_name>` 字段以保证可追溯性。若目标文件已存在，会提供三选项（覆盖 / 跳过 / 查看后决定），绝不静默覆盖。流程最后提供可选的 `/skill-review` 质量门，仅在写入了 command 或 agent 文件时触发。

**补丁模式**（`/patterns --patch`）：使用精确标题行匹配扫描已实例化命令中缺失的 hook 步骤（如检查特定的章节标题而非宽泛关键词，避免注释内容误触发）。检测后预览补丁计划，等待用户确认，再追加缺失步骤。若无需补丁，输出"所有 hooks 完整"的确认提示。

---

## 安装

### 方式 A — Claude Code 插件市场（推荐）

```
/plugin marketplace add easyfan/patterns
/plugin install patterns@patterns
```

> **注**：`/plugin` 是 Claude Code REPL 内置命令，无法通过 `claude -p` 调用（返回 `Unknown skill: plugin`）。自动化测试流水线（skill-test 阶段 5）不覆盖此安装方式，需在 Claude Code 会话中手动执行。

<!--
### 方式 B — npx（未发布，暂不可用）

```bash
npx patterns
```
-->

### 方式 B — 安装脚本

```bash
# macOS / Linux
git clone https://github.com/easyfan/patterns
cd patterns
./install.sh

# Windows
.\install.ps1
```

```bash
# 选项
./install.sh --dry-run      # 预览变更，不实际写入
./install.sh --uninstall    # 卸载已安装文件
CLAUDE_DIR=/custom ./install.sh   # 指定自定义 Claude 配置目录
```

### 方式 C — 手动

```bash
cp commands/patterns.md        ~/.claude/commands/
cp patterns/agent-monitoring.md ~/.claude/patterns/
```

---

## 使用方式

```
/patterns [pattern_name | --patch [command_name]]
```

| 参数 | 说明 |
|------|------|
| _（无参数）_ | 列出 `~/.claude/patterns/` 中所有模式 |
| `<name>` | 为当前项目实例化指定模式 |
| `--patch` | 扫描所有已知命令并补丁修复缺失的 hook 步骤 |
| `--patch <cmd>` | 仅修复指定命令 |

**示例：**

```
/patterns                              # 查看模式目录（底部含 --patch 提示）
/patterns agent-monitoring             # 配置运行时 agent 监控
/patterns --patch research-module      # 补充缺失的质量门 hook
/patterns --patch                      # 修复所有已知命令
```

---

## 安装的文件

```
~/.claude/
├── commands/
│   └── patterns.md              # /patterns 命令
└── patterns/
    └── agent-monitoring.md      # 运行时 agent 监控模式
```

---

## 依赖要求

- **Claude Code** CLI
- **find**、**stat**（系统工具）——用于模式扫描和时间戳读取
- 无其他依赖

---

## 架构

```
/patterns（协调者）
│
├── 无参数：  Bash — 查找 ~/.claude/patterns/*.md → 列出描述 + --patch 提示
│              （仅元项目）Bash — 扫描 pending proposals
│
├── <name>：  读取模式模板
│              Bash — 探测项目信息（CLAUDE.md 或 shell 探针）
│              填写初始化 prompt 占位符
│              步骤 5a — 检查文件存在性 → 三选项：覆盖/跳过/查看后决定
│              写入 .claude/commands/<cmd>.md + agents（如需）
│              → 步骤 7：/skill-review 质量门（仅在写入了 .claude/commands/ 或 .claude/agents/ 文件时）
│
└── --patch：  Bash — 查找已安装的 command 文件
               Grep — 按精确标题行匹配检测缺失的 hook 步骤
               展示补丁计划 → 等待确认
               Edit — 追加缺失的 hook 步骤
               若无需补丁，输出健康状态确认
```

---

## 实战示例：从模式到运行时安全

2026-03-24，`/news-digest` 推送了一篇 OpenAI Engineering 关于运行时 agent 监控的文章，随后创建了 `agent-monitoring` 模式。下一个会话中，在元项目运行了 `/patterns agent-monitoring`：

1. **模式加载**：从 `~/.claude/patterns/` 读取 `agent-monitoring.md`
2. **项目探测**：找到 `CLAUDE.md`，自动填写项目上下文，无需 shell 探针
3. **文件生成**：
   - `~/.claude/commands/agent-monitoring-workflow.md` — 触发任务后审计的协调者命令
4. **质量门**：用户运行 `/skill-review agent-monitoring-workflow` — 发现 3 条建议，当场全部应用

从模式实例化到审查通过的生产可用命令，全程不到 10 分钟。这就是预期工作流：`/patterns` 在可复用的设计模板与项目专用工具之间架起了桥梁。

---

## 开发

### Evals

`evals/evals.json` 包含 7 个测试用例，覆盖列表、实例化、`--patch` 三种模式的主要分支：

| ID | 场景 | 验证重点 |
|----|------|---------|
| 1 | `/patterns`（无参数列表）| 输出所有可用 pattern 名称和描述，底部含 `--patch` 提示 |
| 2 | `/patterns agent-monitoring`（实例化）| 读取模板，自动探测项目信息，生成 `.claude/` 文件 |
| 3 | `/patterns nonexistent-xyz`（目标不存在）| 输出"未找到"错误，列出可用 pattern 名称 |
| 4 | `/patterns --patch research-module`（单命令补丁）| 检测缺失 hook 步骤，预览补丁计划，等待确认后追加 |
| 5 | 元项目上下文（`.claude/user-level-write` 存在）| 列表模式额外展示 pending proposals |
| 6 | 仅基础设施项目（无 skill-review 安装）| 实例化流程中跳过 `/skill-review` 质量门，不报错 |
| 7 | 目标文件已存在冲突 | 触发三选项（覆盖/跳过/查看后决定），不静默覆盖 |

手动测试（在 Claude Code 会话中）：
```bash
/patterns                       # 对应 eval 1
/patterns agent-monitoring      # 对应 eval 2
/patterns --patch               # 对应 eval 4（扫描所有命令）
```

使用 skill-creator 的 eval loop 批量运行（如已安装）：
```bash
python ~/.claude/skills/skill-creator/scripts/run_loop.py \
  --skill-path ~/.claude/commands/patterns.md \
  --evals-path evals/evals.json
```

---

## 许可证

MIT
