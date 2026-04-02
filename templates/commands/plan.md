---
description: 使用计划模板执行实施规划工作流，并生成设计制品。
handoffs:
  - label: 创建任务
    agent: speckit.tasks
    prompt: 将计划拆解为任务
    send: true
  - label: 创建检查清单
    agent: speckit.checklist
    prompt: 为以下领域创建一份检查清单……
scripts:
  sh: scripts/bash/setup-plan.sh --json
  ps: scripts/powershell/setup-plan.ps1 -Json
agent_scripts:
  sh: scripts/bash/update-agent-context.sh __AGENT__
  ps: scripts/powershell/update-agent-context.ps1 -AgentType __AGENT__
---

## 用户输入

```text
$ARGUMENTS
```

如果用户输入不为空，你 **MUST** 在继续前先考虑它。

## 执行前检查

**检查扩展钩子（规划前）**：
- 检查项目根目录中是否存在 `.specify/extensions.yml`
- 如果存在，则读取并查找 `hooks.before_plan` 键下的条目
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

1. **Setup**：在仓库根目录运行 `{SCRIPT}`，并解析 JSON 中的 `FEATURE_SPEC`、`IMPL_PLAN`、`SPECS_DIR`、`BRANCH`。若参数中包含单引号，例如 `"I'm Groot"`，请使用转义写法，例如 `'I'\''m Groot'`（若可以，也可直接使用双引号：`"I'm Groot"`）。

2. **加载上下文**：读取 `FEATURE_SPEC` 与 `/memory/constitution.md`。加载 IMPL_PLAN 模板（已复制到位）。

3. **执行计划工作流**：按照 IMPL_PLAN 模板中的结构执行：
   - 填写 Technical Context（未知项标记为 `"NEEDS CLARIFICATION"`）
   - 根据 constitution 填写 Constitution Check 区块
   - 评估所有门禁（若存在未被合理说明的违规，则报 ERROR）
   - Phase 0：生成 `research.md`（解决所有 `NEEDS CLARIFICATION`）
   - Phase 1：生成 `data-model.md`、`contracts/`、`quickstart.md`
   - Phase 1：运行 agent 脚本以更新 agent 上下文
   - 在设计后重新执行 Constitution Check

4. **停止并报告**：本命令在完成 Phase 2 规划后结束。报告分支名、IMPL_PLAN 路径及生成的制品。

5. **检查扩展钩子**：报告完成后，检查项目根目录中是否存在 `.specify/extensions.yml`
   - 如果存在，则读取并查找 `hooks.after_plan` 键下的条目
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

## 各阶段

### Phase 0：纲要与调研

1. 从上面的 Technical Context 中提取未知项：
   - 每个 `NEEDS CLARIFICATION` -> 一个 research 任务
   - 每个依赖 -> 一个 best practices 调研任务
   - 每个集成点 -> 一个 patterns 调研任务

2. 生成并派发调研 agent：

   ```text
   对于 Technical Context 中的每个未知项：
     Task: "Research {unknown} for {feature context}"
   对于每个技术选择：
     Task: "Find best practices for {tech} in {domain}"
   ```

3. 将调研结论汇总到 `research.md`，格式如下：
   - Decision: [选择了什么]
   - Rationale: [为什么这样选]
   - Alternatives considered: [还评估了哪些方案]

**Output**：生成 `research.md`，并解决所有 `NEEDS CLARIFICATION`

### Phase 1：设计与契约

**Prerequisites:** `research.md` 已完成

1. 从功能规格中提取实体 -> 写入 `data-model.md`
   - 实体名、字段、关系
   - 来自需求的校验规则
   - 如适用，补充状态迁移

2. 定义接口契约（如果项目存在对外接口）-> 写入 `/contracts/`
   - 识别项目对用户或外部系统暴露了哪些接口
   - 用适合该项目类型的契约格式进行记录
   - 例如：库的公共 API、CLI 工具的命令 schema、Web 服务的 endpoint、解析器的 grammar、应用的 UI contract
   - 如果项目纯属内部使用（构建脚本、一次性工具等），则跳过

3. 更新 agent 上下文：
   - 运行 `{AGENT_SCRIPT}`
   - 这些脚本会识别当前所用的 AI agent
   - 更新对应 agent 专属的上下文文件
   - 仅添加当前计划中新出现的技术
   - 保留标记区域之间的人工补充内容

**Output**：`data-model.md`、`/contracts/*`、`quickstart.md`、agent 专属上下文文件

## 关键规则

- 使用绝对路径
- 只要门禁失败或仍存在未解决澄清项，就报 ERROR
