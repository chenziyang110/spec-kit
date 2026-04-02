---
description: 基于现有设计制品，将任务清单转换为可执行、依赖有序的 GitHub issues。
tools: ['github/github-mcp-server/issue_write']
scripts:
  sh: scripts/bash/check-prerequisites.sh --json --require-tasks --include-tasks
  ps: scripts/powershell/check-prerequisites.ps1 -Json -RequireTasks -IncludeTasks
---

## 用户输入

```text
$ARGUMENTS
```

如果用户输入不为空，你 **MUST** 在继续前先考虑它。

## 大纲

1. 在仓库根目录运行 `{SCRIPT}`，并解析 `FEATURE_DIR` 与 `AVAILABLE_DOCS`。所有路径都必须是绝对路径。若参数中包含单引号，例如 `"I'm Groot"`，请使用转义写法，例如 `'I'\''m Groot'`（若可以，也可直接使用双引号：`"I'm Groot"`）。
1. 从该脚本的执行结果中提取 **tasks** 文件路径。
1. 通过运行以下命令获取 Git 远端：

```bash
git config --get remote.origin.url
```

> [!CAUTION]
> 只有当远端 URL 是 GitHub URL 时，才可以继续执行后续步骤。

1. 对任务列表中的每一个任务，使用 GitHub MCP server 在与该 Git 远端对应的仓库中创建一个新的 issue。

> [!CAUTION]
> 在任何情况下，都绝不能在与远端 URL 不匹配的仓库中创建 issue。
