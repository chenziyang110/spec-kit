#!/usr/bin/env bash
# 所有脚本共用的函数与变量

# 通过向上查找 .specify 目录来定位仓库根目录
# 这是 spec-kit 项目的首要标识
find_specify_root() {
    local dir="${1:-$(pwd)}"
    # 规范化为绝对路径，避免相对路径导致死循环
    # 使用 -- 以处理以 - 开头的路径（例如 -P、-L）
    dir="$(cd -- "$dir" 2>/dev/null && pwd)" || return 1
    local prev_dir=""
    while true; do
        if [ -d "$dir/.specify" ]; then
            echo "$dir"
            return 0
        fi
        # 如果已经到达文件系统根目录，或 dirname 不再变化，则停止
        if [ "$dir" = "/" ] || [ "$dir" = "$prev_dir" ]; then
            break
        fi
        prev_dir="$dir"
        dir="$(dirname "$dir")"
    done
    return 1
}

# 获取仓库根目录，优先使用 .specify 而不是 git
# 这样可以避免在 spec-kit 初始化于子目录时误用父级 git 仓库
get_repo_root() {
    # 首先查找 .specify 目录（spec-kit 自身的标识）
    local specify_root
    if specify_root=$(find_specify_root); then
        echo "$specify_root"
        return
    fi

    # 如果未找到 .specify，则退回到 git
    if git rev-parse --show-toplevel >/dev/null 2>&1; then
        git rev-parse --show-toplevel
        return
    fi

    # 对于非 git 仓库，最终退回到脚本所在位置
    local script_dir="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    (cd "$script_dir/../../.." && pwd)
}

# 获取当前分支；对于非 git 仓库提供回退逻辑
get_current_branch() {
    # 先检查是否设置了 SPECIFY_FEATURE 环境变量
    if [[ -n "${SPECIFY_FEATURE:-}" ]]; then
        echo "$SPECIFY_FEATURE"
        return
    fi

    # 然后在 spec-kit 根目录检查 git（不是父目录）
    local repo_root=$(get_repo_root)
    if has_git; then
        git -C "$repo_root" rev-parse --abbrev-ref HEAD
        return
    fi

    # 对于非 git 仓库，尝试找到最新的功能目录
    local specs_dir="$repo_root/specs"

    if [[ -d "$specs_dir" ]]; then
        local latest_feature=""
        local highest=0
        local latest_timestamp=""

        for dir in "$specs_dir"/*; do
            if [[ -d "$dir" ]]; then
                local dirname=$(basename "$dir")
                if [[ "$dirname" =~ ^([0-9]{8}-[0-9]{6})- ]]; then
                    # 基于时间戳的分支：按字典序比较
                    local ts="${BASH_REMATCH[1]}"
                    if [[ "$ts" > "$latest_timestamp" ]]; then
                        latest_timestamp="$ts"
                        latest_feature=$dirname
                    fi
                elif [[ "$dirname" =~ ^([0-9]{3})- ]]; then
                    local number=${BASH_REMATCH[1]}
                    number=$((10#$number))
                    if [[ "$number" -gt "$highest" ]]; then
                        highest=$number
                        # 仅在尚未发现时间戳分支时才更新
                        if [[ -z "$latest_timestamp" ]]; then
                            latest_feature=$dirname
                        fi
                    fi
                fi
            fi
        done

        if [[ -n "$latest_feature" ]]; then
            echo "$latest_feature"
            return
        fi
    fi

    echo "main"  # 最终回退值
}

# 检查 spec-kit 根目录层级是否可用 git
# 仅当 git 已安装且仓库根目录位于 git 工作树内时返回 true
# 同时兼容普通仓库（.git 目录）和 worktree/submodule（.git 文件）
has_git() {
    # 先检查 git 命令是否可用（因为 get_repo_root 本身可能会用到 git）
    command -v git >/dev/null 2>&1 || return 1
    local repo_root=$(get_repo_root)
    # 检查 .git 是否存在（普通仓库是目录，worktree/submodule 可能是文件）
    [ -e "$repo_root/.git" ] || return 1
    # 验证它是否真的是合法的 git 工作树
    git -C "$repo_root" rev-parse --is-inside-work-tree >/dev/null 2>&1
}

check_feature_branch() {
    local branch="$1"
    local has_git_repo="$2"

    # 对于非 git 仓库，无法强制分支命名规则，但仍然给出输出
    if [[ "$has_git_repo" != "true" ]]; then
        echo "[specify] Warning: Git repository not detected; skipped branch validation" >&2
        return 0
    fi

    if [[ ! "$branch" =~ ^[0-9]{3}- ]] && [[ ! "$branch" =~ ^[0-9]{8}-[0-9]{6}- ]]; then
        echo "ERROR: Not on a feature branch. Current branch: $branch" >&2
        echo "Feature branches should be named like: 001-feature-name or 20260319-143022-feature-name" >&2
        return 1
    fi

    return 0
}

get_feature_dir() { echo "$1/specs/$2"; }

# 通过数字前缀而不是精确分支名来查找功能目录
# 这样允许多个分支共同对应同一份规格（例如 004-fix-bug、004-add-feature）
find_feature_dir_by_prefix() {
    local repo_root="$1"
    local branch_name="$2"
    local specs_dir="$repo_root/specs"

    # 从分支名中提取前缀（例如从 "004-whatever" 提取 "004"，或从时间戳分支提取 "20260319-143022"）
    local prefix=""
    if [[ "$branch_name" =~ ^([0-9]{8}-[0-9]{6})- ]]; then
        prefix="${BASH_REMATCH[1]}"
    elif [[ "$branch_name" =~ ^([0-9]{3})- ]]; then
        prefix="${BASH_REMATCH[1]}"
    else
        # 如果分支没有可识别的前缀，则回退到精确匹配
        echo "$specs_dir/$branch_name"
        return
    fi

    # 在 specs/ 中查找以该前缀开头的目录
    local matches=()
    if [[ -d "$specs_dir" ]]; then
        for dir in "$specs_dir"/"$prefix"-*; do
            if [[ -d "$dir" ]]; then
                matches+=("$(basename "$dir")")
            fi
        done
    fi

    # 处理查找结果
    if [[ ${#matches[@]} -eq 0 ]]; then
        # 未找到匹配项：返回按分支名推导的路径（稍后会以清晰错误失败）
        echo "$specs_dir/$branch_name"
    elif [[ ${#matches[@]} -eq 1 ]]; then
        # 恰好一个匹配项：理想情况
        echo "$specs_dir/${matches[0]}"
    else
        # 存在多个匹配项：正常命名规范下不应出现这种情况
        echo "ERROR: Multiple spec directories found with prefix '$prefix': ${matches[*]}" >&2
        echo "Please ensure only one spec directory exists per prefix." >&2
        return 1
    fi
}

get_feature_paths() {
    local repo_root=$(get_repo_root)
    local current_branch=$(get_current_branch)
    local has_git_repo="false"

    if has_git; then
        has_git_repo="true"
    fi

    # 使用基于前缀的查找方式，以支持一份 spec 对应多个分支
    local feature_dir
    if ! feature_dir=$(find_feature_dir_by_prefix "$repo_root" "$current_branch"); then
        echo "ERROR: Failed to resolve feature directory" >&2
        return 1
    fi

    # 使用 printf '%q' 对值进行安全转义，防止因精心构造的分支名
    # 或包含特殊字符的路径导致 shell 注入
    printf 'REPO_ROOT=%q\n' "$repo_root"
    printf 'CURRENT_BRANCH=%q\n' "$current_branch"
    printf 'HAS_GIT=%q\n' "$has_git_repo"
    printf 'FEATURE_DIR=%q\n' "$feature_dir"
    printf 'FEATURE_SPEC=%q\n' "$feature_dir/spec.md"
    printf 'IMPL_PLAN=%q\n' "$feature_dir/plan.md"
    printf 'TASKS=%q\n' "$feature_dir/tasks.md"
    printf 'RESEARCH=%q\n' "$feature_dir/research.md"
    printf 'DATA_MODEL=%q\n' "$feature_dir/data-model.md"
    printf 'QUICKSTART=%q\n' "$feature_dir/quickstart.md"
    printf 'CONTRACTS_DIR=%q\n' "$feature_dir/contracts"
}

# 检查是否可用 jq，以安全构造 JSON
has_jq() {
    command -v jq >/dev/null 2>&1
}

# 对字符串进行转义，以便安全嵌入 JSON 值中（在 jq 不可用时使用）。
# 处理反斜杠、双引号，以及 JSON 要求的控制字符转义（RFC 8259）。
json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\t'/\\t}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\b'/\\b}"
    s="${s//$'\f'/\\f}"
    # 将剩余的 U+0001-U+001F 控制字符转义为 \uXXXX。
    # （U+0000/NUL 不会出现在 bash 字符串中，因此排除。）
    # LC_ALL=C 可确保 ${#s} 按字节计数，${s:$i:1} 每次取一个字节，
    # 从而让多字节 UTF-8 序列（首字节 >= 0xC0）保持原样通过。
    local LC_ALL=C
    local i char code
    for (( i=0; i<${#s}; i++ )); do
        char="${s:$i:1}"
        printf -v code '%d' "'$char" 2>/dev/null || code=256
        if (( code >= 1 && code <= 31 )); then
            printf '\\u%04x' "$code"
        else
            printf '%s' "$char"
        fi
    done
}

check_file() { [[ -f "$1" ]] && echo "  ✓ $2" || echo "  ✗ $2"; }
check_dir() { [[ -d "$1" && -n $(ls -A "$1" 2>/dev/null) ]] && echo "  ✓ $2" || echo "  ✗ $2"; }

# 按优先级栈将模板名解析为文件路径：
#   1. .specify/templates/overrides/
#   2. .specify/presets/<preset-id>/templates/（按 .registry 中的优先级排序）
#   3. .specify/extensions/<ext-id>/templates/
#   4. .specify/templates/（核心模板）
resolve_template() {
    local template_name="$1"
    local repo_root="$2"
    local base="$repo_root/.specify/templates"

    # 优先级 1：项目级覆盖
    local override="$base/overrides/${template_name}.md"
    [ -f "$override" ] && echo "$override" && return 0

    # 优先级 2：已安装的 presets（按 .registry 中的优先级排序）
    local presets_dir="$repo_root/.specify/presets"
    if [ -d "$presets_dir" ]; then
        local registry_file="$presets_dir/.registry"
        if [ -f "$registry_file" ] && command -v python3 >/dev/null 2>&1; then
            # 读取按优先级排序的 preset ID（数字越小优先级越高）。
            # python3 调用被包在 if 条件中，这样即使 python3 非零退出
            # （例如 JSON 非法），也不会因 set -e 直接中止函数。
            local sorted_presets=""
            if sorted_presets=$(SPECKIT_REGISTRY="$registry_file" python3 -c "
import json, sys, os
try:
    with open(os.environ['SPECKIT_REGISTRY']) as f:
        data = json.load(f)
    presets = data.get('presets', {})
    for pid, meta in sorted(presets.items(), key=lambda x: x[1].get('priority', 10)):
        print(pid)
except Exception:
    sys.exit(1)
" 2>/dev/null); then
                if [ -n "$sorted_presets" ]; then
                    # python3 成功并返回了 preset ID：按优先级顺序查找
                    while IFS= read -r preset_id; do
                        local candidate="$presets_dir/$preset_id/templates/${template_name}.md"
                        [ -f "$candidate" ] && echo "$candidate" && return 0
                    done <<< "$sorted_presets"
                fi
                # python3 成功，但 registry 中没有 presets：无需查找
            else
                # python3 失败（缺失，或 registry 解析失败）：回退到无序目录扫描
                for preset in "$presets_dir"/*/; do
                    [ -d "$preset" ] || continue
                    local candidate="$preset/templates/${template_name}.md"
                    [ -f "$candidate" ] && echo "$candidate" && return 0
                done
            fi
        else
            # 回退：按目录字母序（无 python3 可用）
            for preset in "$presets_dir"/*/; do
                [ -d "$preset" ] || continue
                local candidate="$preset/templates/${template_name}.md"
                [ -f "$candidate" ] && echo "$candidate" && return 0
            done
        fi
    fi

    # 优先级 3：扩展提供的模板
    local ext_dir="$repo_root/.specify/extensions"
    if [ -d "$ext_dir" ]; then
        for ext in "$ext_dir"/*/; do
            [ -d "$ext" ] || continue
            # 跳过隐藏目录（例如 .backup、.cache）
            case "$(basename "$ext")" in .*) continue;; esac
            local candidate="$ext/templates/${template_name}.md"
            [ -f "$candidate" ] && echo "$candidate" && return 0
        done
    fi

    # 优先级 4：核心模板
    local core="$base/${template_name}.md"
    [ -f "$core" ] && echo "$core" && return 0

    # 在所有位置中都未找到模板。
    # 返回 1，以便调用方区分“未找到”和“已找到”。
    # 在 set -e 下调用时，应使用：TEMPLATE=$(resolve_template ...) || true
    return 1
}
