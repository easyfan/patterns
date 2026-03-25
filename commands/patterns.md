---
description: 列出可用 pattern 模板并写入 command/agent 文件，引导实例化工作流，或通过 --patch 修补已实例化命令的 hook 步骤
allowed-tools: ["Bash", "Read", "Write", "Edit", "Grep"]
---
# Pattern 引导器

## 使用方式
```
/patterns                        # 列出所有可用 pattern
/patterns <pattern_name>         # 加载指定 pattern，引导建立工作流
/patterns --patch [command_name] # 修补已实例化命令，追加缺失的 hook 步骤
                                 # 注意：--patch 仅支持以下命令：research-module、research-review
# 实例化成功后，系统将询问是否对新文件执行 /skill-review 质量审查（可跳过）
```

**示例**：
- `/patterns` — 查看所有 pattern
- `/patterns code-deep-research` — 为当前项目建立代码深度研究工作流
- `/patterns research-review-committee` — 为当前项目建立研究审查委员会
- `/patterns --patch research-module` — 修补指定命令，追加缺失 hook

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
/patterns --patch                  # 扫描所有已知命令，修补缺失的 hook 步骤
/patterns --patch research-module  # 只修补指定命令
/patterns --patch research-review  # 只修补指定命令
```

#### 修补目标清单

> 以下是当前完整清单。新增 pattern 时需同步更新本表，否则 `--patch` 无参数模式将遗漏新命令。

| 命令文件名 | 缺失的 hook | 检测标题行 |
|-----------|------------|-----------|
| `research-module.md` | 完成后询问是否运行 `/research-review` | `#### 最终步骤：质量门` |
| `research-review.md` | 🔴严重缺失时建议重新运行 `/research-module` | `#### 最终步骤：研究闭环` |

#### 执行步骤

**Step P1：扫描**

```bash
find "$HOME/.claude/commands" "$(pwd)/.claude/commands" \
  \( -name "research-module.md" -o -name "research-review.md" \) \
  2>/dev/null | sort -u
```

若指定了 `command_name`，只保留匹配项。

若扫描结果为空，输出后退出：
```
未找到可修补的命令文件。
支持修补的命令：research-module、research-review。
请先通过 /patterns <pattern_name> 实例化对应工作流，再执行 --patch。
```

输出扫描结果：
```
🔍 发现以下已实例化命令：
  /path/to/project/.claude/commands/research-module.md
  /path/to/project/.claude/commands/research-review.md
```

**Step P2：逐文件检测**

对每个文件，用 Grep 检测对应 hook 标题行是否已存在：
- `research-module.md` → grep `#### 最终步骤：质量门`
- `research-review.md` → grep `#### 最终步骤：研究闭环`

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
2. 用 Edit 追加对应 hook 步骤：

   **research-module.md 追加内容**：
   ```markdown
   #### 最终步骤：质量门

   文档写入完成后，询问用户：
   > "是否执行 `/research-review <module>` 对产出的设计文档进行质量审查？"
   > 用户说"是"/"继续"则立即触发；说"跳过"则结束。
   ```

   **research-review.md 追加内容（在 Reporter 输出段落末尾）**：
   ```markdown
   #### 最终步骤：研究闭环

   Reporter 生成报告后，若报告含 🔴 严重缺失：
   > "检测到 🔴 严重缺失，建议重新运行 `/research-module <module>` 补充研究，再次审查。"
   ```

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

读取 `$HOME/.claude/patterns/` 目录，列出所有 `.md` 文件：

```bash
find "$HOME/.claude/patterns" -maxdepth 1 -name "*.md" 2>/dev/null
```

若返回空，输出：`暂无可用 pattern，请先在 ~/.claude/patterns/ 目录中添加模板文件。` 后退出。

对每个文件提取 `## 概述` 章节首行作为简介（若无该章节则取文件第二段首行），并追加最后修改时间，输出：

```
📚 可用 Pattern 列表
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  agent-monitoring      运行时 Agent 监控模式，检测规避/scope 溢出/权限异常    (修改: 2026-03-10)
  code-infra            基础代码设施 pattern，快速建立项目级 CI/工具链           (修改: 2026-03-12)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
用法：/patterns <name>  引导建立对应工作流
💡 已实例化命令缺少 hook 步骤？运行 /patterns --patch 一键修补。
（示例，实际列表以当前 ~/.claude/patterns/ 目录为准）
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
  ~/.claude/proposals/patterns/20260313_workspace_code-deep-research.md
  ...
这些 proposal 包含历史 /skill-review 发现的 pattern 级缺口，建议先处理后再实例化（避免实例化已知有缺陷的 pattern）。
选择：(1) 继续实例化  (2) 先查看 proposal 内容  (3) 先执行 /pattern-review <pattern_name>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

- 选 (1) 继续 → 直接进入 Step 1
- 选 (2) 查看 → Read 相关 proposal 文件后，再次询问上述选项
- 选 (3) pattern-review → 提示用户先执行 `/pattern-review <pattern_name>`，完成后重新调用 `/patterns <pattern_name>`，**在此退出**。退出提示输出：`已退出。完成 pattern-review 后，请运行 /patterns <pattern_name> 继续实例化。`

非元项目时跳过此步骤，直接进入 Step 1。

#### Step 1：读取 Pattern 文件

```
$HOME/.claude/patterns/<pattern_name>.md
```

输出：`[加载中] 正在读取 pattern: <name>，分析当前项目结构...`

若文件不存在，先输出 `未找到 pattern：<name>（已查找路径：$HOME/.claude/patterns/<name>.md），以下是可用 pattern 列表：`，再列出可用 pattern 后退出。

#### Step 2：获取当前项目信息（优先读 CLAUDE.md）

输出：`[分析项目] 正在读取项目信息...`

**优先级：**

1. **若项目根目录存在 `CLAUDE.md`**（即已执行过 `/init`）：
   直接读取 `CLAUDE.md` 作为主要上下文——它包含项目定位、目录结构、技术栈等语义信息，
   比 shell 探测更准确。此时几乎无需用户补填占位符。

2. **若 `CLAUDE.md` 不存在**：
   执行 shell 探测作为 fallback：

```bash
# 构建系统 & 语言
ls pom.xml 2>/dev/null && echo "Maven/Java"
ls go.mod 2>/dev/null && echo "Go modules"
ls CMakeLists.txt 2>/dev/null && echo "CMake/C++"
ls Cargo.toml 2>/dev/null && echo "Cargo/Rust"
ls pyproject.toml setup.py 2>/dev/null && echo "Python"
ls package.json 2>/dev/null && echo "Node.js"

# 项目结构
ls -d src/ lib/ app/ internal/ 2>/dev/null | head -5

# 已有文档
find . -name "DESIGN.md" -o -name "ARCHITECTURE.md" 2>/dev/null | head -10
```

构建探测摘要：
```
探测结果：
- 构建系统：Maven / pom.xml
- 语言：Java
- 源码目录：src/main/java/
- 已有设计文档：0 个
- 工作目录：/workspace/order-service
```

#### Step 3：预填 Kickoff Prompt

从 pattern 文件提取 Kickoff Prompt 模板（两个 ``` 之间的内容），
将探测结果自动填入对应占位符 `[...]`，无法确定的保留 `[待填写]`。

若 pattern 文件无 Kickoff Prompt 代码块，输出警告并展示 pattern 全文供手动参考：
> "⚠️ 该 pattern 无 Kickoff Prompt 模板，展示完整 pattern 内容供参考，请手动构造任务描述。"

向用户展示预填结果：

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 Pattern: code-deep-research
已根据当前项目自动填写以下信息：
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ 语言/框架：Java（从 pom.xml 探测）
✅ 构建系统：Maven
⚠️  项目类型：[待填写] — 请描述这个项目做什么
⚠️  模块组织：[待填写] — 例如 com.company.payment
✅ 输出文档路径：docs/design/<module>.md（默认）

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

若存在 `⚠️ [待填写]` 项，进入 Step 4 补全；否则直接进入 Step 5 执行 Kickoff。

#### Step 4：询问缺失信息

若所有占位符均已填写（无 `[待填写]` 项），**跳过本步骤，直接进入 Step 5**，无需等待用户确认。

对每个 `[待填写]` 项，逐一简短询问用户（不要一次问所有）：

```
这个项目主要做什么？（一句话，如"订单支付微服务"）
```

等用户回答后继续下一个，直到所有必填项完成。

#### Step 5：执行 Kickoff

输出：`[执行中] 正在根据 pattern 创建工作流文件...`

将填好的 Kickoff Prompt 作为任务执行——即按照 pattern 中的指引，
**直接为当前项目创建对应的 command 和 agent 文件**，而不是把 prompt 打印出来让用户复制。

**Step 5a：目标文件存在性检查**

对每个待创建文件，先检查是否已存在：
- 不存在 → 继续创建
- 已存在 → 向用户展示：`文件已存在：<路径>，选择：(1)覆盖 (2)跳过 (3)查看当前内容后决定`，等待用户选择后再继续。不得静默覆盖。若用户选 (3)，Read 文件内容展示后，**再次呈现 (1)/(2) 选项**，等待用户做出明确选择。

**Step 5b：写入文件**

输出：`[创建文件] 正在生成 command/agent 文件...`

- 读取 pattern 的设计原则和要求
- 结合探测到的项目信息
- 使用 Write 工具创建新文件（或在用户确认覆盖后覆盖现有文件）。若用户选择"查看后决定"，在用户确认后使用 Edit 工具做最小化修改。
- 生成并写入 `.claude/commands/<command>.md`
- 若 pattern 需要 agents，写入 `.claude/agents/<agent>.md`
- **所有生成的 command/agent 文件的 YAML front-matter 必须包含 `generated-from: <pattern_name>` 字段**，例如：
  ```yaml
  ---
  description: ...
  allowed-tools: [...]
  generated-from: code-deep-research
  ---
  ```
  该字段用于 `/skill-review` 溯源，不影响命令执行行为。
- 向用户展示创建了哪些文件

#### Step 6：完成汇报

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ 工作流建立完成
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

已创建：
  .claude/commands/research-module.md
  .claude/agents/module-analyst-b1.md
  .claude/agents/module-analyst-b2.md
  .claude/agents/module-analyst-b3.md

重启后可用：
  /research-module <module_name>

建议下一步：
  /patterns research-review-committee   # 配套建立审查委员会

⚠️ 新建的 command/agent 文件需重启会话后才可使用（/exit 重启）
💡 未来若命令缺少 hook 步骤，可运行 /patterns --patch 进行修补。
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

#### Step 7：质量门（仅当 Step 5 在 `.claude/commands/` 或 `.claude/agents/` 下写入了新文件时）

**不触发条件**：检查本次通过 Write 或 Edit 操作写入/修改的所有文件路径——若全部文件均不含 `.claude/commands/` 或 `.claude/agents/` 前缀（即只创建了基础设施文件，如 CLAUDE.md、.gitignore、settings.example.json、user-level-write 等）→ 跳过 Step 7，直接结束。（注意：Step 5a 中用户选 (3) 后通过 Edit 修改的文件同样计入此检查。）

输出：
```
是否对新创建的文件执行 /skill-review 质量审查？
  文件：<列出本次创建的 command/agent 文件名，逗号分隔>
  输入"是"/"继续" 立即执行，"跳过" 则省略。
```

等待用户确认：
- 用户说"是"/"继续"/"yes" → 执行 `/skill-review <文件名列表>`（逗号分隔，不含路径和 .md）
- 用户说"跳过"/"不用"/"no" → 结束，不执行审查
