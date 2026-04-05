---
name: patterns
description: |
  Use this skill when the user invokes /patterns or /patterns:patterns, or asks to list, instantiate, or patch workflow patterns for their Claude Code project. Triggers on: "/patterns", "list patterns", "load a pattern", "create workflow from pattern", "/patterns --patch", "patch missing hooks", "show available patterns", "instantiate workflow", "set up research workflow". Covers listing bundled plugin templates and ~/.claude/patterns/, auto-filling kickoff prompts from project context, creating command/agent files, and patching existing commands with missing hook steps.
argument-hint: "[pattern_name | --patch [command_name]]"
allowed-tools: ["Bash", "Read", "Write", "Edit", "Grep"]
---
# Pattern 引导器

## 使用方式
```
/patterns:patterns                        # 列出所有可用 pattern
/patterns:patterns <pattern_name>         # 加载指定 pattern，引导建立工作流
/patterns:patterns --patch [command_name] # 修补已实例化命令，追加缺失的 hook 步骤
                                          # --patch 无参数模式动态扫描所有含 generated-from 字段的已实例化命令
# 实例化成功后，系统将询问是否对新文件执行 /skill-review 质量审查（可跳过）
```

**示例**：
- `/patterns:patterns` — 查看所有 pattern
- `/patterns:patterns code-deep-research` — 为当前项目建立代码深度研究工作流
- `/patterns:patterns --patch research-module` — 修补指定命令，追加缺失 hook

---

## 路径解析（每次执行前优先运行）

`$SKILL_FILE` 由 CC 插件运行时注入，指向本 SKILL.md 的绝对路径。通过它推导插件根目录和内置模板目录：

```bash
# $SKILL_FILE 仅在通过 plugin 安装时指向插件 cache；
# 通过 install.sh 安装时指向 ~/.claude/skills/，此时 PLUGIN_TEMPLATES 目录不存在，自动跳过
PLUGIN_ROOT="$(dirname "$(dirname "$SKILL_FILE")")"
PLUGIN_TEMPLATES="$PLUGIN_ROOT/templates"
USER_PATTERNS="$HOME/.claude/patterns"
```

扫描时同时搜索两处，同名文件以用户 patterns 优先（覆盖插件内置）：

```bash
{ find "$USER_PATTERNS" -maxdepth 1 -name "*.md" 2>/dev/null; \
  [ -d "$PLUGIN_TEMPLATES" ] && find "$PLUGIN_TEMPLATES" -maxdepth 1 -name "*.md" 2>/dev/null; } \
  | awk -F/ '!seen[$NF]++' | sort
```

---

## 执行流程

### Step 0：解析参数

- 无参数 → **列出模式**
- `--patch [command_name]` → **修补模式**（见下文）
- 其他参数 → **引导建立**

---

### `--patch` 修补模式

**用法**：
```
/patterns:patterns --patch                  # 扫描所有已知命令，修补缺失的 hook 步骤
/patterns:patterns --patch research-module  # 只修补指定命令
/patterns:patterns --patch research-review  # 只修补指定命令
```

#### 修补目标

`--patch` 无参数模式通过扫描 `generated-from` 字段动态发现所有已实例化命令，无需手动维护清单。每个 pattern 在其文件中声明对应的 hook 标题行（`patch-anchor`），`--patch` 通过读取该字段确定检测目标。

#### 执行步骤

**Step P1：扫描**

```bash
grep -rl "generated-from:" "$HOME/.claude/commands/" "$(pwd)/.claude/commands/" 2>/dev/null | sort -u
```

若指定了 `command_name`，只保留文件名匹配项。

若扫描结果为空，输出后退出：
```
未找到可修补的命令文件（未发现含 generated-from 字段的已实例化命令）。
请先通过 /patterns:patterns <pattern_name> 实例化对应工作流，再执行 --patch。
```

输出扫描结果：
```
🔍 发现以下已实例化命令：
  /path/to/project/.claude/commands/research-module.md
  /path/to/project/.claude/commands/research-review.md
```

**Step P2：逐文件检测**

对每个文件，读取其 `generated-from` 字段确认来源 pattern，再从 `$USER_PATTERNS` 或 `$PLUGIN_TEMPLATES` 读取对应 pattern 文件获取 `patch-anchor`（检测标题行），用 Grep 检测该标题行是否已存在：

```bash
grep -q "<patch-anchor 内容>" <文件路径> && echo "HAS_HOOK" || echo "MISSING_HOOK"
```

若 pattern 文件中未声明 `patch-anchor`，则跳过该文件并提示：`⚠️ <文件名>：无法确定 hook 检测锚点（pattern 未声明 patch-anchor），已跳过。`

分类：
- 已含关键词 → 标记 `✅ 已有 hook，跳过`
- 未含关键词 → 标记 `⚠️ 缺失 hook，待修补`

**Step P3：展示修补计划，等待确认**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔧 --patch 修补计划
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ 已有 hook（跳过）：
  /proj-a/.claude/commands/research-module.md

⚠️ 需修补（将追加最终步骤）：
  /proj-b/.claude/commands/research-module.md
  /proj-b/.claude/commands/research-review.md

输入"继续"执行修补，"取消"退出。
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

等待用户确认。

**Step P4：执行修补**

对每个需修补的文件：
1. Read 完整内容，找到最后一个有意义的章节末尾（通常是"完成汇报"或"最终输出"段落之后）
2. 用 Edit 追加对应 hook 步骤（内容从 pattern 文件的 patch-anchor 段落获取）
3. 输出：`✅ 已修补：<路径>`

**Step P5：汇总**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ --patch 完成
已修补：X 个文件
已跳过：X 个文件（hook 已存在）
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

若已修补=0（即全部跳过），在上述区块后追加一行：
`✅ 所有已实例化命令的 hook 步骤均完整，无需修补。`

---

### 无参数：列出所有 Pattern

先执行路径解析（见上文），然后扫描两处：

```bash
{ find "$USER_PATTERNS" -maxdepth 1 -name "*.md" 2>/dev/null; \
  [ -d "$PLUGIN_TEMPLATES" ] && find "$PLUGIN_TEMPLATES" -maxdepth 1 -name "*.md" 2>/dev/null; } \
  | awk -F/ '!seen[$NF]++' | sort
```

若结果为空，输出：`暂无可用 pattern，请先在 ~/.claude/patterns/ 目录中添加模板文件。` 后退出。

对每个文件提取 `## 概述` 章节首行作为简介（若无该章节则取文件第二段首行），并追加最后修改时间，输出：

```
📚 可用 Pattern 列表
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  agent-monitoring      运行时 Agent 监控模式，检测规避/scope 溢出/权限异常    (修改: 2026-03-10)
  code-infra            基础代码设施 pattern，快速建立项目级 CI/工具链           (修改: 2026-03-12)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
用法：/patterns:patterns <name>  引导建立对应工作流
💡 已实例化命令缺少 hook 步骤？运行 /patterns:patterns --patch 一键修补。
（示例，实际列表以当前目录为准）
```

修改时间通过以下命令获取（跨平台兼容）：
```bash
stat -f "%Sm" -t "%Y-%m-%d" "$f" 2>/dev/null || stat -c "%y" "$f" 2>/dev/null | cut -d' ' -f1
```

**元项目专属：Pending Proposals 检查**

输出 pattern 列表后，检查是否为元项目：

```bash
[ -f "$(pwd)/.claude/user-level-write" ] && echo "META" || echo "NON-META"
```

若为元项目，扫描未处理 proposals：

```bash
find ~/.claude/proposals -name "*.md" 2>/dev/null | \
  xargs grep -L "status: ✅" 2>/dev/null
```

若有未处理文件，在列表末尾追加：

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📬 Pending Proposals（N 个未处理）
  ~/.claude/proposals/patterns/20260313_workspace_code-deep-research.md
  ...
建议处理后再继续，或运行 /pattern-review <name>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

非元项目时跳过此检查，不输出任何 proposal 相关内容。

---

### 有参数：引导建立工作流

#### Step 0.5：Pending Proposals 前置检查（仅限元项目）

检查是否为元项目：

```bash
[ -f "$(pwd)/.claude/user-level-write" ] && echo "META" || echo "NON-META"
```

若为元项目，扫描该 pattern 是否有未处理 proposals：

```bash
find ~/.claude/proposals/patterns -name "*<pattern_name>*.md" 2>/dev/null | \
  xargs grep -L "status: ✅" 2>/dev/null
```

若有未处理文件，输出并等待用户选择：

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📬 发现 <pattern_name> 的 Pending Proposals（N 个未处理）：
  ...
选择：(1) 继续实例化  (2) 先查看 proposal 内容  (3) 先执行 /pattern-review <pattern_name>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

- 选 (1) 继续 → 直接进入 Step 1
- 选 (2) 查看 → Read 相关 proposal 文件后，再次询问上述选项
- 选 (3) pattern-review → 输出 `已退出。完成 pattern-review 后，请运行 /patterns:patterns <pattern_name> 继续实例化。`，退出

非元项目时跳过此步骤，直接进入 Step 1。

#### Step 1：读取 Pattern 文件

先执行路径解析（见上文）。按以下优先级查找 `<pattern_name>.md`：
1. `$USER_PATTERNS/<pattern_name>.md`
2. `$PLUGIN_TEMPLATES/<pattern_name>.md`

输出：`[加载中] 正在读取 pattern: <name>，分析当前项目结构...`

若两处均不存在，先输出 `未找到 pattern：<name>，以下是可用 pattern 列表：`，再列出可用 pattern 后退出。

#### Step 2：获取当前项目信息（优先读 CLAUDE.md）

输出：`[分析项目] 正在读取项目信息...`

**优先级：**

1. **若项目根目录存在 `CLAUDE.md`**：直接读取作为主要上下文。
2. **若 `CLAUDE.md` 不存在**：执行 shell 探测作为 fallback：

```bash
ls pom.xml 2>/dev/null && echo "Maven/Java"
ls go.mod 2>/dev/null && echo "Go modules"
ls CMakeLists.txt 2>/dev/null && echo "CMake/C++"
ls Cargo.toml 2>/dev/null && echo "Cargo/Rust"
ls pyproject.toml setup.py 2>/dev/null && echo "Python"
ls package.json 2>/dev/null && echo "Node.js"
ls -d src/ lib/ app/ internal/ 2>/dev/null | head -5
find . -name "DESIGN.md" -o -name "ARCHITECTURE.md" 2>/dev/null | head -10
```

#### Step 3：预填 Kickoff Prompt

从 pattern 文件提取 Kickoff Prompt 模板：优先提取 `## Kickoff Prompt` 章节标题下的第一个代码块；若无该章节，则回落到 `## 调用格式` 章节下的第一个代码块。
将探测结果自动填入对应占位符 `[...]`，无法确定的保留 `[待填写]`。

若 pattern 文件无上述章节或代码块，输出警告并展示 pattern 全文供手动参考：
> "⚠️ 该 pattern 无 Kickoff Prompt 模板，展示完整 pattern 内容供参考，请手动构造任务描述。"

向用户展示预填结果后，若存在 `⚠️ [待填写]` 项进入 Step 4；否则直接进入 Step 5。

#### Step 4：询问缺失信息

若所有占位符均已填写，跳过本步骤，直接进入 Step 5。

对每个 `[待填写]` 项，逐一简短询问用户。每次提问格式为 `[占位符 N/总数M] <问题>`：

```
[占位符 1/2] 这个项目主要做什么？（一句话，如"订单支付微服务"）
```

等用户回答后继续下一个，直到所有必填项完成。

#### Step 5：执行 Kickoff

输出：`[执行中] 正在根据 pattern 创建工作流文件...`

**Step 5-pre：声明待创建文件清单（强制，在任何写操作前执行）**

基于 Step 1 已读取的 pattern 文件内容推导完整文件清单，向用户输出并锁定：

```
[文件清单] 本次将创建以下文件：
  .claude/commands/<command>.md   ← coordinator command
  .claude/agents/<agent>.md       ← subagent（若有）
（以上清单已锁定，所有文件将强制创建。如需调整，请在此步骤前告知。）
```

**此清单一旦声明不可中途缩减。**

**Step 5a：目标文件存在性检查**

对每个文件，若已存在 → 展示：`文件已存在：<路径>，选择：(1)覆盖 (2)跳过 (3)查看当前内容后决定`，等待用户选择。若用户选 (3)，Read 后**再次呈现 (1)/(2)**，等待明确选择。不得静默覆盖。

**Step 5b：写入文件**

输出：`[创建文件] 正在生成 command/agent 文件...`

使用 Write 工具创建文件。**所有生成的 command/agent 文件的 YAML front-matter 必须包含 `generated-from: <pattern_name>` 字段**：

```yaml
---
description: ...
allowed-tools: [...]
generated-from: code-deep-research
---
```

**Step 5c：写入后验证 generated-from（强制）**

```bash
grep -q "generated-from:" <文件路径> || echo "MISSING"
```

若输出 `MISSING`，**立即** Edit 补入该字段，并输出：`[修复] 已补入 generated-from 字段: <文件路径>`。

**Step 5d：产物完整性校验（强制）**

```bash
ls <文件路径> 2>/dev/null && echo "OK" || echo "MISSING: <文件路径>"
```

若有文件 MISSING：立即创建，输出 `[验证修复] 重新创建了缺失文件: <文件路径>`，然后重新执行 Step 5c。

所有文件均存在后，才可进入 Step 6。

#### Step 6：完成汇报

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ 工作流建立完成
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

已创建：
  .claude/commands/research-module.md
  .claude/agents/module-analyst-b1.md

重启后可用：
  /research-module <module_name>

⚠️ 新建的 command/agent 文件需重启会话后才可使用（/exit 重启）
💡 未来若命令缺少 hook 步骤，可运行 /patterns:patterns --patch 进行修补。
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

#### Step 7：质量门（仅当 Step 5 在 `.claude/commands/` 或 `.claude/agents/` 下写入了新文件时）

**不触发条件**：本次写入/修改的文件路径均不含 `.claude/commands/` 或 `.claude/agents/` 前缀 → 跳过 Step 7，直接结束。

输出：
```
是否对新创建的文件执行 /skill-review 质量审查？
  文件：<列出本次创建的 command/agent 文件名，逗号分隔>
  输入"是"/"继续" 立即执行，"跳过" 则省略。
```

- 用户说"是"/"继续"/"yes" → 执行 `/skill-review <文件名列表>`
- 用户说"跳过"/"不用"/"no" → 结束
