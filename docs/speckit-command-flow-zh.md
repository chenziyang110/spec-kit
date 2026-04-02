# Spec Kit 命令流程拆解（中文）

本文整理 Spec Kit 在 Claude Code 等 AI agent 中的实际执行流程，重点说明：

- `specify init --ai <agent>` 做了什么
- `/speckit.*` 命令之间如何衔接
- 每个命令内部大致执行了哪些步骤
- 关键产物（`spec.md`、`plan.md`、`tasks.md` 等）如何流转

说明：

- 对 Claude Code 而言，标准命令名是 `/speckit.specify`，不是 `/speckit.spec`
- 对 Claude 的命令安装目录是 `.claude/commands/`
- 命令源模板位于 `templates/commands/`

---

## 1. 两层结构

Spec Kit 可以理解成两层：

1. **安装层**
   `specify init --ai claude`
   负责把 Spec Kit 的模板、脚本、命令文件安装到你的项目里。

2. **运行层**
   你在 Claude Code 里执行的 `/speckit.constitution`、`/speckit.specify`、`/speckit.plan` 等命令。
   这些命令由命令模板驱动，AI 会按模板中的流程去执行。

换句话说：

- CLI 负责“装配工作流”
- 命令模板负责“定义流程”
- 脚本负责“落地目录、路径、分支和文件”
- AI agent 负责“真正执行每一步推理、写作与修改”

---

## 2. 初始化层：`specify init --ai claude`

当你运行：

```bash
specify init my-project --ai claude
```

大致会做这些事：

1. 读取 `AGENT_CONFIG`
2. 识别目标 agent 为 Claude
3. 选择命令目标目录 `.claude/commands/`
4. 将核心模板复制到 `.specify/templates/`
5. 将核心脚本复制到 `.specify/scripts/`
6. 将 `templates/commands/*.md` 转成 Claude 可执行的命令文件
7. 使 Claude Code 中出现 `/speckit.*` 命令

相关代码位置：

- `AGENT_CONFIG`：`src/specify_cli/__init__.py`
- `init` 入口：`src/specify_cli/__init__.py`
- 核心脚手架：`src/specify_cli/__init__.py` 中的 `scaffold_from_core_pack`
- Claude integration：`src/specify_cli/integrations/claude/__init__.py`

---

## 3. 总体工作流图

```mermaid
flowchart TD
    A[specify init --ai claude] --> B[复制 .specify/templates 与 .specify/scripts]
    B --> C[生成 .claude/commands/speckit.*.md]
    C --> D[在 Claude Code 中可用 /speckit.* 命令]

    D --> E[/speckit.constitution]
    E --> F[/speckit.specify]
    F --> G[/speckit.clarify 可选]
    F --> H[/speckit.plan]
    G --> H
    H --> I[/speckit.checklist 可选]
    H --> J[/speckit.tasks]
    J --> K[/speckit.analyze 可选]
    J --> L[/speckit.implement]
    L --> M[/speckit.taskstoissues 可选]
```

---

## 4. 运行层主流程图

```mermaid
flowchart TD
    A[/speckit.constitution] --> B[更新项目原则与治理]
    B --> C[/speckit.specify]

    C --> C1[before_specify hooks]
    C1 --> C2[create-new-feature 脚本]
    C2 --> C3[创建功能分支与 spec.md]
    C3 --> C4[按 spec-template 填充规格]
    C4 --> C5[生成 requirements checklist]
    C5 --> C6[必要时提 0-3 个澄清问题]
    C6 --> C7[after_specify hooks]

    C7 --> D[/speckit.clarify 可选]
    C7 --> E[/speckit.plan]

    D --> D1[扫描 spec 歧义]
    D1 --> D2[最多 5 轮逐问逐写回]
    D2 --> E

    E --> E1[before_plan hooks]
    E1 --> E2[setup-plan 脚本]
    E2 --> E3[读取 spec + constitution]
    E3 --> E4[生成 plan/research/data-model/contracts/quickstart]
    E4 --> E5[update-agent-context 脚本]
    E5 --> E6[after_plan hooks]

    E6 --> F[/speckit.checklist 可选]
    E6 --> G[/speckit.tasks]

    G --> G1[before_tasks hooks]
    G1 --> G2[读取 plan/spec/可选设计文档]
    G2 --> G3[生成按用户故事组织的 tasks.md]
    G3 --> G4[after_tasks hooks]

    G4 --> H[/speckit.analyze 可选]
    G4 --> I[/speckit.implement]

    I --> I1[before_implement hooks]
    I1 --> I2[检查 checklist 完成度]
    I2 --> I3[读取 tasks/plan/contracts 等]
    I3 --> I4[按阶段执行并回写 [X]]
    I4 --> I5[完成校验]
    I5 --> I6[after_implement hooks]
```

---

## 5. 每个命令内部做什么

### 5.1 `/speckit.constitution`

作用：

- 创建或更新项目宪章
- 写入 `.specify/memory/constitution.md`
- 让后续所有命令都受到项目原则约束

内部流程：

1. 读取现有宪章模板或宪章文件
2. 识别占位符
3. 基于用户输入和仓库上下文填充原则与治理规则
4. 决定版本号变更（MAJOR / MINOR / PATCH）
5. 检查并同步相关模板与命令是否仍然与宪章一致
6. 写回 `.specify/memory/constitution.md`

特点：

- 这一步更多是 AI 直接操作文档
- 不依赖单独的 shell 脚本

---

### 5.2 `/speckit.specify`

作用：

- 把自然语言需求转成 `spec.md`

内部流程：

1. 执行 `before_specify` hooks（如果项目定义了扩展钩子）
2. 调用 `create-new-feature.sh` 或 `create-new-feature.ps1`
3. 创建功能分支
4. 创建功能目录
5. 初始化 `spec.md`
6. 按 `spec-template.md` 结构填充：
   - 用户故事
   - 功能需求（FR）
   - 成功标准（SC）
   - 边界情况
   - 假设
7. 自动生成 `checklists/requirements.md`
8. 对 spec 做质量校验
9. 如果还有关键歧义，则向用户提最多 3 个澄清问题
10. 将答案写回 `spec.md`
11. 执行 `after_specify` hooks

输出产物：

- `specs/<feature>/spec.md`
- `specs/<feature>/checklists/requirements.md`

---

### 5.3 `/speckit.clarify`

作用：

- 针对现有 `spec.md` 做更严格的澄清
- 它是 `/speckit.plan` 之前的风险控制步骤

内部流程：

1. 调用 `check-prerequisites --json --paths-only`
2. 定位当前功能目录与 `spec.md`
3. 按固定分类法扫描规格中的歧义、缺项与非功能要求空白
4. 生成候选问题列表
5. 逐个提问，而不是一次问完
6. 每接受一个答案，就立即写回 `spec.md`
7. 最多进行 5 个问题循环
8. 输出剩余问题、已解决项和建议下一步

特点：

- 它是“渐进式写回”，不是最后一次性覆盖
- 更像 requirements refinement

---

### 5.4 `/speckit.plan`

作用：

- 将需求规格转成技术实施计划与设计制品

内部流程：

1. 执行 `before_plan` hooks
2. 调用 `setup-plan.sh` 或 `setup-plan.ps1`
3. 初始化 `plan.md`
4. 读取 `spec.md` 与 `constitution.md`
5. 填写 Technical Context
6. 填写 Constitution Check
7. 生成 `research.md`
8. 生成 `data-model.md`
9. 生成 `contracts/`
10. 生成 `quickstart.md`
11. 调用 `update-agent-context.sh` 或 `update-agent-context.ps1`
12. 更新 agent 上下文文件（例如 `CLAUDE.md`、`AGENTS.md` 等）
13. 执行 `after_plan` hooks

输出产物：

- `plan.md`
- `research.md`
- `data-model.md`
- `contracts/`
- `quickstart.md`

---

### 5.5 `/speckit.checklist`

作用：

- 生成“需求质量检查清单”
- 不是测试代码，而是测试需求写得是否完整、清晰、一致、可衡量

内部流程：

1. 调用 `check-prerequisites`
2. 读取 spec / plan / tasks 的必要部分
3. 基于用户指定的关注领域生成 checklist
4. 输出到 `specs/<feature>/checklists/*.md`

常见类型：

- `ux.md`
- `security.md`
- `performance.md`
- `api.md`

---

### 5.6 `/speckit.tasks`

作用：

- 将设计制品拆成可以执行的任务列表

内部流程：

1. 执行 `before_tasks` hooks
2. 调用 `check-prerequisites --json`
3. 读取：
   - `plan.md`
   - `spec.md`
   - 可选的 `data-model.md`
   - 可选的 `contracts/`
   - 可选的 `research.md`
   - 可选的 `quickstart.md`
4. 以用户故事为主线组织任务
5. 划分 Setup / Foundational / User Story / Polish 阶段
6. 标注依赖关系与可并行任务
7. 生成 `tasks.md`
8. 执行 `after_tasks` hooks

输出产物：

- `tasks.md`

特点：

- 任务必须严格遵循格式
- 每个任务都应带文件路径
- 每个用户故事都应可独立测试与交付

---

### 5.7 `/speckit.analyze`

作用：

- 在实现前做一次跨制品一致性分析

内部流程：

1. 调用 `check-prerequisites --require-tasks --include-tasks`
2. 读取：
   - `spec.md`
   - `plan.md`
   - `tasks.md`
   - `constitution.md`
3. 建立：
   - 需求清单
   - 用户行为清单
   - 任务覆盖映射
   - 宪章规则集
4. 检测：
   - 重复
   - 歧义
   - 覆盖缺口
   - 宪章冲突
   - 术语漂移
   - 任务与需求脱节
5. 输出只读分析报告

特点：

- 不修改文件
- 更像一致性与覆盖度审查

---

### 5.8 `/speckit.implement`

作用：

- 根据 `tasks.md` 真正开始实现

内部流程：

1. 执行 `before_implement` hooks
2. 调用 `check-prerequisites --require-tasks --include-tasks`
3. 检查 `checklists/` 是否有未完成项
4. 若有未完成项，询问用户是否继续
5. 读取：
   - `tasks.md`
   - `plan.md`
   - `data-model.md`
   - `contracts/`
   - `research.md`
   - `quickstart.md`
6. 检查项目的 ignore 文件与基础配置文件
7. 按阶段执行任务：
   - Setup
   - Foundational
   - 各个 User Story
   - Polish
8. 按要求回写 `tasks.md`，把完成项标成 `[X]`
9. 完成校验
10. 执行 `after_implement` hooks

特点：

- 这是最重的一步
- 它真正进入代码实现阶段
- 不只是“生成代码”，还会做一些环境与项目卫生检查

---

### 5.9 `/speckit.taskstoissues`

作用：

- 把 `tasks.md` 里的任务转换成 GitHub Issues

内部流程：

1. 调用 `check-prerequisites`
2. 定位 `tasks.md`
3. 读取 git remote
4. 确认 remote 指向 GitHub
5. 使用 GitHub MCP server 创建 issue

特点：

- 这是协作层扩展
- 不属于核心 SDD 主链路

---

## 6. 文件产物流转图

```mermaid
flowchart LR
    A[用户需求描述] --> B[/speckit.specify]
    B --> C[spec.md]

    C --> D[/speckit.clarify]
    D --> C

    C --> E[/speckit.plan]
    E --> F[plan.md]
    E --> G[research.md]
    E --> H[data-model.md]
    E --> I[contracts/]
    E --> J[quickstart.md]

    C --> K[/speckit.checklist]
    F --> K
    K --> L[checklists/*.md]

    C --> M[/speckit.tasks]
    F --> M
    G --> M
    H --> M
    I --> M
    J --> M
    M --> N[tasks.md]

    C --> O[/speckit.analyze]
    F --> O
    N --> O

    N --> P[/speckit.implement]
    F --> P
    H --> P
    I --> P
    G --> P
    J --> P
```

---

## 7. Claude Code 中的实际最短主路径

如果你在 Claude Code 中正常使用，最常见的主路径通常是：

```text
/speckit.constitution
/speckit.specify
/speckit.clarify      # 可选但推荐
/speckit.plan
/speckit.tasks
/speckit.analyze      # 可选但推荐
/speckit.implement
```

更偏实用的理解是：

- `constitution`：先定原则
- `specify`：先把“做什么”说清楚
- `clarify`：把模糊处补齐
- `plan`：再决定“怎么做”
- `tasks`：拆成执行项
- `analyze`：实现前再做一次一致性检查
- `implement`：最后开始动手实现

---

## 8. 一句话总结

Spec Kit 不是“一个命令直接生成所有代码”的工具，而是一套**把需求、计划、任务、实现分阶段结构化推进**的工作流系统。

它的核心不只是 CLI，而是这四部分的协作：

- `specify init`：安装工作流
- `templates/commands/*.md`：定义工作流步骤
- `scripts/`：处理路径、分支、文件、上下文
- AI agent：按模板真正执行每个阶段

