---
description: 根据自然语言功能描述创建或更新功能规格说明。
handoffs:
  - label: 构建技术计划
    agent: speckit.plan
    prompt: 为该规格创建计划。我将使用……进行构建
  - label: 澄清规格需求
    agent: speckit.clarify
    prompt: 澄清规格需求
    send: true
scripts:
  sh: scripts/bash/create-new-feature.sh "{ARGS}"
  ps: scripts/powershell/create-new-feature.ps1 "{ARGS}"
---

## 用户输入

```text
$ARGUMENTS
```

如果用户输入不为空，你 **MUST** 在继续前先考虑它。

## 执行前检查

**检查扩展钩子（规格创建前）**：
- 检查项目根目录中是否存在 `.specify/extensions.yml`
- 如果存在，则读取并查找 `hooks.before_specify` 键下的条目
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

触发消息中，用户在 `/speckit.specify` 后输入的文本**就是**功能描述。即使下文中 `{ARGS}` 以字面量形式出现，也要假定这段描述在当前对话中始终可用。除非用户给出的是空命令，否则不要要求用户重复描述。

基于该功能描述，执行以下操作：

1. **生成一个简洁的短名称**（2-4 个词）用于分支：
   - 分析功能描述并提取最有意义的关键词
   - 生成一个 2-4 个词的短名称，抓住功能本质
   - 尽量采用“动作-名词”格式（例如 `add-user-auth`、`fix-payment-bug`）
   - 保留技术术语和缩写（OAuth2、API、JWT 等）
   - 保持简洁，但也要足够描述性，方便一眼理解该功能
   - 示例：
     - “I want to add user authentication” -> `user-auth`
     - “Implement OAuth2 integration for the API” -> `oauth2-api-integration`
     - “Create a dashboard for analytics” -> `analytics-dashboard`
     - “Fix payment processing timeout bug” -> `fix-payment-timeout`

2. **创建功能分支**：通过运行脚本，并带上 `--short-name`（以及 `--json`）。
   在 sequential 模式下，**不要**传 `--number`，脚本会自动探测下一个可用编号。
   在 timestamp 模式下，脚本会自动生成 `YYYYMMDD-HHMMSS` 前缀。

   **分支编号模式**：在运行脚本前，检查 `.specify/init-options.json` 是否存在，并读取其中的 `branch_numbering` 值。
   - 如果为 `"timestamp"`，则在脚本调用中追加 `--timestamp`（Bash）或 `-Timestamp`（PowerShell）
   - 如果为 `"sequential"` 或缺失，则不加额外参数（默认行为）

   - Bash 示例：`{SCRIPT} --json --short-name "user-auth" "Add user authentication"`
   - Bash（timestamp）：`{SCRIPT} --json --timestamp --short-name "user-auth" "Add user authentication"`
   - PowerShell 示例：`{SCRIPT} -Json -ShortName "user-auth" "Add user authentication"`
   - PowerShell（timestamp）：`{SCRIPT} -Json -Timestamp -ShortName "user-auth" "Add user authentication"`

   **IMPORTANT**：
   - 不要传 `--number`，脚本会自动确定正确的下一个编号
   - 一定要带 JSON 标志（Bash 用 `--json`，PowerShell 用 `-Json`），以便可靠解析输出
   - 该脚本每个功能只能运行一次
   - 终端输出中的 JSON 就是事实来源，必须从中读取真正的结果
   - JSON 输出中会包含 `BRANCH_NAME` 与 `SPEC_FILE` 路径
   - 若参数中包含单引号，例如 `"I'm Groot"`，请使用转义写法，例如 `'I'\''m Groot'`（若可以，也可直接使用双引号：`"I'm Groot"`）

3. 加载 `templates/spec-template.md`，理解其中要求的章节结构。

4. 按照以下流程执行：

    1. 从输入中解析用户描述
       若为空：报错 `No feature description provided`
    2. 从描述中提取关键概念
       识别：参与者（actors）、动作（actions）、数据（data）、约束（constraints）
    3. 对不清楚之处：
       - 基于上下文与行业常识做出有根据的推断
       - 只有在以下情况下，才使用 `[NEEDS CLARIFICATION: specific question]` 标记：
         - 该选择会显著影响功能范围或用户体验
         - 存在多个合理解释，且它们会导致不同结果
         - 不存在合理默认值
       - **限制：总共最多 3 个 `[NEEDS CLARIFICATION]` 标记**
       - 按影响优先级排序澄清项：范围 > 安全/隐私 > 用户体验 > 技术细节
    4. 填写 User Scenarios & Testing 区块
       如果无法形成清晰的用户流程：报错 `Cannot determine user scenarios`
    5. 生成功能需求（Functional Requirements）
       每条需求都必须可测试
       对未明确说明的细节，采用合理默认值，并在 Assumptions 区块记录
    6. 定义 Success Criteria
       创建可衡量、与技术无关的结果指标
       同时包含定量指标（时间、性能、规模）与定性指标（用户满意度、任务完成率）
       每条标准都必须能在不了解实现细节的情况下验证
    7. 如涉及数据，则识别关键实体（Key Entities）
    8. 返回：SUCCESS（规格已可进入规划阶段）

5. 使用模板结构，将规格写入 `SPEC_FILE`，用从功能描述（参数）中推导出的具体内容替换占位符，同时保持章节顺序与标题层级不变。

6. **规格质量校验**：写入初版 spec 后，按以下标准进行质量校验：

   a. **创建规格质量检查清单**：在 `FEATURE_DIR/checklists/requirements.md` 创建一份检查清单，结构遵循 checklist 模板，并包含以下校验项：

      ```markdown
      # 规格质量检查清单：[FEATURE NAME]

      **Purpose**: 在进入规划前，验证规格说明的完整性与质量
      **Created**: [DATE]
      **Feature**: [指向 spec.md 的链接]

      ## 内容质量

      - [ ] 不包含实现细节（语言、框架、API）
      - [ ] 聚焦用户价值与业务需求
      - [ ] 面向非技术干系人撰写
      - [ ] 所有必填章节均已完成

      ## 需求完整性

      - [ ] 不残留 [NEEDS CLARIFICATION] 标记
      - [ ] 需求可测试且无歧义
      - [ ] 成功标准可衡量
      - [ ] 成功标准与具体技术无关（不出现实现细节）
      - [ ] 所有验收场景都已定义
      - [ ] 已识别边界情况
      - [ ] 范围边界清晰
      - [ ] 已识别依赖与假设

      ## 功能就绪度

      - [ ] 所有功能需求都有清晰的验收标准
      - [ ] 用户场景覆盖核心流程
      - [ ] 功能满足 Success Criteria 中定义的可衡量结果
      - [ ] 规格中没有泄露实现细节

      ## 备注

      - 标记为未完成的项，必须在 `/speckit.clarify` 或 `/speckit.plan` 前修正
      ```

   b. **执行校验**：逐项审查 spec 是否满足检查清单：
      - 对每项给出通过 / 失败结论
      - 记录发现的具体问题（可引用相关 spec 段落）

   c. **处理校验结果**：

      - **如果全部通过**：将检查清单标记为完成，并继续第 7 步

      - **如果存在失败项（不包含 `[NEEDS CLARIFICATION]`）**：
        1. 列出失败项及其具体问题
        2. 更新 spec 以修复每个问题
        3. 重新执行校验，直到全部通过（最多 3 轮）
        4. 如果 3 轮后仍未全部通过，则在检查清单备注中记录剩余问题，并向用户发出警告

      - **如果仍存在 `[NEEDS CLARIFICATION]` 标记**：
        1. 从 spec 中提取所有 `[NEEDS CLARIFICATION: ...]` 标记
        2. **LIMIT CHECK**：如果超过 3 个，只保留最关键的 3 个（按范围 / 安全 / UX 影响排序），其余采用有根据的默认值
        3. 对每一个需要澄清的问题（最多 3 个），按以下格式向用户展示选项：

           ```markdown
           ## Question [N]: [Topic]

           **Context**: [引用相关 spec 段落]

           **What we need to know**: [从 NEEDS CLARIFICATION 标记中提取出的具体问题]

           **Suggested Answers**:

           | Option | Answer | Implications |
           |--------|--------|--------------|
           | A      | [第一个建议答案] | [该选择对功能意味着什么] |
           | B      | [第二个建议答案] | [该选择对功能意味着什么] |
           | C      | [第三个建议答案] | [该选择对功能意味着什么] |
           | Custom | 提供你自己的答案 | [说明如何填写自定义输入] |

           **Your choice**: _[Wait for user response]_
           ```

        4. **CRITICAL - Table Formatting**：确保 Markdown 表格格式正确：
           - 管道符与列间距保持一致
           - 每个单元格内容两侧都要有空格：`| Content |`，不要写成 `|Content|`
           - 表头分隔线每列至少 3 个短横线：`|--------|`
           - 确认表格在 Markdown 预览中能正常渲染
        5. 按顺序编号问题（Q1、Q2、Q3，最多 3 个）
        6. 在等待回答前，一次性呈现全部问题
        7. 等待用户一次性回复所有问题的选择（例如：`Q1: A, Q2: Custom - [details], Q3: B`）
        8. 用用户选定或自定义的答案替换 spec 中的每个 `[NEEDS CLARIFICATION]` 标记
        9. 在所有澄清完成后重新执行校验

   d. **更新检查清单**：每一轮校验后，都要把当前通过/失败状态同步到检查清单文件

7. 报告完成情况，包括：分支名、spec 文件路径、检查清单结果，以及进入下一阶段（`/speckit.clarify` 或 `/speckit.plan`）的就绪情况。

8. **检查扩展钩子**：在报告完成后，检查项目根目录中是否存在 `.specify/extensions.yml`
   - 如果存在，则读取并查找 `hooks.after_specify` 键下的条目
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

**NOTE:** 脚本会先创建并切换到新分支，再初始化 spec 文件，之后才进行写入。

## 快速准则

- 聚焦用户需要的 **WHAT（做什么）** 与 **WHY（为什么）**
- 避免讨论 HOW（如何实现），不要写技术栈、API 或代码结构
- 面向业务干系人，而不是开发者
- 不要在 spec 内嵌入任何检查清单；检查清单应由单独命令生成

### 章节要求

- **Mandatory sections**：每个功能都必须填写
- **Optional sections**：仅在与功能相关时才包含
- 如果某个章节不适用，就直接删除，不要保留成 “N/A”

### 给 AI 生成规格时的要求

1. **做出有根据的推断**：用上下文、行业惯例和常见模式补齐空白
2. **记录假设**：将合理默认值写入 Assumptions 区块
3. **限制澄清项**：最多 3 个 `[NEEDS CLARIFICATION]` 标记，只能用于那些关键决策：
   - 会显著影响功能范围或用户体验
   - 存在多个合理解释且后果不同
   - 没有任何合理默认值
4. **澄清优先级**：范围 > 安全/隐私 > 用户体验 > 技术细节
5. **像测试者一样思考**：任何模糊需求都应该无法通过“可测试且无歧义”这一检查项
6. **常见需要澄清的区域**（仅在没有合理默认值时再问）：
   - 功能范围与边界（是否包括/排除某些用例）
   - 用户类型与权限（如果存在多种互相冲突的合理解释）
   - 安全 / 合规要求（在法律或财务上影响重大时）

**合理默认值示例**（通常不需要为此提问）：

- 数据保留：采用该领域的行业常规
- 性能目标：除非另有说明，否则采用标准 Web / 移动应用预期
- 错误处理：展示用户友好消息，并提供合适的降级方案
- 认证方式：Web 应用默认采用标准会话制或 OAuth2
- 集成模式：采用与项目类型匹配的常见模式（REST/GraphQL 用于 Web 服务，函数调用用于库，CLI 参数用于工具等）

### 成功标准指南

成功标准必须满足：

1. **可衡量**：包含具体指标（时间、百分比、数量、速率）
2. **与技术无关**：不提及框架、语言、数据库或工具
3. **面向用户**：描述用户/业务层面的结果，而不是系统内部机制
4. **可验证**：无需知道实现细节也能验证

**好的例子**：

- “用户可在 3 分钟内完成结账”
- “系统支持 10,000 个并发用户”
- “95% 的搜索在 1 秒内返回结果”
- “任务完成率提升 40%”

**坏的例子**（实现导向）：

- “API 响应时间低于 200ms”（太技术化，改成用户可感知的结果）
- “数据库可处理 1000 TPS”（实现细节，改成用户层指标）
- “React 组件渲染高效”（框架特定）
- “Redis cache 命中率高于 80%”（技术特定）
