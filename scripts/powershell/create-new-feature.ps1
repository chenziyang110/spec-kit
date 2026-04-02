#!/usr/bin/env pwsh
# 创建一个新功能
[CmdletBinding()]
param(
    [switch]$Json,
    [switch]$AllowExistingBranch,
    [string]$ShortName,
    [Parameter()]
    [long]$Number = 0,
    [switch]$Timestamp,
    [switch]$Help,
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
    [string[]]$FeatureDescription
)
$ErrorActionPreference = 'Stop'

# 如果请求了帮助，则显示帮助信息
if ($Help) {
    Write-Host "Usage: ./create-new-feature.ps1 [-Json] [-AllowExistingBranch] [-ShortName <name>] [-Number N] [-Timestamp] <feature description>"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Json               Output in JSON format"
    Write-Host "  -AllowExistingBranch  Switch to branch if it already exists instead of failing"
    Write-Host "  -ShortName <name>   Provide a custom short name (2-4 words) for the branch"
    Write-Host "  -Number N           Specify branch number manually (overrides auto-detection)"
    Write-Host "  -Timestamp          Use timestamp prefix (YYYYMMDD-HHMMSS) instead of sequential numbering"
    Write-Host "  -Help               Show this help message"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  ./create-new-feature.ps1 'Add user authentication system' -ShortName 'user-auth'"
    Write-Host "  ./create-new-feature.ps1 'Implement OAuth2 integration for API'"
    Write-Host "  ./create-new-feature.ps1 -Timestamp -ShortName 'user-auth' 'Add user authentication'"
    exit 0
}

# 检查是否提供了功能描述
if (-not $FeatureDescription -or $FeatureDescription.Count -eq 0) {
    Write-Error "Usage: ./create-new-feature.ps1 [-Json] [-AllowExistingBranch] [-ShortName <name>] [-Number N] [-Timestamp] <feature description>"
    exit 1
}

$featureDesc = ($FeatureDescription -join ' ').Trim()

# 去除首尾空白后再校验描述不为空（例如用户只传入了空白字符）
if ([string]::IsNullOrWhiteSpace($featureDesc)) {
    Write-Error "Error: Feature description cannot be empty or contain only whitespace"
    exit 1
}

function Get-HighestNumberFromSpecs {
    param([string]$SpecsDir)
    
    [long]$highest = 0
    if (Test-Path $SpecsDir) {
        Get-ChildItem -Path $SpecsDir -Directory | ForEach-Object {
            # 匹配顺序编号前缀（>=3 位数字），但跳过时间戳目录
            if ($_.Name -match '^(\d{3,})-' -and $_.Name -notmatch '^\d{8}-\d{6}-') {
                [long]$num = 0
                if ([long]::TryParse($matches[1], [ref]$num) -and $num -gt $highest) {
                    $highest = $num
                }
            }
        }
    }
    return $highest
}

function Get-HighestNumberFromBranches {
    param()
    
    [long]$highest = 0
    try {
        $branches = git branch -a 2>$null
        if ($LASTEXITCODE -eq 0) {
            foreach ($branch in $branches) {
                # 清洗分支名：移除前导标记和远端前缀
                $cleanBranch = $branch.Trim() -replace '^\*?\s+', '' -replace '^remotes/[^/]+/', ''
                
                # 提取顺序功能编号（>=3 位数字），并跳过时间戳分支
                if ($cleanBranch -match '^(\d{3,})-' -and $cleanBranch -notmatch '^\d{8}-\d{6}-') {
                    [long]$num = 0
                    if ([long]::TryParse($matches[1], [ref]$num) -and $num -gt $highest) {
                        $highest = $num
                    }
                }
            }
        }
    } catch {
        # 如果 git 命令失败，则返回 0
        Write-Verbose "Could not check Git branches: $_"
    }
    return $highest
}

function Get-NextBranchNumber {
    param(
        [string]$SpecsDir
    )

    # 获取所有远端信息以拿到最新分支状态（如果没有远端则忽略错误）
    try {
        git fetch --all --prune 2>$null | Out-Null
    } catch {
        # 忽略 fetch 错误
    }

    # 从所有分支中取最大编号（不只限于匹配当前短名的分支）
    $highestBranch = Get-HighestNumberFromBranches

    # 从所有 specs 中取最大编号（不只限于匹配当前短名的规格）
    $highestSpec = Get-HighestNumberFromSpecs -SpecsDir $SpecsDir

    # 取二者中的最大值
    $maxNum = [Math]::Max($highestBranch, $highestSpec)

    # 返回下一个编号
    return $maxNum + 1
}

function ConvertTo-CleanBranchName {
    param([string]$Name)
    
    return $Name.ToLower() -replace '[^a-z0-9]', '-' -replace '-{2,}', '-' -replace '^-', '' -replace '-$', ''
}
# 加载公共函数（包括 Get-RepoRoot、Test-HasGit、Resolve-Template）
. "$PSScriptRoot/common.ps1"

# 使用 common.ps1 中优先 .specify 的逻辑
$repoRoot = Get-RepoRoot

# 检查该仓库根目录是否可用 git（而不是误用父目录）
$hasGit = Test-HasGit

Set-Location $repoRoot

$specsDir = Join-Path $repoRoot 'specs'
New-Item -ItemType Directory -Path $specsDir -Force | Out-Null

# 生成分支名的函数：带停用词过滤和长度过滤
function Get-BranchName {
    param([string]$Description)
    
    # 需要过滤掉的常见停用词
    $stopWords = @(
        'i', 'a', 'an', 'the', 'to', 'for', 'of', 'in', 'on', 'at', 'by', 'with', 'from',
        'is', 'are', 'was', 'were', 'be', 'been', 'being', 'have', 'has', 'had',
        'do', 'does', 'did', 'will', 'would', 'should', 'could', 'can', 'may', 'might', 'must', 'shall',
        'this', 'that', 'these', 'those', 'my', 'your', 'our', 'their',
        'want', 'need', 'add', 'get', 'set'
    )
    
    # 转为小写并提取单词（仅保留字母数字）
    $cleanName = $Description.ToLower() -replace '[^a-z0-9\s]', ' '
    $words = $cleanName -split '\s+' | Where-Object { $_ }
    
    # 过滤单词：去掉停用词和少于 3 个字符的单词（除非它们在原文中是大写缩写）
    $meaningfulWords = @()
    foreach ($word in $words) {
        # 跳过停用词
        if ($stopWords -contains $word) { continue }
        
        # 保留长度 >= 3 的单词，或在原文中以大写出现的单词（大概率是缩写）
        if ($word.Length -ge 3) {
            $meaningfulWords += $word
        } elseif ($Description -match "\b$($word.ToUpper())\b") {
            # 如果短词在原文中以大写出现，则保留（大概率是缩写）
            $meaningfulWords += $word
        }
    }
    
    # 如果筛出了有意义的单词，则使用前 3-4 个
    if ($meaningfulWords.Count -gt 0) {
        $maxWords = if ($meaningfulWords.Count -eq 4) { 4 } else { 3 }
        $result = ($meaningfulWords | Select-Object -First $maxWords) -join '-'
        return $result
    } else {
        # 如果没有筛出有意义的单词，则回退到原始逻辑
        $result = ConvertTo-CleanBranchName -Name $Description
        $fallbackWords = ($result -split '-') | Where-Object { $_ } | Select-Object -First 3
        return [string]::Join('-', $fallbackWords)
    }
}

# 生成分支名
if ($ShortName) {
    # 使用用户提供的短名，只做清洗
    $branchSuffix = ConvertTo-CleanBranchName -Name $ShortName
} else {
    # 根据描述智能过滤后生成
    $branchSuffix = Get-BranchName -Description $featureDesc
}

# 如果同时指定了 -Number 和 -Timestamp，则给出警告
if ($Timestamp -and $Number -ne 0) {
    Write-Warning "[specify] Warning: -Number is ignored when -Timestamp is used"
    $Number = 0
}

# 确定分支前缀
if ($Timestamp) {
    $featureNum = Get-Date -Format 'yyyyMMdd-HHmmss'
    $branchName = "$featureNum-$branchSuffix"
} else {
    # 确定分支编号
    if ($Number -eq 0) {
        if ($hasGit) {
            # 检查远端中的现有分支
            $Number = Get-NextBranchNumber -SpecsDir $specsDir
        } else {
            # 回退到本地目录检查
            $Number = (Get-HighestNumberFromSpecs -SpecsDir $specsDir) + 1
        }
    }

    $featureNum = ('{0:000}' -f $Number)
    $branchName = "$featureNum-$branchSuffix"
}

# GitHub 对分支名有 244 字节限制
# 如有需要，进行校验并截断
$maxBranchLength = 244
if ($branchName.Length -gt $maxBranchLength) {
    # 计算后缀需要裁剪多少
    # 需要考虑前缀长度：时间戳（15）+ 连字符（1）= 16；顺序编号（3）+ 连字符（1）= 4
    $prefixLength = $featureNum.Length + 1
    $maxSuffixLength = $maxBranchLength - $prefixLength
    
    # 截断后缀
    $truncatedSuffix = $branchSuffix.Substring(0, [Math]::Min($branchSuffix.Length, $maxSuffixLength))
    # 如果截断后产生了尾随连字符，则将其移除
    $truncatedSuffix = $truncatedSuffix -replace '-$', ''
    
    $originalBranchName = $branchName
    $branchName = "$featureNum-$truncatedSuffix"
    
    Write-Warning "[specify] Branch name exceeded GitHub's 244-byte limit"
    Write-Warning "[specify] Original: $originalBranchName ($($originalBranchName.Length) bytes)"
    Write-Warning "[specify] Truncated to: $branchName ($($branchName.Length) bytes)"
}

if ($hasGit) {
    $branchCreated = $false
    try {
        git checkout -q -b $branchName 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            $branchCreated = $true
        }
    } catch {
        # git 命令执行过程中抛出了异常
    }

    if (-not $branchCreated) {
        # 检查分支是否已存在
        $existingBranch = git branch --list $branchName 2>$null
        if ($existingBranch) {
            if ($AllowExistingBranch) {
                # 切换到已有分支，而不是直接失败
                git checkout -q $branchName 2>$null | Out-Null
                if ($LASTEXITCODE -ne 0) {
                    Write-Error "Error: Branch '$branchName' exists but could not be checked out. Resolve any uncommitted changes or conflicts and try again."
                    exit 1
                }
            } elseif ($Timestamp) {
                Write-Error "Error: Branch '$branchName' already exists. Rerun to get a new timestamp or use a different -ShortName."
                exit 1
            } else {
                Write-Error "Error: Branch '$branchName' already exists. Please use a different feature name or specify a different number with -Number."
                exit 1
            }
        } else {
            Write-Error "Error: Failed to create git branch '$branchName'. Please check your git configuration and try again."
            exit 1
        }
    }
} else {
    Write-Warning "[specify] Warning: Git repository not detected; skipped branch creation for $branchName"
}

$featureDir = Join-Path $specsDir $branchName
New-Item -ItemType Directory -Path $featureDir -Force | Out-Null

$specFile = Join-Path $featureDir 'spec.md'
if (-not (Test-Path -PathType Leaf $specFile)) {
    $template = Resolve-Template -TemplateName 'spec-template' -RepoRoot $repoRoot
    if ($template -and (Test-Path $template)) {
        Copy-Item $template $specFile -Force
    } else {
        New-Item -ItemType File -Path $specFile | Out-Null
    }
}

# 为当前会话设置 SPECIFY_FEATURE 环境变量
$env:SPECIFY_FEATURE = $branchName

if ($Json) {
    $obj = [PSCustomObject]@{ 
        BRANCH_NAME = $branchName
        SPEC_FILE = $specFile
        FEATURE_NUM = $featureNum
        HAS_GIT = $hasGit
    }
    $obj | ConvertTo-Json -Compress
} else {
    Write-Output "BRANCH_NAME: $branchName"
    Write-Output "SPEC_FILE: $specFile"
    Write-Output "FEATURE_NUM: $featureNum"
    Write-Output "HAS_GIT: $hasGit"
    Write-Output "SPECIFY_FEATURE environment variable set to: $branchName"
}
