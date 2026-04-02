# 实施计划：[FEATURE]

**Branch**： `[###-feature-name]` | **Date**： [DATE] | **Spec**： [link]
**Input**：来自 `/specs/[###-feature-name]/spec.md` 的功能规格说明

**Note**：本模板由 `/speckit.plan` 命令填写。执行工作流请参见 `.specify/templates/plan-template.md`。

## 摘要

[从功能规格中提取：核心需求 + 基于调研确定的技术方案]

## 技术上下文

<!--
  ACTION REQUIRED：请将本节内容替换为该项目的实际技术细节。
  此处结构仅作为指导，用于帮助推进迭代。
-->

**Language/Version**： [例如 Python 3.11、Swift 5.9、Rust 1.75，或 NEEDS CLARIFICATION]
**Primary Dependencies**： [例如 FastAPI、UIKit、LLVM，或 NEEDS CLARIFICATION]
**Storage**： [如适用，例如 PostgreSQL、CoreData、files，或 N/A]
**Testing**： [例如 pytest、XCTest、cargo test，或 NEEDS CLARIFICATION]
**Target Platform**： [例如 Linux server、iOS 15+、WASM，或 NEEDS CLARIFICATION]
**Project Type**： [例如 library/cli/web-service/mobile-app/compiler/desktop-app，或 NEEDS CLARIFICATION]
**Performance Goals**： [领域相关目标，例如 1000 req/s、10k lines/sec、60 fps，或 NEEDS CLARIFICATION]
**Constraints**： [领域相关约束，例如 <200ms p95、<100MB memory、offline-capable，或 NEEDS CLARIFICATION]
**Scale/Scope**： [领域相关规模，例如 10k users、1M LOC、50 screens，或 NEEDS CLARIFICATION]

## 宪章检查

*GATE：在 Phase 0 调研前必须通过；在 Phase 1 设计后需再次检查。*

[根据宪章文件确定门禁项]

## 项目结构

### 文档（本功能）

```text
specs/[###-feature]/
├── plan.md              # 本文件（/speckit.plan 命令输出）
├── research.md          # Phase 0 输出（/speckit.plan 命令）
├── data-model.md        # Phase 1 输出（/speckit.plan 命令）
├── quickstart.md        # Phase 1 输出（/speckit.plan 命令）
├── contracts/           # Phase 1 输出（/speckit.plan 命令）
└── tasks.md             # Phase 2 输出（/speckit.tasks 命令；不是由 /speckit.plan 创建）
```

### 源代码（仓库根目录）
<!--
  ACTION REQUIRED：请用该功能的实际代码布局替换下面的占位树。
  删除未使用的选项，并将所选结构展开为真实路径（例如 apps/admin、packages/something）。
  最终交付的计划中不应保留 “Option” 标签。
-->

```text
# [REMOVE IF UNUSED] Option 1：单项目（默认）
src/
├── models/
├── services/
├── cli/
└── lib/

tests/
├── contract/
├── integration/
└── unit/

# [REMOVE IF UNUSED] Option 2：Web 应用（当检测到 "frontend" + "backend" 时）
backend/
├── src/
│   ├── models/
│   ├── services/
│   └── api/
└── tests/

frontend/
├── src/
│   ├── components/
│   ├── pages/
│   └── services/
└── tests/

# [REMOVE IF UNUSED] Option 3：移动端 + API（当检测到 "iOS/Android" 时）
api/
└── [同上 backend 结构]

ios/ or android/
└── [平台特定结构：功能模块、UI 流程、平台测试]
```

**Structure Decision**： [说明最终选择了哪种结构，并引用上面列出的真实目录]

## 复杂度跟踪

> **仅当“宪章检查”存在必须说明的违规项时填写**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [例如第 4 个项目] | [当前需求] | [为什么 3 个项目不够] |
| [例如 Repository 模式] | [具体问题] | [为什么直接访问 DB 不足以解决] |
