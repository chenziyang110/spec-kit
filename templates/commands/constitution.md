---
description: 通过交互式输入或已有原则输入来创建或更新项目宪章，并确保所有依赖模板保持同步。
handoffs:
  - label: 构建规格说明
    agent: speckit.specify
    prompt: 基于更新后的宪章来编写功能规格。我想构建……
---

## 用户输入

```text
$ARGUMENTS
```

如果用户输入不为空，你 **MUST** 在继续前先考虑它。

## 大纲

你正在更新位于 `.specify/memory/constitution.md` 的项目宪章。该文件是一个 TEMPLATE，包含方括号形式的占位符（例如 `[PROJECT_NAME]`、`[PRINCIPLE_1_NAME]`）。你的工作是：
（a）收集/推导出具体值，
（b）精确填充模板，
（c）把任何修订同步传播到依赖制品中。

**Note**：如果 `.specify/memory/constitution.md` 尚不存在，它本应在项目初始化阶段由 `.specify/templates/constitution-template.md` 复制生成。如果缺失，请先复制模板。

请遵循以下执行流程：

1. 加载现有宪章 `.specify/memory/constitution.md`。
   - 识别所有形如 `[ALL_CAPS_IDENTIFIER]` 的占位符。
   **IMPORTANT**：用户需要的原则数量可能少于或多于模板中的默认数量。如果用户明确给出了数量要求，必须尊重这一点，但仍应遵循整体模板思路，并相应调整文档结构。

2. 收集/推导占位符的值：
   - 如果用户输入（会话内容）已经提供了值，就直接使用。
   - 否则从仓库已有上下文中推断（README、docs、若嵌入了旧版宪章，则也可参考旧版）。
   - 对治理相关日期：
     - `RATIFICATION_DATE` 是最初采纳日期（如果未知，可询问；若无法获知，则标记 TODO）
     - `LAST_AMENDED_DATE` 是今天（若本次有修改）；否则保留旧值
   - `CONSTITUTION_VERSION` 必须按语义化版本规则递增：
     - **MAJOR**：有破坏兼容性的治理/原则删除或重定义
     - **MINOR**：新增原则/章节，或对已有指引进行实质性扩展
     - **PATCH**：澄清、措辞修正、错字修复、非语义性优化
   - 如果版本升级级别存在歧义，应在最终定稿前先给出理由。

3. 起草更新后的宪章内容：
   - 用具体文本替换每一个占位符。除非项目决定故意保留某些模板槽位，否则不得残留方括号占位符；若确实保留，必须明确说明理由。
   - 保持原有标题层级；如果注释在替换后已不再需要，可以删除，除非它仍能提供有价值的说明。
   - 确保每个 Principle 区块都包含：
     - 简洁的原则名称行
     - 一段正文（或若干 bullet），描述不可妥协的规则
     - 若理由并不显然，则补充明确 rationale
   - 确保 Governance 区块明确写出：
     - 修订流程
     - 版本策略
     - 合规性复核要求

4. 一致性传播清单（把原来的 checklist 变成实际校验动作）：
   - 读取 `.specify/templates/plan-template.md`，确保其中任何 “Constitution Check” 或规则与更新后的原则保持一致。
   - 读取 `.specify/templates/spec-template.md`，检查范围/需求结构是否与宪章一致；若宪章新增或移除了必填章节/约束，则同步更新。
   - 读取 `.specify/templates/tasks-template.md`，确保任务分类能反映新的原则驱动任务类型（例如可观测性、版本治理、测试纪律）。
   - 读取 `.specify/templates/commands/*.md` 中的每个命令文件（包括本文件），检查是否残留过时引用（例如本应通用的规则仍写成仅面向某个 agent，如 CLAUDE）。
   - 读取任何运行时指导文档（例如 `README.md`、`docs/quickstart.md`，或若存在的 agent 专属指导文件），并更新其中对原则变更的引用。

5. 生成 Sync Impact Report（更新完成后，以 HTML 注释形式插入到宪章文件顶部）：
   - 版本变化：old -> new
   - 被修改的原则列表（若重命名，则写 old title -> new title）
   - 新增章节
   - 删除章节
   - 需要同步的模板（已更新：✓ / 待处理：⚠），并附文件路径
   - 若有故意延后的占位符或问题，将其列为 Follow-up TODOs

6. 最终输出前校验：
   - 不应残留未经解释的方括号占位符
   - 版本行必须与 Sync Impact Report 一致
   - 日期格式必须为 ISO：YYYY-MM-DD
   - 原则应当是声明式、可验证的，并且避免模糊措辞（例如将 “should” 替换为带理由的 MUST / SHOULD）

7. 将完整的宪章写回 `.specify/memory/constitution.md`（覆盖写入）。

8. 向用户输出最终摘要，内容包括：
   - 新版本号及升级理由
   - 任何需要人工继续跟进的文件
   - 建议的 commit message（例如：`docs: amend constitution to vX.Y.Z (principle additions + governance update)`）

格式与风格要求：

- Markdown 标题层级必须与模板一致（不要升降级）
- 长段落建议换行以提升可读性（理想情况下 <100 字符），但不要为了硬性换行而破坏阅读体验
- 各区块之间保持一个空行
- 不要留下尾随空格

如果用户只提供了部分修改（例如只修改一个原则），你仍然必须执行校验与版本决策流程。

如果关键信息确实缺失（例如 Ratification Date 完全未知），请插入 `TODO(<FIELD_NAME>): explanation`，并在 Sync Impact Report 的 deferred items 中列出。

不要创建新的模板；始终在现有 `.specify/memory/constitution.md` 文件上进行操作。
