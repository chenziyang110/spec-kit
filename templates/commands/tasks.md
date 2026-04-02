---
description: 基于现有设计制品，为该功能生成一份可执行、依赖有序的 tasks.md。
handoffs:
  - label: 一致性分析
    agent: speckit.analyze
    prompt: 运行项目一致性分析
    send: true
  - label: 实施项目
    agent: speckit.implement
    prompt: 按阶段开始实现
    send: true
scripts:
  sh: scripts/bash/check-prerequisites.sh --json
  ps: scripts/powershell/check-prerequisites.ps1 -Json
---

## 用户输入

```text
$ARGUMENTS
```

如果用户输入不为空，你 **MUST** 在继续前先考虑它。

## 执行前检查

**检查扩展钩子（生成任务前）**：
- 检查项目根目录中是否存在 `.specify/extensions.yml`
- 如果存在，则读取并查找 `hooks.before_tasks` 键下的条目
- 如果 YAML 无法解析或非法，则静默跳过钩子检查并正常继续
- 过滤掉 `enabled` 被显式设置为 `false` 的钩子。未设置 `enabled` 的钩子默认视为启用
- 对剩余钩子，**不要**尝试解释或求值其 `condition` 表达式：
  - 若钩子没有 `condition` 字段，或其值为 null/空，则视为可执行
  - 若钩子定义了非空 `condition`，则跳过该钩子，并把条件判断留给 HookExecutor 实现
- 对每个可执行钩子，根据其 `optional` 标志输出以下内容：
  - **可选钩子**（`optional: true`）：
    ```
    ## Extension Hooks

    **Optional Pre-Hook**: {extension}
    Command: `/{command}`
    Description: {description}

    Prompt: {prompt}
    To execute: `/{command}`
    ```
  - **强制钩子**（`optional: false`）：
    ```
    ## Extension Hooks

    **Automatic Pre-Hook**: {extension}
    Executing: `/{command}`
    EXECUTE_COMMAND: {command}

    Wait for the result of the hook command before proceeding to the Outline.
    ```
- 如果没有注册任何钩子，或不存在 `.specify/extensions.yml`，则静默跳过

## 大纲

1. **Setup**：在仓库根目录运行 `{SCRIPT}`，并解析 JSON 中的 `FEATURE_DIR` 与 `AVAILABLE_DOCS`。所有路径都必须是绝对路径。若参数中包含单引号，例如 `"I'm Groot"`，请使用转义写法，例如 `'I'\''m Groot'`（若可以，也可直接使用双引号：`"I'm Groot"`）。

2. **加载设计文档**：从 FEATURE_DIR 读取：
   - **Required**：plan.md（技术栈、库、结构），spec.md（含优先级的用户故事）
   - **Optional**：data-model.md（实体）、contracts/（接口契约）、research.md（决策）、quickstart.md（测试场景）
   - 注意：不是所有项目都会有全部文档。应根据实际可用文档生成任务。

3. **执行任务生成工作流**：
   - 加载 plan.md，提取技术栈、依赖库、项目结构
   - 加载 spec.md，提取用户故事及其优先级（P1、P2、P3 等）
   - 若存在 data-model.md：提取实体并映射到对应用户故事
   - 若存在 contracts/：将接口契约映射到对应用户故事
   - 若存在 research.md：提取决策，用于生成 setup 类任务
   - 按用户故事组织任务（见下方 Task Generation Rules）
   - 生成一个显示用户故事完成顺序的依赖图
   - 为每个用户故事生成并行执行示例
   - 校验任务完整性（每个用户故事都具备所需任务，且可独立测试）

4. **生成 tasks.md**：以 `templates/tasks-template.md` 为结构模板，填充以下内容：
   - 从 plan.md 中提取正确的功能名称
   - Phase 1：准备任务（项目初始化）
   - Phase 2：基础性任务（阻塞所有用户故事的前置条件）
   - Phase 3+：每个用户故事一个阶段（按 spec.md 中优先级顺序）
   - 每个阶段都包含：故事目标、独立测试标准、测试任务（若有要求）、实现任务
   - 最终阶段：打磨与横切关注点
   - 所有任务都必须严格符合 checklist 格式（见下方 Task Generation Rules）
   - 每个任务都要写清晰的文件路径
   - 在 Dependencies 区块中说明各故事的完成顺序
   - 为每个故事给出并行执行示例
   - 在 Implementation Strategy 区块中说明（MVP 优先、增量交付）

5. **报告**：输出生成的 tasks.md 路径，并汇总：
   - 总任务数
   - 每个用户故事对应的任务数
   - 已识别出的并行机会
   - 每个故事的独立测试标准
   - 建议的 MVP 范围（通常仅用户故事 1）
   - 格式校验结果：确认**所有**任务都符合 checklist 格式（checkbox、ID、labels、file paths）

6. **检查扩展钩子**：在 tasks.md 生成后，检查项目根目录中是否存在 `.specify/extensions.yml`
   - 如果存在，则读取并查找 `hooks.after_tasks` 键下的条目
   - 如果 YAML 无法解析或非法，则静默跳过钩子检查并正常继续
   - 过滤掉 `enabled` 被显式设置为 `false` 的钩子。未设置 `enabled` 的钩子默认视为启用
   - 对剩余钩子，**不要**尝试解释或求值其 `condition` 表达式：
     - 若钩子没有 `condition` 字段，或其值为 null/空，则视为可执行
     - 若钩子定义了非空 `condition`，则跳过该钩子，并把条件判断留给 HookExecutor 实现
   - 对每个可执行钩子，根据其 `optional` 标志输出以下内容：
     - **可选钩子**（`optional: true`）：
       ```
       ## Extension Hooks

       **Optional Hook**: {extension}
       Command: `/{command}`
       Description: {description}

       Prompt: {prompt}
       To execute: `/{command}`
       ```
     - **强制钩子**（`optional: false`）：
       ```
       ## Extension Hooks

       **Automatic Hook**: {extension}
       Executing: `/{command}`
       EXECUTE_COMMAND: {command}
       ```
   - 如果没有注册任何钩子，或不存在 `.specify/extensions.yml`，则静默跳过

用于任务生成的上下文：{ARGS}

生成出的 tasks.md 应当可立即执行。也就是说，每个任务都必须具体到足以让一个 LLM 无需额外上下文就能完成。

## 任务生成规则

**CRITICAL**：任务**必须**按用户故事组织，以便支持独立实现与独立测试。

**测试是可选项**：只有在功能规格中明确要求测试，或者用户明确要求采用 TDD 时，才生成测试任务。

### Checklist 格式（必需）

每个任务都必须**严格**符合以下格式：

```text
- [ ] [TaskID] [P?] [Story?] Description with file path
```

**格式组成**：

1. **Checkbox**：必须以 `- [ ]` 开头（Markdown checkbox）
2. **Task ID**：按执行顺序递增编号（T001、T002、T003...）
3. **[P] 标记**：**仅当**该任务可并行时才添加（不同文件，且不依赖尚未完成的任务）
4. **[Story] 标签**：仅用户故事阶段任务**必须**带
   - 格式：`[US1]`、`[US2]`、`[US3]` 等（映射到 spec.md 中的用户故事）
   - Setup 阶段：**不带**
   - Foundational 阶段：**不带**
   - 用户故事阶段：**必须带**
   - Polish 阶段：**不带**
5. **Description**：清晰动作 + 精确文件路径

**示例**：

- 正确：`- [ ] T001 Create project structure per implementation plan`
- 正确：`- [ ] T005 [P] Implement authentication middleware in src/middleware/auth.py`
- 正确：`- [ ] T012 [P] [US1] Create User model in src/models/user.py`
- 正确：`- [ ] T014 [US1] Implement UserService in src/services/user_service.py`
- 错误：`- [ ] Create User model`（缺少 ID 和 Story 标签）
- 错误：`T001 [US1] Create model`（缺少 checkbox）
- 错误：`- [ ] [US1] Create User model`（缺少 Task ID）
- 错误：`- [ ] T001 [US1] Create model`（缺少文件路径）

### 任务组织方式

1. **基于用户故事（spec.md）** - 作为首要组织维度：
   - 每个用户故事（P1、P2、P3...）单独形成一个阶段
   - 将所有相关组件映射到对应故事：
     - 该故事需要的模型
     - 该故事需要的服务
     - 该故事需要的接口/UI
     - 若要求测试：该故事专属的测试
   - 标记故事之间的依赖（大多数故事应尽量保持独立）

2. **基于契约（Contracts）**：
   - 每个接口契约 -> 映射到它服务的用户故事
   - 若要求测试：每个接口契约 -> 在该故事阶段中，先生成一个 `[P]` 契约测试任务，再生成实现任务

3. **基于数据模型（Data Model）**：
   - 将每个实体映射到需要它的用户故事
   - 如果一个实体服务于多个故事：放到最早的故事阶段，或 Setup 阶段
   - 实体关系 -> 在对应故事阶段生成服务层任务

4. **基于准备 / 基础设施**：
   - 共享基础设施 -> Setup 阶段（Phase 1）
   - 基础性 / 阻塞性任务 -> Foundational 阶段（Phase 2）
   - 某个故事专属的准备工作 -> 放到该故事阶段内部

### 阶段结构

- **Phase 1**：准备（项目初始化）
- **Phase 2**：基础性工作（阻塞前置条件，必须先于所有用户故事完成）
- **Phase 3+**：按优先级排列的用户故事（P1、P2、P3...）
  - 每个故事内部顺序：测试（若要求） -> 模型 -> 服务 -> 端点 -> 集成
  - 每个阶段都应形成一个完整、可独立测试的增量
- **最终阶段**：打磨与横切关注点
