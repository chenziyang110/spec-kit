# [PROJECT_NAME] 项目宪章
<!-- 示例：Spec Constitution、TaskFlow Constitution 等 -->

## 核心原则

### [PRINCIPLE_1_NAME]
<!-- 示例：I. 库优先 -->
[PRINCIPLE_1_DESCRIPTION]
<!-- 示例：每个功能都应先作为独立库开始；库必须自包含、可独立测试、具备文档；不得仅因组织结构需要而创建无清晰目的的库 -->

### [PRINCIPLE_2_NAME]
<!-- 示例：II. CLI 接口 -->
[PRINCIPLE_2_DESCRIPTION]
<!-- 示例：每个库都应通过 CLI 暴露能力；文本输入/输出协议：stdin/args -> stdout，错误 -> stderr；支持 JSON 和人类可读格式 -->

### [PRINCIPLE_3_NAME]
<!-- 示例：III. 测试优先（不可谈判） -->
[PRINCIPLE_3_DESCRIPTION]
<!-- 示例：TDD 为强制要求：先写测试 -> 用户批准 -> 测试失败 -> 再实现；严格遵循 Red-Green-Refactor 周期 -->

### [PRINCIPLE_4_NAME]
<!-- 示例：IV. 集成测试 -->
[PRINCIPLE_4_DESCRIPTION]
<!-- 示例：以下重点区域必须具备集成测试：新增库的契约测试、契约变更、服务间通信、共享 schema -->

### [PRINCIPLE_5_NAME]
<!-- 示例：V. 可观测性、VI. 版本与破坏性变更、VII. 简洁性 -->
[PRINCIPLE_5_DESCRIPTION]
<!-- 示例：文本 I/O 保证可调试性；必须提供结构化日志；或：采用 MAJOR.MINOR.BUILD 版本格式；或：从简单方案开始，遵循 YAGNI -->

## [SECTION_2_NAME]
<!-- 示例：附加约束、安全要求、性能标准等 -->

[SECTION_2_CONTENT]
<!-- 示例：技术栈要求、合规标准、部署策略等 -->

## [SECTION_3_NAME]
<!-- 示例：开发流程、评审流程、质量门禁等 -->

[SECTION_3_CONTENT]
<!-- 示例：代码评审要求、测试门禁、部署审批流程等 -->

## 治理
<!-- 示例：宪章优先于其他实践；修订必须包含文档、审批与迁移计划 -->

[GOVERNANCE_RULES]
<!-- 示例：所有 PR/评审都必须验证是否符合本宪章；复杂度必须给出合理性说明；运行时开发指引请参考 [GUIDANCE_FILE] -->

**Version**： [CONSTITUTION_VERSION] | **Ratified**： [RATIFICATION_DATE] | **Last Amended**： [LAST_AMENDED_DATE]
<!-- 示例：Version: 2.1.1 | Ratified: 2025-06-13 | Last Amended: 2025-07-16 -->
