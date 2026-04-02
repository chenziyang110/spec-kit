#!/usr/bin/env bash

# 使用 plan.md 中的信息更新 agent 上下文文件
#
# 该脚本通过解析功能规格与计划文件，维护 AI agent 的上下文文件，
# 并把项目相关信息同步到各 agent 专属的配置文件中。
#
# 主要功能：
# 1. 环境校验
#    - 校验 git 仓库结构与分支信息
#    - 检查所需的 plan.md 文件与模板
#    - 校验文件权限与可访问性
#
# 2. 计划数据提取
#    - 解析 plan.md 以提取项目元数据
#    - 识别语言/版本、框架、数据库与项目类型
#    - 对缺失或不完整的规格数据做平滑处理
#
# 3. Agent 文件管理
#    - 在需要时从模板创建新的 agent 上下文文件
#    - 使用新的项目信息更新已有 agent 文件
#    - 保留人工补充内容和自定义配置
#    - 支持多种 AI agent 格式与目录结构
#
# 4. 内容生成
#    - 生成与语言相关的构建/测试命令
#    - 生成合适的项目目录结构
#    - 更新技术栈与最近变更区块
#    - 保持格式与时间戳一致
#
# 5. 多 Agent 支持
#    - 处理 agent 专属的文件路径与命名约定
#    - 支持：Claude、Gemini、Copilot、Cursor、Qwen、opencode、Codex、Windsurf、Junie、Kilo Code、Auggie CLI、Roo Code、CodeBuddy CLI、Qoder CLI、Amp、SHAI、Tabnine CLI、Kiro CLI、Mistral Vibe、Kimi Code、Pi Coding Agent、iFlow CLI、Antigravity 以及 Generic
#    - 可更新单个 agent，或批量更新所有已有 agent 文件
#    - 如果没有任何 agent 文件，则默认创建 Claude 文件
#
# 用法：./update-agent-context.sh [agent_type]
# agent 类型：claude|gemini|copilot|cursor-agent|qwen|opencode|codex|windsurf|junie|kilocode|auggie|roo|codebuddy|amp|shai|tabnine|kiro-cli|agy|bob|vibe|qodercli|kimi|trae|pi|iflow|generic
# 为空时表示更新所有已有 agent 文件

set -e

# 启用严格错误处理
set -u
set -o pipefail

#==============================================================================
# 配置与全局变量
#==============================================================================

# 获取脚本目录并加载公共函数
SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# 从公共函数中获取所有路径和变量
_paths_output=$(get_feature_paths) || { echo "ERROR: Failed to resolve feature paths" >&2; exit 1; }
eval "$_paths_output"
unset _paths_output

NEW_PLAN="$IMPL_PLAN"  # Alias for compatibility with existing code
AGENT_TYPE="${1:-}"

# agent 专属文件路径
CLAUDE_FILE="$REPO_ROOT/CLAUDE.md"
GEMINI_FILE="$REPO_ROOT/GEMINI.md"
COPILOT_FILE="$REPO_ROOT/.github/copilot-instructions.md"
CURSOR_FILE="$REPO_ROOT/.cursor/rules/specify-rules.mdc"
QWEN_FILE="$REPO_ROOT/QWEN.md"
AGENTS_FILE="$REPO_ROOT/AGENTS.md"
WINDSURF_FILE="$REPO_ROOT/.windsurf/rules/specify-rules.md"
JUNIE_FILE="$REPO_ROOT/.junie/AGENTS.md"
KILOCODE_FILE="$REPO_ROOT/.kilocode/rules/specify-rules.md"
AUGGIE_FILE="$REPO_ROOT/.augment/rules/specify-rules.md"
ROO_FILE="$REPO_ROOT/.roo/rules/specify-rules.md"
CODEBUDDY_FILE="$REPO_ROOT/CODEBUDDY.md"
QODER_FILE="$REPO_ROOT/QODER.md"
# Amp、Kiro CLI、IBM Bob 和 Pi 共用 AGENTS.md
# 使用 AGENTS_FILE 可避免同一文件被重复更新多次。
AMP_FILE="$AGENTS_FILE"
SHAI_FILE="$REPO_ROOT/SHAI.md"
TABNINE_FILE="$REPO_ROOT/TABNINE.md"
KIRO_FILE="$AGENTS_FILE"
AGY_FILE="$REPO_ROOT/.agent/rules/specify-rules.md"
BOB_FILE="$AGENTS_FILE"
VIBE_FILE="$REPO_ROOT/.vibe/agents/specify-agents.md"
KIMI_FILE="$REPO_ROOT/KIMI.md"
TRAE_FILE="$REPO_ROOT/.trae/rules/AGENTS.md"
IFLOW_FILE="$REPO_ROOT/IFLOW.md"

# 模板文件
TEMPLATE_FILE="$REPO_ROOT/.specify/templates/agent-file-template.md"

# 存放解析后 plan 数据的全局变量
NEW_LANG=""
NEW_FRAMEWORK=""
NEW_DB=""
NEW_PROJECT_TYPE=""

#==============================================================================
# 工具函数
#==============================================================================

log_info() {
    echo "INFO: $1"
}

log_success() {
    echo "✓ $1"
}

log_error() {
    echo "ERROR: $1" >&2
}

log_warning() {
    echo "WARNING: $1" >&2
}

# 用于清理临时文件的函数
cleanup() {
    local exit_code=$?
    # 解除 trap，避免重复进入清理逻辑
    trap - EXIT INT TERM
    rm -f /tmp/agent_update_*_$$
    rm -f /tmp/manual_additions_$$
    exit $exit_code
}

# 设置清理 trap
trap cleanup EXIT INT TERM

#==============================================================================
# 校验函数
#==============================================================================

validate_environment() {
    # 检查当前是否存在功能分支/功能上下文（兼容 git 与非 git）
    if [[ -z "$CURRENT_BRANCH" ]]; then
        log_error "Unable to determine current feature"
        if [[ "$HAS_GIT" == "true" ]]; then
            log_info "Make sure you're on a feature branch"
        else
            log_info "Set SPECIFY_FEATURE environment variable or create a feature first"
        fi
        exit 1
    fi
    
    # 检查 plan.md 是否存在
    if [[ ! -f "$NEW_PLAN" ]]; then
        log_error "No plan.md found at $NEW_PLAN"
        log_info "Make sure you're working on a feature with a corresponding spec directory"
        if [[ "$HAS_GIT" != "true" ]]; then
            log_info "Use: export SPECIFY_FEATURE=your-feature-name or create a new feature first"
        fi
        exit 1
    fi
    
    # 检查模板是否存在（创建新文件时需要）
    if [[ ! -f "$TEMPLATE_FILE" ]]; then
        log_warning "Template file not found at $TEMPLATE_FILE"
        log_warning "Creating new agent files will fail"
    fi
}

#==============================================================================
# Plan 解析函数
#==============================================================================

extract_plan_field() {
    local field_pattern="$1"
    local plan_file="$2"
    
    grep "^\*\*${field_pattern}\*\*: " "$plan_file" 2>/dev/null | \
        head -1 | \
        sed "s|^\*\*${field_pattern}\*\*: ||" | \
        sed 's/^[ \t]*//;s/[ \t]*$//' | \
        grep -v "NEEDS CLARIFICATION" | \
        grep -v "^N/A$" || echo ""
}

parse_plan_data() {
    local plan_file="$1"
    
    if [[ ! -f "$plan_file" ]]; then
        log_error "Plan file not found: $plan_file"
        return 1
    fi
    
    if [[ ! -r "$plan_file" ]]; then
        log_error "Plan file is not readable: $plan_file"
        return 1
    fi
    
    log_info "Parsing plan data from $plan_file"
    
    NEW_LANG=$(extract_plan_field "Language/Version" "$plan_file")
    NEW_FRAMEWORK=$(extract_plan_field "Primary Dependencies" "$plan_file")
    NEW_DB=$(extract_plan_field "Storage" "$plan_file")
    NEW_PROJECT_TYPE=$(extract_plan_field "Project Type" "$plan_file")
    
    # 记录已发现的信息
    if [[ -n "$NEW_LANG" ]]; then
        log_info "Found language: $NEW_LANG"
    else
        log_warning "No language information found in plan"
    fi
    
    if [[ -n "$NEW_FRAMEWORK" ]]; then
        log_info "Found framework: $NEW_FRAMEWORK"
    fi
    
    if [[ -n "$NEW_DB" ]] && [[ "$NEW_DB" != "N/A" ]]; then
        log_info "Found database: $NEW_DB"
    fi
    
    if [[ -n "$NEW_PROJECT_TYPE" ]]; then
        log_info "Found project type: $NEW_PROJECT_TYPE"
    fi
}

format_technology_stack() {
    local lang="$1"
    local framework="$2"
    local parts=()
    
    # 添加非空部分
    [[ -n "$lang" && "$lang" != "NEEDS CLARIFICATION" ]] && parts+=("$lang")
    [[ -n "$framework" && "$framework" != "NEEDS CLARIFICATION" && "$framework" != "N/A" ]] && parts+=("$framework")
    
    # 按正确格式拼接
    if [[ ${#parts[@]} -eq 0 ]]; then
        echo ""
    elif [[ ${#parts[@]} -eq 1 ]]; then
        echo "${parts[0]}"
    else
        # 多个部分之间用 " + " 连接
        local result="${parts[0]}"
        for ((i=1; i<${#parts[@]}; i++)); do
            result="$result + ${parts[i]}"
        done
        echo "$result"
    fi
}

#==============================================================================
# 模板与内容生成函数
#==============================================================================

get_project_structure() {
    local project_type="$1"
    
    if [[ "$project_type" == *"web"* ]]; then
        echo "backend/\\nfrontend/\\ntests/"
    else
        echo "src/\\ntests/"
    fi
}

get_commands_for_language() {
    local lang="$1"
    
    case "$lang" in
        *"Python"*)
            echo "cd src && pytest && ruff check ."
            ;;
        *"Rust"*)
            echo "cargo test && cargo clippy"
            ;;
        *"JavaScript"*|*"TypeScript"*)
            echo "npm test \\&\\& npm run lint"
            ;;
        *)
            echo "# Add commands for $lang"
            ;;
    esac
}

get_language_conventions() {
    local lang="$1"
    echo "$lang: Follow standard conventions"
}

create_new_agent_file() {
    local target_file="$1"
    local temp_file="$2"
    local project_name="$3"
    local current_date="$4"
    
    if [[ ! -f "$TEMPLATE_FILE" ]]; then
        log_error "Template not found at $TEMPLATE_FILE"
        return 1
    fi
    
    if [[ ! -r "$TEMPLATE_FILE" ]]; then
        log_error "Template file is not readable: $TEMPLATE_FILE"
        return 1
    fi
    
    log_info "Creating new agent context file from template..."
    
    if ! cp "$TEMPLATE_FILE" "$temp_file"; then
        log_error "Failed to copy template file"
        return 1
    fi
    
    # 替换模板占位符
    local project_structure
    project_structure=$(get_project_structure "$NEW_PROJECT_TYPE")
    
    local commands
    commands=$(get_commands_for_language "$NEW_LANG")
    
    local language_conventions
    language_conventions=$(get_language_conventions "$NEW_LANG")
    
    # 使用更安全的方式执行替换，并带上错误检查
    # 通过更换分隔符或转义来处理 sed 中的特殊字符
    local escaped_lang=$(printf '%s\n' "$NEW_LANG" | sed 's/[\[\.*^$()+{}|]/\\&/g')
    local escaped_framework=$(printf '%s\n' "$NEW_FRAMEWORK" | sed 's/[\[\.*^$()+{}|]/\\&/g')
    local escaped_branch=$(printf '%s\n' "$CURRENT_BRANCH" | sed 's/[\[\.*^$()+{}|]/\\&/g')
    
    # 按条件构造技术栈与最近变更字符串
    local tech_stack
    if [[ -n "$escaped_lang" && -n "$escaped_framework" ]]; then
        tech_stack="- $escaped_lang + $escaped_framework ($escaped_branch)"
    elif [[ -n "$escaped_lang" ]]; then
        tech_stack="- $escaped_lang ($escaped_branch)"
    elif [[ -n "$escaped_framework" ]]; then
        tech_stack="- $escaped_framework ($escaped_branch)"
    else
        tech_stack="- ($escaped_branch)"
    fi

    local recent_change
    if [[ -n "$escaped_lang" && -n "$escaped_framework" ]]; then
        recent_change="- $escaped_branch: Added $escaped_lang + $escaped_framework"
    elif [[ -n "$escaped_lang" ]]; then
        recent_change="- $escaped_branch: Added $escaped_lang"
    elif [[ -n "$escaped_framework" ]]; then
        recent_change="- $escaped_branch: Added $escaped_framework"
    else
        recent_change="- $escaped_branch: Added"
    fi

    local substitutions=(
        "s|\[PROJECT NAME\]|$project_name|"
        "s|\[DATE\]|$current_date|"
        "s|\[EXTRACTED FROM ALL PLAN.MD FILES\]|$tech_stack|"
        "s|\[ACTUAL STRUCTURE FROM PLANS\]|$project_structure|g"
        "s|\[ONLY COMMANDS FOR ACTIVE TECHNOLOGIES\]|$commands|"
        "s|\[LANGUAGE-SPECIFIC, ONLY FOR LANGUAGES IN USE\]|$language_conventions|"
        "s|\[LAST 3 FEATURES AND WHAT THEY ADDED\]|$recent_change|"
    )
    
    for substitution in "${substitutions[@]}"; do
        if ! sed -i.bak -e "$substitution" "$temp_file"; then
            log_error "Failed to perform substitution: $substitution"
            rm -f "$temp_file" "$temp_file.bak"
            return 1
        fi
    done
    
    # 将 \n 序列转成真实换行
    newline=$(printf '\n')
    sed -i.bak2 "s/\\\\n/${newline}/g" "$temp_file"

    # 清理备份文件
    rm -f "$temp_file.bak" "$temp_file.bak2"

    # 对 .mdc 文件预置 Cursor frontmatter，以便规则能被自动纳入
    if [[ "$target_file" == *.mdc ]]; then
        local frontmatter_file
        frontmatter_file=$(mktemp) || return 1
        printf '%s\n' "---" "description: Project Development Guidelines" "globs: [\"**/*\"]" "alwaysApply: true" "---" "" > "$frontmatter_file"
        cat "$temp_file" >> "$frontmatter_file"
        mv "$frontmatter_file" "$temp_file"
    fi

    return 0
}




update_existing_agent_file() {
    local target_file="$1"
    local current_date="$2"
    
    log_info "Updating existing agent context file..."
    
    # 使用单个临时文件实现原子更新
    local temp_file
    temp_file=$(mktemp) || {
        log_error "Failed to create temporary file"
        return 1
    }
    
    # 单次遍历完成文件处理
    local tech_stack=$(format_technology_stack "$NEW_LANG" "$NEW_FRAMEWORK")
    local new_tech_entries=()
    local new_change_entry=""
    
    # 准备新增的技术条目
    if [[ -n "$tech_stack" ]] && ! grep -q "$tech_stack" "$target_file"; then
        new_tech_entries+=("- $tech_stack ($CURRENT_BRANCH)")
    fi
    
    if [[ -n "$NEW_DB" ]] && [[ "$NEW_DB" != "N/A" ]] && [[ "$NEW_DB" != "NEEDS CLARIFICATION" ]] && ! grep -q "$NEW_DB" "$target_file"; then
        new_tech_entries+=("- $NEW_DB ($CURRENT_BRANCH)")
    fi
    
    # 准备新增的变更条目
    if [[ -n "$tech_stack" ]]; then
        new_change_entry="- $CURRENT_BRANCH: Added $tech_stack"
    elif [[ -n "$NEW_DB" ]] && [[ "$NEW_DB" != "N/A" ]] && [[ "$NEW_DB" != "NEEDS CLARIFICATION" ]]; then
        new_change_entry="- $CURRENT_BRANCH: Added $NEW_DB"
    fi
    
    # 检查文件中是否存在相关章节
    local has_active_technologies=0
    local has_recent_changes=0
    
    if grep -q "^## Active Technologies" "$target_file" 2>/dev/null; then
        has_active_technologies=1
    fi
    
    if grep -q "^## Recent Changes" "$target_file" 2>/dev/null; then
        has_recent_changes=1
    fi
    
    # 按行处理文件
    local in_tech_section=false
    local in_changes_section=false
    local tech_entries_added=false
    local changes_entries_added=false
    local existing_changes_count=0
    local file_ended=false
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        # 处理 Active Technologies 区块
        if [[ "$line" == "## Active Technologies" ]]; then
            echo "$line" >> "$temp_file"
            in_tech_section=true
            continue
        elif [[ $in_tech_section == true ]] && [[ "$line" =~ ^##[[:space:]] ]]; then
            # 在结束该区块前插入新的技术条目
            if [[ $tech_entries_added == false ]] && [[ ${#new_tech_entries[@]} -gt 0 ]]; then
                printf '%s\n' "${new_tech_entries[@]}" >> "$temp_file"
                tech_entries_added=true
            fi
            echo "$line" >> "$temp_file"
            in_tech_section=false
            continue
        elif [[ $in_tech_section == true ]] && [[ -z "$line" ]]; then
            # 在技术区块中的空行前插入新的技术条目
            if [[ $tech_entries_added == false ]] && [[ ${#new_tech_entries[@]} -gt 0 ]]; then
                printf '%s\n' "${new_tech_entries[@]}" >> "$temp_file"
                tech_entries_added=true
            fi
            echo "$line" >> "$temp_file"
            continue
        fi
        
        # 处理 Recent Changes 区块
        if [[ "$line" == "## Recent Changes" ]]; then
            echo "$line" >> "$temp_file"
            # 在标题后立即插入新的变更条目
            if [[ -n "$new_change_entry" ]]; then
                echo "$new_change_entry" >> "$temp_file"
            fi
            in_changes_section=true
            changes_entries_added=true
            continue
        elif [[ $in_changes_section == true ]] && [[ "$line" =~ ^##[[:space:]] ]]; then
            echo "$line" >> "$temp_file"
            in_changes_section=false
            continue
        elif [[ $in_changes_section == true ]] && [[ "$line" == "- "* ]]; then
            # 仅保留前 2 条已有变更
            if [[ $existing_changes_count -lt 2 ]]; then
                echo "$line" >> "$temp_file"
                ((existing_changes_count++))
            fi
            continue
        fi
        
        # 更新时间戳
        if [[ "$line" =~ (\*\*)?Last\ updated(\*\*)?:.*[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] ]]; then
            echo "$line" | sed "s/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/$current_date/" >> "$temp_file"
        else
            echo "$line" >> "$temp_file"
        fi
    done < "$target_file"
    
    # 循环结束后的补充检查：如果仍处于 Active Technologies 区块且尚未添加新条目
    if [[ $in_tech_section == true ]] && [[ $tech_entries_added == false ]] && [[ ${#new_tech_entries[@]} -gt 0 ]]; then
        printf '%s\n' "${new_tech_entries[@]}" >> "$temp_file"
        tech_entries_added=true
    fi
    
    # 如果相应章节不存在，则追加到文件末尾
    if [[ $has_active_technologies -eq 0 ]] && [[ ${#new_tech_entries[@]} -gt 0 ]]; then
        echo "" >> "$temp_file"
        echo "## Active Technologies" >> "$temp_file"
        printf '%s\n' "${new_tech_entries[@]}" >> "$temp_file"
        tech_entries_added=true
    fi
    
    if [[ $has_recent_changes -eq 0 ]] && [[ -n "$new_change_entry" ]]; then
        echo "" >> "$temp_file"
        echo "## Recent Changes" >> "$temp_file"
        echo "$new_change_entry" >> "$temp_file"
        changes_entries_added=true
    fi
    
    # 确保 Cursor 的 .mdc 文件包含 YAML frontmatter，以便自动纳入
    if [[ "$target_file" == *.mdc ]]; then
        if ! head -1 "$temp_file" | grep -q '^---'; then
            local frontmatter_file
            frontmatter_file=$(mktemp) || { rm -f "$temp_file"; return 1; }
            printf '%s\n' "---" "description: Project Development Guidelines" "globs: [\"**/*\"]" "alwaysApply: true" "---" "" > "$frontmatter_file"
            cat "$temp_file" >> "$frontmatter_file"
            mv "$frontmatter_file" "$temp_file"
        fi
    fi

    # 以原子方式将临时文件移动到目标位置
    if ! mv "$temp_file" "$target_file"; then
        log_error "Failed to update target file"
        rm -f "$temp_file"
        return 1
    fi

    return 0
}
#==============================================================================
# 主 Agent 文件更新函数
#==============================================================================

update_agent_file() {
    local target_file="$1"
    local agent_name="$2"
    
    if [[ -z "$target_file" ]] || [[ -z "$agent_name" ]]; then
        log_error "update_agent_file requires target_file and agent_name parameters"
        return 1
    fi
    
    log_info "Updating $agent_name context file: $target_file"
    
    local project_name
    project_name=$(basename "$REPO_ROOT")
    local current_date
    current_date=$(date +%Y-%m-%d)
    
    # 如目录不存在则先创建
    local target_dir
    target_dir=$(dirname "$target_file")
    if [[ ! -d "$target_dir" ]]; then
        if ! mkdir -p "$target_dir"; then
            log_error "Failed to create directory: $target_dir"
            return 1
        fi
    fi
    
    if [[ ! -f "$target_file" ]]; then
        # 从模板创建新文件
        local temp_file
        temp_file=$(mktemp) || {
            log_error "Failed to create temporary file"
            return 1
        }
        
        if create_new_agent_file "$target_file" "$temp_file" "$project_name" "$current_date"; then
            if mv "$temp_file" "$target_file"; then
                log_success "Created new $agent_name context file"
            else
                log_error "Failed to move temporary file to $target_file"
                rm -f "$temp_file"
                return 1
            fi
        else
            log_error "Failed to create new agent file"
            rm -f "$temp_file"
            return 1
        fi
    else
        # 更新已有文件
        if [[ ! -r "$target_file" ]]; then
            log_error "Cannot read existing file: $target_file"
            return 1
        fi
        
        if [[ ! -w "$target_file" ]]; then
            log_error "Cannot write to existing file: $target_file"
            return 1
        fi
        
        if update_existing_agent_file "$target_file" "$current_date"; then
            log_success "Updated existing $agent_name context file"
        else
            log_error "Failed to update existing agent file"
            return 1
        fi
    fi
    
    return 0
}

#==============================================================================
# Agent 选择与处理
#==============================================================================

update_specific_agent() {
    local agent_type="$1"
    
    case "$agent_type" in
        claude)
            update_agent_file "$CLAUDE_FILE" "Claude Code" || return 1
            ;;
        gemini)
            update_agent_file "$GEMINI_FILE" "Gemini CLI" || return 1
            ;;
        copilot)
            update_agent_file "$COPILOT_FILE" "GitHub Copilot" || return 1
            ;;
        cursor-agent)
            update_agent_file "$CURSOR_FILE" "Cursor IDE" || return 1
            ;;
        qwen)
            update_agent_file "$QWEN_FILE" "Qwen Code" || return 1
            ;;
        opencode)
            update_agent_file "$AGENTS_FILE" "opencode" || return 1
            ;;
        codex)
            update_agent_file "$AGENTS_FILE" "Codex CLI" || return 1
            ;;
        windsurf)
            update_agent_file "$WINDSURF_FILE" "Windsurf" || return 1
            ;;
        junie)
            update_agent_file "$JUNIE_FILE" "Junie" || return 1
            ;;
        kilocode)
            update_agent_file "$KILOCODE_FILE" "Kilo Code" || return 1
            ;;
        auggie)
            update_agent_file "$AUGGIE_FILE" "Auggie CLI" || return 1
            ;;
        roo)
            update_agent_file "$ROO_FILE" "Roo Code" || return 1
            ;;
        codebuddy)
            update_agent_file "$CODEBUDDY_FILE" "CodeBuddy CLI" || return 1
            ;;
        qodercli)
            update_agent_file "$QODER_FILE" "Qoder CLI" || return 1
            ;;
        amp)
            update_agent_file "$AMP_FILE" "Amp" || return 1
            ;;
        shai)
            update_agent_file "$SHAI_FILE" "SHAI" || return 1
            ;;
        tabnine)
            update_agent_file "$TABNINE_FILE" "Tabnine CLI" || return 1
            ;;
        kiro-cli)
            update_agent_file "$KIRO_FILE" "Kiro CLI" || return 1
            ;;
        agy)
            update_agent_file "$AGY_FILE" "Antigravity" || return 1
            ;;
        bob)
            update_agent_file "$BOB_FILE" "IBM Bob" || return 1
            ;;
        vibe)
            update_agent_file "$VIBE_FILE" "Mistral Vibe" || return 1
            ;;
        kimi)
            update_agent_file "$KIMI_FILE" "Kimi Code" || return 1
            ;;
        trae)
            update_agent_file "$TRAE_FILE" "Trae" || return 1
            ;;
        pi)
            update_agent_file "$AGENTS_FILE" "Pi Coding Agent" || return 1
            ;;
        iflow)
            update_agent_file "$IFLOW_FILE" "iFlow CLI" || return 1
            ;;
        generic)
            log_info "Generic agent: no predefined context file. Use the agent-specific update script for your agent."
            ;;
        *)
            log_error "Unknown agent type '$agent_type'"
            log_error "Expected: claude|gemini|copilot|cursor-agent|qwen|opencode|codex|windsurf|junie|kilocode|auggie|roo|codebuddy|amp|shai|tabnine|kiro-cli|agy|bob|vibe|qodercli|kimi|trae|pi|iflow|generic"
            exit 1
            ;;
    esac
}

# 辅助逻辑：跳过不存在的文件，以及已经更新过的文件（通过
# realpath 去重，因此指向同一文件的变量——例如 AMP_FILE、
# KIRO_FILE、BOB_FILE 最终都解析到 AGENTS_FILE——只会写入一次）。
# 为兼容 bash 3.2，这里使用线性数组而不是关联数组。
# 注意：该逻辑定义在顶层，因为 bash 3.2 不支持真正的
# 嵌套/local 函数。_updated_paths、_found_agent 和 _all_ok
# 仅在 update_all_existing_agents 内初始化，这样 source 本脚本时
# 不会对调用方环境产生副作用。

_update_if_new() {
    local file="$1" name="$2"
    [[ -f "$file" ]] || return 0
    local real_path
    real_path=$(realpath "$file" 2>/dev/null || echo "$file")
    local p
    if [[ ${#_updated_paths[@]} -gt 0 ]]; then
        for p in "${_updated_paths[@]}"; do
            [[ "$p" == "$real_path" ]] && return 0
        done
    fi
    # 在尝试更新前先记录该文件已经出现过，这样可以保证：
    # (a) 指向同一路径的别名在失败后不会被重复重试
    # (b) _found_agent 反映的是文件存在性，而不是更新是否成功
    _updated_paths+=("$real_path")
    _found_agent=true
    update_agent_file "$file" "$name"
}

update_all_existing_agents() {
    _found_agent=false
    _updated_paths=()
    local _all_ok=true

    _update_if_new "$CLAUDE_FILE" "Claude Code"           || _all_ok=false
    _update_if_new "$GEMINI_FILE" "Gemini CLI"             || _all_ok=false
    _update_if_new "$COPILOT_FILE" "GitHub Copilot"        || _all_ok=false
    _update_if_new "$CURSOR_FILE" "Cursor IDE"             || _all_ok=false
    _update_if_new "$QWEN_FILE" "Qwen Code"                || _all_ok=false
    _update_if_new "$AGENTS_FILE" "Codex/opencode"         || _all_ok=false
    _update_if_new "$AMP_FILE" "Amp"                       || _all_ok=false
    _update_if_new "$KIRO_FILE" "Kiro CLI"                 || _all_ok=false
    _update_if_new "$BOB_FILE" "IBM Bob"                   || _all_ok=false
    _update_if_new "$WINDSURF_FILE" "Windsurf"             || _all_ok=false
    _update_if_new "$JUNIE_FILE" "Junie"                || _all_ok=false
    _update_if_new "$KILOCODE_FILE" "Kilo Code"            || _all_ok=false
    _update_if_new "$AUGGIE_FILE" "Auggie CLI"             || _all_ok=false
    _update_if_new "$ROO_FILE" "Roo Code"                  || _all_ok=false
    _update_if_new "$CODEBUDDY_FILE" "CodeBuddy CLI"       || _all_ok=false
    _update_if_new "$SHAI_FILE" "SHAI"                     || _all_ok=false
    _update_if_new "$TABNINE_FILE" "Tabnine CLI"           || _all_ok=false
    _update_if_new "$QODER_FILE" "Qoder CLI"               || _all_ok=false
    _update_if_new "$AGY_FILE" "Antigravity"               || _all_ok=false
    _update_if_new "$VIBE_FILE" "Mistral Vibe"             || _all_ok=false
    _update_if_new "$KIMI_FILE" "Kimi Code"                || _all_ok=false
    _update_if_new "$TRAE_FILE" "Trae"                     || _all_ok=false
    _update_if_new "$IFLOW_FILE" "iFlow CLI"               || _all_ok=false

    # 如果没有任何 agent 文件，则创建默认的 Claude 文件
    if [[ "$_found_agent" == false ]]; then
        log_info "No existing agent files found, creating default Claude file..."
        update_agent_file "$CLAUDE_FILE" "Claude Code" || return 1
    fi

    [[ "$_all_ok" == true ]]
}
print_summary() {
    echo
    log_info "Summary of changes:"
    
    if [[ -n "$NEW_LANG" ]]; then
        echo "  - Added language: $NEW_LANG"
    fi
    
    if [[ -n "$NEW_FRAMEWORK" ]]; then
        echo "  - Added framework: $NEW_FRAMEWORK"
    fi
    
    if [[ -n "$NEW_DB" ]] && [[ "$NEW_DB" != "N/A" ]]; then
        echo "  - Added database: $NEW_DB"
    fi
    
    echo
    log_info "Usage: $0 [claude|gemini|copilot|cursor-agent|qwen|opencode|codex|windsurf|junie|kilocode|auggie|roo|codebuddy|amp|shai|tabnine|kiro-cli|agy|bob|vibe|qodercli|kimi|trae|pi|iflow|generic]"
}

#==============================================================================
# 主执行流程
#==============================================================================

main() {
    # 在继续前先校验环境
    validate_environment
    
    log_info "=== Updating agent context files for feature $CURRENT_BRANCH ==="
    
    # 解析 plan 文件以提取项目信息
    if ! parse_plan_data "$NEW_PLAN"; then
        log_error "Failed to parse plan data"
        exit 1
    fi
    
    # 根据 agent 类型参数执行对应处理
    local success=true
    
    if [[ -z "$AGENT_TYPE" ]]; then
        # 未指定具体 agent：更新所有已有 agent 文件
        log_info "No agent specified, updating all existing agent files..."
        if ! update_all_existing_agents; then
            success=false
        fi
    else
        # 指定了具体 agent：只更新该 agent
        log_info "Updating specific agent: $AGENT_TYPE"
        if ! update_specific_agent "$AGENT_TYPE"; then
            success=false
        fi
    fi
    
    # 打印摘要
    print_summary
    
    if [[ "$success" == true ]]; then
        log_success "Agent context update completed successfully"
        exit 0
    else
        log_error "Agent context update completed with errors"
        exit 1
    fi
}

# 如果脚本是直接运行的，则执行 main 函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
