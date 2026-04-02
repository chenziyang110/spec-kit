---
description: 基于用户需求，为当前功能生成一份自定义检查清单。
scripts:
  sh: scripts/bash/check-prerequisites.sh --json
  ps: scripts/powershell/check-prerequisites.ps1 -Json
---

## 检查清单用途："英文需求的单元测试（Unit Tests for Requirements Writing）"

**CRITICAL CONCEPT**：检查清单是**针对需求写作的单元测试（UNIT TESTS FOR REQUIREMENTS WRITING）**，用于验证某一领域下需求的质量、清晰度和完整性。

**不是用于验证/测试实现本身：**

- 不要写成 “验证按钮能否正确点击”
- 不要写成 “测试错误处理是否工作”
- 不要写成 “确认 API 返回 200”
- 不要用于检查代码 / 实现是否符合规格

**它应该用于验证需求质量：**

- “是否为所有卡片类型定义了视觉层级要求？”（完整性）
- “`prominent display` 是否被量化为具体尺寸或位置要求？”（清晰度）
- “所有交互元素的 hover 状态要求是否一致？”（一致性）
- “是否定义了键盘导航的无障碍要求？”（覆盖度）
- “规格是否定义了 logo 图片加载失败时的行为？”（边界情况）

**比喻**：如果你的规格说明是用英文写成的代码，那么检查清单就是它的单元测试套件。你要测试的是需求是否写得好、是否完整、是否无歧义、是否可用于实现，而**不是**实现是否已经正确运行。

## 用户输入

```text
$ARGUMENTS
```

如果用户输入不为空，你 **MUST** 在继续前先考虑它。

## 执行步骤

1. **Setup**：在仓库根目录运行 `{SCRIPT}`，并解析 JSON 中的 `FEATURE_DIR` 与 `AVAILABLE_DOCS`。
   - 所有文件路径都必须是绝对路径。
   - 若参数中包含单引号，例如 `"I'm Groot"`，请使用转义写法，例如 `'I'\''m Groot'`（若可以，也可直接使用双引号：`"I'm Groot"`）。

2. **澄清意图（动态生成）**：先生成最多三个初始上下文澄清问题（不要用预设题库）。这些问题必须：
   - 来自用户表述 + 从 spec/plan/tasks 中提取的信号
   - 只询问那些会实质影响检查清单内容的信息
   - 如果在 `$ARGUMENTS` 中已经足够明确，则该问题应单独跳过
   - 优先精准，而不是面面俱到

   生成算法：
   1. 提取信号：功能领域关键词（如 auth、latency、UX、API）、风险提示词（如 “critical”、“must”、“compliance”）、角色线索（如 “QA”、“review”、“security team”），以及显式交付物（如 “a11y”、“rollback”、“contracts”）。
   2. 将信号聚类为候选关注域（最多 4 个），并按相关性排序。
   3. 如果用户未明确说明，则推断可能的受众与使用时机（作者、评审者、QA、发布前）。
   4. 识别缺失维度：范围宽度、深度/严格程度、风险侧重点、排除边界、可衡量验收标准。
   5. 从以下问题原型中构造问题：
      - 范围细化（例如：“这份清单是否应包含与 X、Y 的集成接点，还是只限于本地模块正确性？”）
      - 风险优先级（例如：“这些潜在风险区域中，哪些应被纳入强制门禁检查？”）
      - 深度校准（例如：“这是一份轻量的提交前自检单，还是正式的发布门禁？”）
      - 受众定位（例如：“这份清单是给作者本人使用，还是供同事在 PR 评审时使用？”）
      - 边界排除（例如：“本轮是否应明确排除性能调优项？”）
      - 场景缺口（例如：“未检测到恢复流程，是否应将回滚 / 部分失败路径纳入范围？”）

   问题格式规则：
   - 如果需要呈现选项，请生成一个紧凑表格，列为：Option | Candidate | Why It Matters
   - 选项最多 A-E；若自由回答更清晰，则不要使用表格
   - 不要要求用户重复他们已经说过的话
   - 不要凭空创造类别。若不确定，请显式问：“请确认 X 是否在范围内。”

   当无法交互时，默认值如下：
   - 深度：Standard
   - 受众：如果与代码相关，则默认为 Reviewer（PR）；否则默认为 Author
   - 焦点：选择相关性最高的 2 个关注域

   输出这些问题，并标记为 Q1/Q2/Q3。收到回答后：如果仍有 >=1 类场景（Alternate / Exception / Recovery / 非功能性场景）不清楚，你 **MAY** 再追问最多两个更有针对性的问题（Q4/Q5），并为每个问题附上一行简短理由（例如：“恢复路径风险仍未解决”）。总问题数不得超过 5。若用户明确拒绝继续提问，则不要升级追问。

3. **理解用户请求**：将 `$ARGUMENTS` 与澄清回答合并：
   - 推导检查清单主题（如 security、review、deploy、ux）
   - 汇总用户明确提出的必须包含项
   - 将焦点选择映射为分类骨架
   - 从 spec/plan/tasks 中补足缺失上下文（**不要**脑补）

4. **加载功能上下文**：从 FEATURE_DIR 读取：
   - spec.md：功能需求与范围
   - plan.md（若存在）：技术细节与依赖
   - tasks.md（若存在）：实现任务

   **上下文加载策略：**
   - 只加载与当前关注域相关的必要部分（避免整文件倾倒）
   - 对较长内容，优先提炼为简洁的场景/需求摘要
   - 使用渐进式披露：仅在发现缺口时再继续检索
   - 如果源文档很大，先生成中间摘要项，而不是嵌入大段原文

5. **生成检查清单**：把它作为“需求的单元测试”来写
   - 若不存在，则创建 `FEATURE_DIR/checklists/` 目录
   - 生成唯一的检查清单文件名：
     - 使用简短、具有描述性的领域名（例如 `ux.md`、`api.md`、`security.md`）
     - 格式：`[domain].md`
   - 文件处理行为：
     - 如果文件**不存在**：创建新文件，条目从 CHK001 开始编号
     - 如果文件**已存在**：将新条目追加到文件末尾，并从上一个 CHK ID 继续编号（例如上一个为 CHK015，则从 CHK016 开始）
   - 永远不要删除或覆盖已有检查清单内容，只能保留并追加

   **核心原则：测试需求，而不是测试实现**
   每一项检查都必须评估“需求本身”的：
   - **完整性（Completeness）**：是否列出了所有必要需求？
   - **清晰度（Clarity）**：是否明确、无歧义、足够具体？
   - **一致性（Consistency）**：不同需求之间是否彼此一致？
   - **可衡量性（Measurability）**：是否能客观验证？
   - **覆盖度（Coverage）**：是否覆盖所有场景与边界情况？

   **分类结构**：按需求质量维度分组
   - **需求完整性（Requirement Completeness）**
   - **需求清晰度（Requirement Clarity）**
   - **需求一致性（Requirement Consistency）**
   - **验收标准质量（Acceptance Criteria Quality）**
   - **场景覆盖（Scenario Coverage）**
   - **边界情况覆盖（Edge Case Coverage）**
   - **非功能性需求（Non-Functional Requirements）**（性能、安全、可访问性等是否被明确规定）
   - **依赖与假设（Dependencies & Assumptions）**
   - **歧义与冲突（Ambiguities & Conflicts）**

   **如何撰写检查项：“英文需求的单元测试”**

   错误示例（在测试实现）：
   - “验证首页展示 3 张 episode 卡片”
   - “测试桌面端 hover 状态是否正常”
   - “确认点击 logo 会返回首页”

   正确示例（在测试需求质量）：
   - “是否明确规定了精选 episode 的确切数量与布局？” [Completeness]
   - “`prominent display` 是否被量化为具体尺寸或位置要求？” [Clarity]
   - “所有交互元素的 hover 状态要求是否保持一致？” [Consistency]
   - “是否为所有交互式 UI 定义了键盘可访问性要求？” [Coverage]
   - “当 logo 图片加载失败时，是否定义了降级行为？” [Edge Cases]
   - “是否为异步 episode 数据定义了加载态要求？” [Completeness]
   - “规格是否定义了相互竞争的 UI 元素之间的视觉层级？” [Clarity]

   **条目结构**
   每一项都应遵循以下模式：
   - 使用提问句，询问需求质量
   - 关注 spec/plan 中“写了什么”或“没写什么”
   - 在方括号中标注质量维度，例如 `[Completeness/Clarity/Consistency/etc.]`
   - 若是在核查现有需求，引用规格章节 `[Spec §X.Y]`
   - 若是在检查缺失需求，使用 `[Gap]` 标记

   **按质量维度给出的示例**

   Completeness：
   - “是否为所有 API 失败模式定义了错误处理需求？ [Gap]”
   - “是否为所有交互元素规定了可访问性要求？ [Completeness]”
   - “是否定义了响应式布局的移动端断点要求？ [Gap]”

   Clarity：
   - “`fast loading` 是否被量化为明确的时间阈值？ [Clarity, Spec §NFR-2]”
   - “`related episodes` 的选择标准是否被显式定义？ [Clarity, Spec §FR-5]”
   - “`prominent` 是否被定义为可衡量的视觉属性？ [Ambiguity, Spec §FR-4]”

   Consistency：
   - “各页面之间的导航要求是否相互一致？ [Consistency, Spec §FR-10]”
   - “首页与详情页之间对卡片组件的要求是否一致？ [Consistency]”

   Coverage：
   - “对于零状态场景（没有 episodes）是否有明确需求？ [Coverage, Edge Case]”
   - “是否覆盖并发用户交互场景？ [Coverage, Gap]”
   - “是否规定了部分数据加载失败时的需求？ [Coverage, Exception Flow]”

   Measurability：
   - “视觉层级要求是否可测量/可验证？ [Acceptance Criteria, Spec §FR-1]”
   - “`balanced visual weight` 是否可以被客观验证？ [Measurability, Spec §FR-2]”

   **场景分类与覆盖**（仍然聚焦需求质量）：
   - 检查以下场景类型是否存在需求：主流程、备选流程、异常/错误流程、恢复流程、非功能性场景
   - 对每一类场景，都问：这些需求是否完整、清晰且一致？
   - 如果某类场景缺失：问“这些场景需求是被刻意排除，还是缺失了？ [Gap]”
   - 如果涉及状态变更，应包含韧性/回滚要求，例如：“迁移失败时是否定义了回滚要求？ [Gap]”

   **可追踪性要求（Traceability Requirements）**
   - 最低要求：>=10% 的条目必须包含至少一个可追踪引用
   - 每项应引用：规格章节 `[Spec §X.Y]`，或使用标记 `[Gap]`、`[Ambiguity]`、`[Conflict]`、`[Assumption]`
   - 若不存在 ID 体系：添加一项 “是否已建立需求与验收标准的 ID 体系？ [Traceability]”

   **暴露并定位问题**（需求质量问题）：
   要问的是需求本身的问题，而不是实现问题：
   - 歧义：“`fast` 是否被量化为明确指标？ [Ambiguity, Spec §NFR-1]”
   - 冲突：“§FR-10 与 §FR-10a 的导航需求是否冲突？ [Conflict]”
   - 假设：“`podcast API 永远可用` 这一假设是否被验证？ [Assumption]”
   - 依赖：“是否记录了外部 podcast API 的需求？ [Dependency, Gap]”
   - 缺失定义：“`visual hierarchy` 是否被定义为可衡量标准？ [Gap]”

   **内容合并策略**
   - 软上限：如果原始候选条目 >40，则按风险/影响优先排序
   - 合并近似重复、检查同一需求维度的条目
   - 如果低影响边界情况 >5 项，可合并为一条，例如：
     - “边界情况 X、Y、Z 是否已在需求中覆盖？ [Coverage]”

   **绝对禁止（ABSOLUTELY PROHIBITED）**
   下列写法会把检查清单变成“实现测试”，必须避免：
   - 任何以 “Verify / Test / Confirm / Check” 开头，并直接检查实现行为的条目
   - 提到代码执行、用户操作或系统行为本身
   - 诸如 “displays correctly”、“works properly”、“functions as expected” 的描述
   - 诸如 “click”、“navigate”、“render”、“load”、“execute” 的动作词
   - 测试用例、测试计划、QA 操作步骤
   - 实现细节（框架、API、算法）

   **必须采用的写法模式（REQUIRED PATTERNS）**
   - “是否为 [场景] 定义/规定/记录了 [某类需求]？”
   - “是否用明确标准量化/澄清了 [模糊术语]？”
   - “ [A 章节] 与 [B 章节] 的需求是否一致？”
   - “ [某项需求] 是否能被客观度量/验证？”
   - “需求中是否覆盖了 [边界情况/场景]？”
   - “规格是否定义了 [缺失方面]？”

6. **结构参考**：按 `templates/checklist-template.md` 的规范生成检查清单，包括标题、元信息区块、分类标题与 ID 格式。如果模板不可用，则使用以下兜底结构：一级标题（H1）+ purpose/created 元信息行 + 多个 `##` 分类区块，每个区块内为 `- [ ] CHK### <requirement item>`，ID 全局递增，从 CHK001 开始。

7. **报告**：输出检查清单文件的完整路径、条目数量，以及本次操作是新建文件还是向现有文件追加。并总结：
   - 选定的关注域
   - 深度等级
   - 使用角色 / 使用时机
   - 纳入的、由用户显式指定的 must-have 项

**Important**：每次调用 `/speckit.checklist`，都应使用简短且描述性强的文件名；它要么创建新文件，要么向已有文件追加内容。这样可以支持：

- 多种不同类型的检查清单（例如 `ux.md`、`test.md`、`security.md`）
- 简短易记、用途明确的文件名
- 在 `checklists/` 目录中快速定位与导航

为避免杂乱，请使用清晰的类型命名，并在适当时清理过时的检查清单。

## 示例检查清单类型与样例条目

**UX 需求质量：** `ux.md`

样例条目（测试“需求”，不是测试“实现”）：

- “视觉层级要求是否定义为可衡量标准？ [Clarity, Spec §FR-1]”
- “是否明确规定了 UI 元素的数量与位置？ [Completeness, Spec §FR-1]”
- “交互状态（hover、focus、active）的要求是否一致？ [Consistency]”
- “是否为所有交互元素规定了可访问性要求？ [Coverage, Gap]”
- “图片加载失败时是否定义了降级行为？ [Edge Case, Gap]”
- “`prominent display` 是否可被客观度量？ [Measurability, Spec §FR-4]”

**API 需求质量：** `api.md`

样例条目：

- “是否为所有失败场景规定了错误响应格式？ [Completeness]”
- “是否以明确阈值量化了限流要求？ [Clarity]”
- “所有端点上的认证要求是否一致？ [Consistency]”
- “是否为外部依赖规定了重试/超时需求？ [Coverage, Gap]”
- “是否在需求中记录了版本策略？ [Gap]”

**性能需求质量：** `performance.md`

样例条目：

- “性能需求是否被量化为明确指标？ [Clarity]”
- “是否为所有关键用户旅程定义了性能目标？ [Coverage]”
- “是否规定了不同负载条件下的性能要求？ [Completeness]”
- “性能需求是否可被客观测量？ [Measurability]”
- “高负载场景下是否定义了退化行为要求？ [Edge Case, Gap]”

**安全需求质量：** `security.md`

样例条目：

- “是否为所有受保护资源规定了认证要求？ [Coverage]”
- “是否为敏感信息定义了数据保护要求？ [Completeness]”
- “是否记录了威胁模型，并使需求与其保持一致？ [Traceability]”
- “安全需求是否与合规义务保持一致？ [Consistency]”
- “是否定义了安全失败 / 泄露响应需求？ [Gap, Exception Flow]”

## 反例：不要这样做

**错误：这些是在测试实现，而不是测试需求**

```markdown
- [ ] CHK001 - 验证首页展示 3 张 episode 卡片 [Spec §FR-001]
- [ ] CHK002 - 测试桌面端 hover 状态是否正常 [Spec §FR-003]
- [ ] CHK003 - 确认点击 logo 会跳转首页 [Spec §FR-010]
- [ ] CHK004 - 检查 related episodes 区域是否显示 3-5 项 [Spec §FR-005]
```

**正确：这些是在测试需求质量**

```markdown
- [ ] CHK001 - 是否明确规定了精选 episode 的数量与布局？ [Completeness, Spec §FR-001]
- [ ] CHK002 - 是否为所有交互元素一致地定义了 hover 状态要求？ [Consistency, Spec §FR-003]
- [ ] CHK003 - 是否清晰规定了所有可点击品牌元素的导航要求？ [Clarity, Spec §FR-010]
- [ ] CHK004 - 是否记录了 related episodes 的筛选标准？ [Gap, Spec §FR-005]
- [ ] CHK005 - 是否为异步 episode 数据定义了加载态需求？ [Gap]
- [ ] CHK006 - “视觉层级”要求是否可以被客观衡量？ [Measurability, Spec §FR-001]
```

**关键区别：**

- 错误：检查系统是否运行正确
- 正确：检查需求是否写得正确
- 错误：验证行为是否正确
- 正确：验证需求质量是否达标
- 错误：问 “它有没有做 X？”
- 正确：问 “X 是否被清晰地规定了？”
