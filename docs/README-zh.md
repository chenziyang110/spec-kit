# 中文理解文档索引

这个目录下的中文文档，目标不是翻译 README，而是帮助你理解 Spec Kit 背后的方法论、流程结构和每一步的角色。

建议阅读顺序如下。

---

## 一、先看整体

1. [speckit-command-flow-zh.md](/F:/github/spec-kit/docs/speckit-command-flow-zh.md)
   讲整体命令流、安装层与运行层、文件产物流转。

2. [generalized-spec-methodology-zh.md](/F:/github/spec-kit/docs/generalized-spec-methodology-zh.md)
   讲这套方法论如何抽象成跨领域通用框架。

3. [spec-method-iteration-and-fallback-zh.md](/F:/github/spec-kit/docs/spec-method-iteration-and-fallback-zh.md)
   讲哪些步骤可重复、什么时候该回退到哪一层补。

---

## 二、再看每一步

1. [constitution-explained-zh.md](/F:/github/spec-kit/docs/constitution-explained-zh.md)
   规则层：为什么先定原则、门禁和治理。

2. [specify-explained-zh.md](/F:/github/spec-kit/docs/specify-explained-zh.md)
   目标层：如何把自然语言需求压成 `spec.md`。

3. [clarify-explained-zh.md](/F:/github/spec-kit/docs/clarify-explained-zh.md)
   消歧层：如何把高影响模糊点问清并回写 spec。

4. [plan-explained-zh.md](/F:/github/spec-kit/docs/plan-explained-zh.md)
   方案层：如何把目标翻译成方案、模型、契约和验证路径。

5. [tasks-explained-zh.md](/F:/github/spec-kit/docs/tasks-explained-zh.md)
   拆解层：如何把方案压成任务编排。

6. [analyze-explained-zh.md](/F:/github/spec-kit/docs/analyze-explained-zh.md)
   校验层：如何检查 spec、plan、tasks 是否一致。

7. [implement-explained-zh.md](/F:/github/spec-kit/docs/implement-explained-zh.md)
   执行层：如何按任务真正落地，并回写完成状态。

8. [checklist-explained-zh.md](/F:/github/spec-kit/docs/checklist-explained-zh.md)
   门禁层：为什么 checklist 是需求质量检查，而不是代码测试。

9. [taskstoissues-explained-zh.md](/F:/github/spec-kit/docs/taskstoissues-explained-zh.md)
   协作映射层：如何把任务清单投射到 GitHub Issues。

---

## 三、如果你是为了迁移到别的领域

建议顺序：

1. [generalized-spec-methodology-zh.md](/F:/github/spec-kit/docs/generalized-spec-methodology-zh.md)
2. [spec-method-iteration-and-fallback-zh.md](/F:/github/spec-kit/docs/spec-method-iteration-and-fallback-zh.md)
3. 再按步骤阅读每个 explained 文档

因为这样更容易先抓住抽象框架，再回头看软件实现实例。

