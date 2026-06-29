# Pattern Template 契约规范（TEMPLATE_SPEC）

本文件定义 `/patterns` 引擎（`skills/patterns/SKILL.md`）与 pattern 模板文件之间的**契约**。

任何模板——无论它来自插件内置 `templates/`、用户私有 `~/.claude/patterns/`，还是 benchmark 中由其他模型生成——只要满足本契约，就能被引擎正确**列出 / 实例化 / 修补（--patch）**。引擎依赖本契约，不依赖任何具体模板文件名。

> 阅读对象：模板作者（人或模型）。
> 配套实现：`skills/patterns/SKILL.md`（解析方），`commands/patterns.md`（入口）。

---

## 0. 两类 pattern

| 类型 | 用途 | 是否生成文件 | 必需 Kickoff |
|------|------|------|------|
| **可实例化工作流**（Instantiable Workflow） | `/patterns <name>` 在项目里落地出 command/agent 文件 | 是 | 是 |
| **参考/协议**（Reference / Protocol） | 仅作约定文档供人/其它 pattern 引用（如 `scratch-protocol`） | 否 | 否 |

引擎在**列表模式**下两类都展示；在**实例化模式**下，参考类无 Kickoff，会回落到"展示全文供手动参考"。本契约的"必需项"按类型分别标注。

---

## 1. 文件位置与命名

- 单文件 Markdown，扩展名 `.md`。
- 文件名即 pattern 名（去掉 `.md`）：`code-deep-research.md` → `code-deep-research`。
- 命名用 kebab-case，仅 `[a-z0-9-]`，不含空格/方括号/中文（方括号是 glob 字符类，会引发误删事故）。
- 引擎扫描两处并按用户优先去重：
  - `$HOME/.claude/patterns/`（用户私有，优先）
  - `<plugin>/templates/`（插件内置）
  - 同名时用户私有覆盖内置。

---

## 2. Front-matter（YAML，推荐）

```yaml
---
name: <pattern-name>            # 必须与文件名一致
description: <一句话简介>         # 列表摘要的首选来源（见 §6）
patch-anchor: <hook 标题行原文>   # 可选；声明后才支持 --patch（见 §5）
---
```

- Front-matter 非强制，但**强烈推荐**。缺失时引擎靠正文兜底解析，更脆弱。
- `patch-anchor` 不声明则该 pattern 不参与 `--patch`（引擎会跳过并提示）。

---

## 3. 正文必需章节

### 3.1 可实例化工作流（必需）

| 章节 | 作用 | 引擎如何用 |
|------|------|-----------|
| `# <标题>` | H1 标题 | 展示 |
| `## 概述` | 一句话简介 | 列表摘要首选来源（见 §6） |
| `## 适用场景` 或 `## 使用场景` | 何时该用 | 供用户判断；不被硬解析 |
| `## Kickoff Prompt` | 含一个代码块，带占位符 | 实例化期提取并预填（见 §4） |
| **实例化输出清单** | 声明将创建哪些 command/agent 文件 | Step 5-pre 据此锁定文件清单（见 §7） |

### 3.2 参考/协议（必需）

- `# <标题>`
- `## 概述`
- 协议正文（自由结构）。
- **不含** Kickoff Prompt，**不声明**输出清单。

### 3.3 两类通用可选章节

`## 工作流结构图`、`## 角色与模型分配`、`## Scratch 目录结构`、`## 踩坑记录` / `## 已知陷阱`、`## 前置依赖`、`## 关键设计决策` 等。提升可读性，不被引擎硬解析。

---

## 4. Kickoff Prompt 与占位符语法

### 4.1 提取规则（引擎行为）

实例化时引擎按优先级提取**第一个代码块**：

1. `## Kickoff Prompt` 章节下的第一个代码块（首选）
2. 回落到 `## 调用格式` 章节下的第一个代码块
3. 都没有 → 输出警告并展示 pattern 全文供手动参考

> 因此可实例化工作流**至少**要有 `## Kickoff Prompt` 或 `## 调用格式` 之一，且其下紧跟一个代码块。

### 4.2 两种占位符（语义不同，不可混用）

| 写法 | 名称 | 何时填 | 谁来填 | 引擎是否处理 |
|------|------|--------|--------|------|
| `[占位符描述]` | **实例化期占位符** | `/patterns <name>` 运行时 | 引擎用项目探测结果自动填；填不出的留 `[待填写]` 并逐条问用户 | ✅ 会处理 |
| `{变量名}` | **运行期变量** | 工作流实际执行时 | 原样写入生成文件，由协调者/调用方在运行时替换 | ❌ 原样保留 |

示例：

```
# Kickoff Prompt（实例化期占位符 —— 引擎会填）
请为 [项目一句话描述] 建立 [研究维度数量] 个并行分析的研究工作流。
输出命令名：[命令名]

# 调用格式（运行期变量 —— 原样写入生成文件）
agent_name: {被审查的 agent 名称}
trace_path: {scratch 文件路径}
```

- 实例化期占位符用**方括号 `[...]`**，描述要尽量自解释，便于引擎从 `CLAUDE.md` / 项目探测中匹配。
- 运行期变量用**花括号 `{...}`**，是生成文件里保留的模板变量，不要写成 `[...]`，否则引擎会误填。

---

## 5. `--patch` 契约（可选）

支持 `--patch`（向已实例化命令补缺失 hook）的 pattern 需要：

1. Front-matter 声明 `patch-anchor: <hook 标题行原文>`——引擎用它在已实例化命令中检测 hook 是否存在：
   ```bash
   grep -q "<patch-anchor 内容>" <已实例化命令文件>
   ```
2. 正文有一段对应的 hook 内容（通常是工作流最终步骤，如"完成汇报后调用 agent-monitor"），`--patch` 会把这段追加进缺失的命令文件。

未声明 `patch-anchor` → 引擎跳过该 pattern 并提示 `无法确定 hook 检测锚点，已跳过`。

---

## 6. 列表摘要来源（引擎行为）

列表模式下，每个 pattern 的一行简介按以下优先级取：

1. front-matter 的 `description` 首行
2. `## 概述` 章节首行
3. 正文第二段首行（最后兜底）

> 为稳定起见，**务必**提供 `description` 或 `## 概述` 之一。仅靠"第二段"兜底会随正文改写而漂移。

---

## 7. 实例化输出契约（可实例化工作流）

- pattern 必须能让引擎推导出**完整的待创建文件清单**（command + agent）。在正文用 `## 在新项目中实例化的步骤` / `## 执行规范` 之类章节，明确列出将写入的 `.claude/commands/<x>.md`、`.claude/agents/<y>.md`。
- 引擎在写任何文件前会先**声明并锁定**该清单（Step 5-pre），清单一旦声明不可中途缩减。
- 所有生成的 command/agent 文件，其 YAML front-matter **必须包含**：
  ```yaml
  generated-from: <pattern-name>
  ```
  这是引擎强制注入并校验的字段（Step 5c），用于 `--patch` 反查来源和 `/skill-review` 溯源。模板正文宜用一节"实例化约定"显式说明这点。

---

## 8. 一致性自检清单

实例化工作流模板在提交前应满足：

- [ ] 文件名 kebab-case，与 front-matter `name` 一致
- [ ] 有 `description` 或 `## 概述`（列表摘要稳定）
- [ ] 有 `## Kickoff Prompt`（或 `## 调用格式`）+ 其下一个代码块
- [ ] 代码块里：实例化期空填用 `[...]`，运行期变量用 `{...}`，无混用
- [ ] 正文声明了将创建的 command/agent 文件清单
- [ ] 说明了生成文件需带 `generated-from: <name>`
- [ ] 若要支持 `--patch`：声明了 `patch-anchor` 且正文有对应 hook 段落

参考/协议模板：满足文件名规范 + `## 概述` 即可。

---

## 9. 最小骨架示例（可实例化工作流）

```markdown
---
name: my-workflow
description: 一句话说明这个工作流干什么
patch-anchor: "## 最终步骤：调用 xxx 审查"   # 仅在需要 --patch 时声明
---

# 我的工作流（my-workflow）

## 概述
一句话说明这个工作流干什么。

## 适用场景
- 何时该用、何时不该用。

## Kickoff Prompt
\`\`\`
请为 [项目一句话描述] 建立一个 [角色数量] 个角色并行的工作流。
命令名：[命令名]
运行时每个角色读取 {输入文件路径} 并写入 {scratch 目录}。
\`\`\`

## 在新项目中实例化的步骤
将创建：
- `.claude/commands/[命令名].md`   ← 协调者命令
- `.claude/agents/<role>.md`        ← 子 agent（按角色数量）

## 实例化约定
所有生成文件的 front-matter 必须含 `generated-from: my-workflow`。

## 最终步骤：调用 xxx 审查
（此段为 patch-anchor 对应的 hook 内容，--patch 会据此补全缺失命令。）
```

---

## 附录：现状偏差（待对齐）

截至本规范编写，现存模板与契约存在以下偏差，可作为后续整改清单：

- 无任何模板声明 `## 概述`——列表摘要全靠"第二段"兜底。
- 无任何模板声明 `patch-anchor`——`--patch` 对现存模板全部跳过。
- 仅 `agent-monitoring` 有 front-matter；其余直接 `# 标题` 开头。
- `agent-monitoring` 用 `## 调用格式` + `{...}` 运行期变量（符合契约，但非 `## Kickoff Prompt`）。
- `collaborative-dev`、`scratch-protocol` 属参考/协议类，无 Kickoff（符合 §3.2）。
