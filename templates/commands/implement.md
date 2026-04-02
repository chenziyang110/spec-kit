---
description: 按照 tasks.md 中定义的全部任务，执行实施计划并完成实现。
scripts:
  sh: scripts/bash/check-prerequisites.sh --json --require-tasks --include-tasks
  ps: scripts/powershell/check-prerequisites.ps1 -Json -RequireTasks -IncludeTasks
---

## 用户输入

```text
$ARGUMENTS
```

如果用户输入不为空，你 **MUST** 在继续前先考虑它。

## 执行前检查

**检查扩展钩子（实现前）**：
- 检查项目根目录中是否存在 `.specify/extensions.yml`
- 如果存在，则读取并查找 `hooks.before_implement` 键下的条目
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

1. 在仓库根目录运行 `{SCRIPT}`，并解析 `FEATURE_DIR` 与 `AVAILABLE_DOCS`。所有路径都必须是绝对路径。若参数中包含单引号，例如 `"I'm Groot"`，请使用转义写法，例如 `'I'\''m Groot'`（若可以，也可直接使用双引号：`"I'm Groot"`）。

2. **检查检查清单状态**（如果存在 `FEATURE_DIR/checklists/`）：
   - 扫描 `checklists/` 目录中的所有检查清单文件
   - 对每个检查清单统计：
     - 总条目数：匹配 `- [ ]`、`- [X]` 或 `- [x]` 的所有行
     - 已完成条目数：匹配 `- [X]` 或 `- [x]` 的行
     - 未完成条目数：匹配 `- [ ]` 的行
   - 生成状态表：

     ```text
     | Checklist | Total | Completed | Incomplete | Status |
     |-----------|-------|-----------|------------|--------|
     | ux.md     | 12    | 12        | 0          | PASS |
     | test.md   | 8     | 5         | 3          | FAIL |
     | security.md | 6   | 6         | 0          | PASS |
     ```

   - 计算整体状态：
     - **PASS**：所有检查清单均无未完成项
     - **FAIL**：至少有一个检查清单存在未完成项

   - **如果存在未完成的检查清单**：
     - 显示该表，并展示未完成项数量
     - **停止**并询问用户：`Some checklists are incomplete. Do you want to proceed with implementation anyway? (yes/no)`
     - 等待用户回应后再继续
     - 如果用户回答 `"no"`、`"wait"` 或 `"stop"`，则停止执行
     - 如果用户回答 `"yes"`、`"proceed"` 或 `"continue"`，则继续第 3 步

   - **如果所有检查清单都已完成**：
     - 显示全通过状态表
     - 自动进入第 3 步

3. 加载并分析实现上下文：
   - **必需**：读取 tasks.md，获得完整任务列表与执行计划
   - **必需**：读取 plan.md，获取技术栈、架构与文件结构
   - **若存在**：读取 data-model.md，获取实体与关系
   - **若存在**：读取 contracts/，获取 API 规格与测试要求
   - **若存在**：读取 research.md，获取技术决策与约束
   - **若存在**：读取 quickstart.md，获取集成场景

4. **项目设置校验**：
   - **必需**：根据项目实际情况创建/校验 ignore 文件

   **检测与创建逻辑**：
   - 为判断当前仓库是否是 git 仓库，执行以下命令；如果成功，则创建/校验 `.gitignore`：

     ```sh
     git rev-parse --git-dir 2>/dev/null
     ```

   - 如果存在 Dockerfile* 或 plan.md 中提到了 Docker -> 创建/校验 `.dockerignore`
   - 如果存在 `.eslintrc*` -> 创建/校验 `.eslintignore`
   - 如果存在 `eslint.config.*` -> 确保配置中的 `ignores` 条目包含必要模式
   - 如果存在 `.prettierrc*` -> 创建/校验 `.prettierignore`
   - 如果存在 `.npmrc` 或 `package.json` -> 创建/校验 `.npmignore`（若需要发布）
   - 如果存在 terraform 文件（`*.tf`） -> 创建/校验 `.terraformignore`
   - 如果需要 `.helmignore`（存在 helm chart） -> 创建/校验 `.helmignore`

   **如果 ignore 文件已存在**：验证其是否包含关键模式，只追加缺失的关键模式
   **如果 ignore 文件缺失**：根据检测到的技术栈创建完整模式集

   **按技术栈划分的常见模式**（来自 plan.md 的 tech stack）：
   - **Node.js/JavaScript/TypeScript**：`node_modules/`、`dist/`、`build/`、`*.log`、`.env*`
   - **Python**：`__pycache__/`、`*.pyc`、`.venv/`、`venv/`、`dist/`、`*.egg-info/`
   - **Java**：`target/`、`*.class`、`*.jar`、`.gradle/`、`build/`
   - **C#/.NET**：`bin/`、`obj/`、`*.user`、`*.suo`、`packages/`
   - **Go**：`*.exe`、`*.test`、`vendor/`、`*.out`
   - **Ruby**：`.bundle/`、`log/`、`tmp/`、`*.gem`、`vendor/bundle/`
   - **PHP**：`vendor/`、`*.log`、`*.cache`、`*.env`
   - **Rust**：`target/`、`debug/`、`release/`、`*.rs.bk`、`*.rlib`、`*.prof*`、`.idea/`、`*.log`、`.env*`
   - **Kotlin**：`build/`、`out/`、`.gradle/`、`.idea/`、`*.class`、`*.jar`、`*.iml`、`*.log`、`.env*`
   - **C++**：`build/`、`bin/`、`obj/`、`out/`、`*.o`、`*.so`、`*.a`、`*.exe`、`*.dll`、`.idea/`、`*.log`、`.env*`
   - **C**：`build/`、`bin/`、`obj/`、`out/`、`*.o`、`*.a`、`*.so`、`*.exe`、`*.dll`、`autom4te.cache/`、`config.status`、`config.log`、`.idea/`、`*.log`、`.env*`
   - **Swift**：`.build/`、`DerivedData/`、`*.swiftpm/`、`Packages/`
   - **R**：`.Rproj.user/`、`.Rhistory`、`.RData`、`.Ruserdata`、`*.Rproj`、`packrat/`、`renv/`
   - **通用**：`.DS_Store`、`Thumbs.db`、`*.tmp`、`*.swp`、`.vscode/`、`.idea/`

   **工具专属模式**：
   - **Docker**：`node_modules/`、`.git/`、`Dockerfile*`、`.dockerignore`、`*.log*`、`.env*`、`coverage/`
   - **ESLint**：`node_modules/`、`dist/`、`build/`、`coverage/`、`*.min.js`
   - **Prettier**：`node_modules/`、`dist/`、`build/`、`coverage/`、`package-lock.json`、`yarn.lock`、`pnpm-lock.yaml`
   - **Terraform**：`.terraform/`、`*.tfstate*`、`*.tfvars`、`.terraform.lock.hcl`
   - **Kubernetes/k8s**：`*.secret.yaml`、`secrets/`、`.kube/`、`kubeconfig*`、`*.key`、`*.crt`

5. 解析 tasks.md 结构并提取：
   - **Task phases**：Setup、Tests、Core、Integration、Polish
   - **Task dependencies**：串行与并行执行规则
   - **Task details**：ID、描述、文件路径、并行标记 [P]
   - **Execution flow**：顺序要求与依赖关系

6. 按任务计划执行实现：
   - **按阶段执行**：完成一个阶段后再进入下一阶段
   - **尊重依赖**：串行任务必须按顺序执行；标记 [P] 的并行任务可一起执行
   - **遵循 TDD**：如果存在测试任务，应先执行测试，再执行对应实现任务
   - **基于文件的协调**：影响同一文件的任务必须串行
   - **校验检查点**：每个阶段结束后都要验证，再继续下一个阶段

7. 实现执行规则：
   - **先做准备**：初始化项目结构、依赖与配置
   - **测试先于代码**：如果需要为契约、实体和集成场景编写测试，应先写测试
   - **核心开发**：实现模型、服务、CLI 命令、端点
   - **集成工作**：数据库连接、中间件、日志、外部服务
   - **打磨与校验**：单元测试、性能优化、文档完善

8. 进度跟踪与错误处理：
   - 每完成一个任务都要汇报进度
   - 如果任何非并行任务失败，停止执行
   - 对并行任务 [P]，继续完成成功的任务，并报告失败项
   - 提供带上下文的清晰错误信息，便于调试
   - 如果实现无法继续，给出下一步建议
   - **IMPORTANT**：任务完成后，务必在 tasks 文件中将对应任务标记为 `[X]`

9. 完成校验：
   - 确认所有必需任务都已完成
   - 检查实现是否符合原始规格说明
   - 校验测试是否通过，覆盖率是否满足要求
   - 确认实现是否遵循技术计划
   - 输出最终状态以及完成内容摘要

说明：本命令假定 tasks.md 中已经存在完整的任务拆解。如果任务缺失或不完整，请先运行 `/speckit.tasks` 重新生成任务列表。

10. **检查扩展钩子**：在完成校验之后，检查项目根目录中是否存在 `.specify/extensions.yml`
    - 如果存在，则读取并查找 `hooks.after_implement` 键下的条目
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
