---
description: 对 spec.md、plan.md 与 tasks.md 执行非破坏性的跨制品一致性与质量分析（在任务生成后进行）。
scripts:
  sh: scripts/bash/check-prerequisites.sh --json --require-tasks --include-tasks
  ps: scripts/powershell/check-prerequisites.ps1 -Json -RequireTasks -IncludeTasks
---

## 用户输入

```text
$ARGUMENTS
```

如果用户输入不为空，你 **MUST** 在继续前先考虑它。

## 目标

在开始实现之前，识别三个核心制品（`spec.md`、`plan.md`、`tasks.md`）之间的不一致、重复、歧义，以及描述不足的问题。本命令只能在 `/speckit.tasks` 已成功生成完整 `tasks.md` 之后运行。

## 运行约束

**严格只读（STRICTLY READ-ONLY）**：**不要**修改任何文件。输出一份结构化分析报告。你可以提供一个可选的修复计划，但只有在用户明确批准后，才可以在后续通过手动调用编辑类命令来执行。

**宪章优先级（Constitution Authority）**：在本分析范围内，项目宪章（`/memory/constitution.md`）**不可协商**。与宪章冲突的问题一律自动归为 CRITICAL（严重），必须通过调整 spec、plan 或 tasks 来解决，而不是削弱原则、重新解释原则或静默忽略原则。如果原则本身需要变更，必须通过独立且显式的宪章更新流程完成，不能在 `/speckit.analyze` 中处理。

## 执行步骤

### 1. 初始化分析上下文

在仓库根目录运行一次 `{SCRIPT}`，并解析其中 JSON 的 `FEATURE_DIR` 与 `AVAILABLE_DOCS`。据此推导绝对路径：

- SPEC = FEATURE_DIR/spec.md
- PLAN = FEATURE_DIR/plan.md
- TASKS = FEATURE_DIR/tasks.md

如果任一必需文件缺失，直接报错并提示用户先运行缺失的前置命令。
若参数中包含单引号，例如 `"I'm Groot"`，请使用转义写法，例如 `'I'\''m Groot'`（若可以，也可直接使用双引号：`"I'm Groot"`）。

### 2. 加载制品（渐进式披露）

仅加载完成分析所需的最小上下文：

**来自 spec.md：**

- 概览 / 上下文
- 功能需求（Functional Requirements）
- 成功标准（Success Criteria，可衡量结果，例如性能、安全、可用性、用户成功率、业务影响）
- 用户故事
- 边界情况（若存在）

**来自 plan.md：**

- 架构 / 技术栈选择
- 数据模型引用
- 各阶段划分
- 技术约束

**来自 tasks.md：**

- 任务 ID
- 任务描述
- 阶段分组
- 并行标记 [P]
- 引用的文件路径

**来自 constitution：**

- 加载 `/memory/constitution.md` 以验证原则一致性

### 3. 构建语义模型

在内部创建表示（不要在输出中直接粘贴原始制品）：

- **需求清单（Requirements inventory）**：对每一个 Functional Requirement（FR-###）和 Success Criterion（SC-###）记录一个稳定 key。若存在显式的 FR-/SC- 标识，则以它作为主 key；另外可选地派生一个命令式短语 slug 以增强可读性（例如 “User can upload file” -> `user-can-upload-file`）。只纳入那些需要构建性工作的 Success Criteria（例如压测基础设施、安全审计工具），排除上线后业务结果指标与 KPI（例如“将支持工单减少 50%”）。
- **用户故事 / 行为清单（User story/action inventory）**：离散的用户动作及其验收标准
- **任务覆盖映射（Task coverage mapping）**：将每个任务映射到一个或多个需求或故事（可通过关键字、显式 ID 或关键短语进行推断）
- **宪章规则集（Constitution rule set）**：提取原则名称以及其中带 MUST / SHOULD 的规范性表述

### 4. 检测流程（节省 token 的分析）

聚焦高信号问题。最多输出 50 条发现；超出的部分用汇总说明。

#### A. 重复检测（Duplication Detection）

- 识别近似重复的需求
- 标记质量较低、应合并的表述

#### B. 歧义检测（Ambiguity Detection）

- 标记没有量化标准的模糊形容词，例如 fast、scalable、secure、intuitive、robust
- 标记未解决的占位符，例如 TODO、TKTK、???、`<placeholder>` 等

#### C. 描述不足（Underspecification）

- 有动词但缺少对象或可衡量结果的需求
- 与验收标准不对齐的用户故事
- 在 spec/plan 中未定义却被 tasks 引用的文件或组件

#### D. 宪章一致性（Constitution Alignment）

- 与 MUST 原则冲突的任何需求或计划项
- 宪章要求但缺失的章节或质量门禁

#### E. 覆盖缺口（Coverage Gaps）

- 没有关联任务的需求
- 无法映射到任何需求/故事的任务
- 需要构建性工作的成功标准（性能、安全、可用性）在任务中未体现

#### F. 不一致（Inconsistency）

- 术语漂移（同一概念在不同文件中使用不同名称）
- plan 中出现但 spec 中缺失的数据实体（或反过来）
- 任务顺序矛盾（例如未标注依赖情况下，集成任务早于基础搭建任务）
- 相互冲突的需求（例如一个要求 Next.js，另一个指定 Vue）

### 5. 严重级别分配

使用如下启发式规则进行优先级排序：

- **CRITICAL**：违反宪章 MUST、缺少核心规格制品，或某个需求完全没有覆盖而且会阻塞基线功能
- **HIGH**：重复或冲突的需求、含糊的安全/性能属性、不可测试的验收标准
- **MEDIUM**：术语漂移、非功能性任务覆盖缺失、边界情况描述不足
- **LOW**：风格/措辞改进、对执行顺序无影响的轻微冗余

### 6. 输出精简分析报告

输出一份 Markdown 报告（不要写文件），结构如下：

## 规格分析报告

| ID | Category | Severity | Location(s) | Summary | Recommendation |
|----|----------|----------|-------------|---------|----------------|
| A1 | Duplication | HIGH | spec.md:L120-134 | 两条需求高度相似…… | 合并表述，保留更清晰的一条 |

（每条发现一行；生成稳定 ID，并以类别首字母作为前缀。）

**Coverage Summary Table：**

| Requirement Key | Has Task? | Task IDs | Notes |
|-----------------|-----------|----------|-------|

**Constitution Alignment Issues：**（若有）

**Unmapped Tasks：**（若有）

**Metrics：**

- Total Requirements
- Total Tasks
- Coverage %（有 >=1 个任务覆盖的需求占比）
- Ambiguity Count
- Duplication Count
- Critical Issues Count

### 7. 给出后续动作

在报告结尾，输出一个简洁的 Next Actions 区块：

- 若存在 CRITICAL 问题：建议先解决，再运行 `/speckit.implement`
- 若只有 LOW / MEDIUM：用户可继续推进，同时给出改进建议
- 给出明确命令建议，例如：
  - “使用 `/speckit.specify` 细化规格”
  - “使用 `/speckit.plan` 调整架构”
  - “手动编辑 tasks.md，为 `performance-metrics` 添加覆盖任务”

### 8. 提供修复建议机会

向用户提问：
“要我为最重要的前 N 个问题给出具体修复编辑建议吗？”
（**不要**自动应用任何修改。）

## 运行原则

### 上下文效率

- **以最少 token 输出高信号信息**：专注于可行动的发现，而不是穷尽式说明
- **渐进式披露**：增量加载制品，不要把所有内容一次性塞进分析中
- **输出节省 token**：发现表最多 50 行，超出部分汇总说明
- **结果应可复现**：在文件未变化的情况下重复运行，应产生一致的 ID 与计数

### 分析准则

- **绝不要修改文件**（这是只读分析）
- **绝不要脑补缺失章节**（缺什么就准确报告什么）
- **优先处理宪章冲突**（此类问题永远是 CRITICAL）
- **用具体例子代替泛泛规则**（引用具体实例，而不是泛化描述）
- **优雅地报告零问题**（输出成功报告，并包含覆盖统计）

## 上下文

{ARGS}
