#!/bin/bash
# FortressCI doctor
# Local health checks for project readiness, scanner availability, and governance controls.
#
# Usage:
#   ./scripts/fortressci-doctor.sh [--workspace <path>] [--strict] [--check-remote]

set -euo pipefail

workspace="."
strict_mode=0
check_remote=0

pass_count=0
warn_count=0
fail_count=0

print_usage() {
    cat <<'EOF'
Usage: fortressci-doctor.sh [options]

Options:
  --workspace <path>  Project path to inspect (default: .)
  --strict            Exit non-zero on warnings
  --check-remote      Probe GitHub branch protection via gh api (if possible)
  -h, --help          Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --workspace)
            workspace="${2:-}"
            shift 2
            ;;
        --strict)
            strict_mode=1
            shift
            ;;
        --check-remote)
            check_remote=1
            shift
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            print_usage
            exit 2
            ;;
    esac
done

check_pass() {
    local message="$1"
    pass_count=$((pass_count + 1))
    echo "✅ PASS: $message"
}

check_warn() {
    local message="$1"
    warn_count=$((warn_count + 1))
    echo "⚠️  WARN: $message"
}

check_fail() {
    local message="$1"
    fail_count=$((fail_count + 1))
    echo "❌ FAIL: $message"
}

check_file_exists() {
    local relative_path="$1"
    local description="$2"
    if [ -f "${workspace}/${relative_path}" ]; then
        check_pass "$description (${relative_path})"
    else
        check_fail "$description (${relative_path})"
    fi
}

check_command() {
    local command_name="$1"
    local required="$2"
    if command -v "$command_name" >/dev/null 2>&1; then
        check_pass "Tool available: ${command_name}"
    else
        if [ "$required" = "required" ]; then
            check_fail "Missing required tool: ${command_name}"
        else
            check_warn "Missing optional tool: ${command_name}"
        fi
    fi
}

detect_ci_file() {
    local count=0
    local ci_files=(
        ".github/workflows/devsecops.yml"
        ".gitlab-ci.yml"
        "bitbucket-pipelines.yml"
        "azure-pipelines.yml"
        "Jenkinsfile"
        ".circleci/config.yml"
    )

    for rel in "${ci_files[@]}"; do
        if [ -f "${workspace}/${rel}" ]; then
            count=$((count + 1))
        fi
    done

    if [ "$count" -gt 0 ]; then
        check_pass "CI pipeline file detected (${count} found)"
    else
        check_warn "No CI pipeline file detected from FortressCI-supported platforms"
    fi
}

check_precommit_hook() {
    local hook_path="${workspace}/.git/hooks/pre-commit"
    if [ -x "$hook_path" ]; then
        check_pass "Pre-commit hook is installed (${hook_path})"
    else
        check_warn "Pre-commit hook not installed (run: pre-commit install)"
    fi
}

check_env_secret() {
    local env_name="$1"
    local required="$2"
    if [ -n "${!env_name:-}" ]; then
        check_pass "Environment variable set: ${env_name}"
    else
        if [ "$required" = "required" ]; then
            check_fail "Missing required environment variable: ${env_name}"
        else
            check_warn "Environment variable not set: ${env_name}"
        fi
    fi
}

extract_enabled_scanner_tools() {
    local config_path="${workspace}/.fortressci.yml"
    if [ ! -f "$config_path" ]; then
        return 0
    fi

    awk '
        /^scanners:/ {in_scanners=1; next}
        in_scanners && /^[^[:space:]]/ {
            if (enabled == "true" && tool != "") {
                print tool
            }
            in_scanners=0
        }
        in_scanners && /^[[:space:]]{2}[A-Za-z0-9_-]+:/ {
            if (enabled == "true" && tool != "") {
                print tool
            }
            enabled=""
            tool=""
            next
        }
        in_scanners && /^[[:space:]]{4}enabled:/ {
            split($0, parts, ":")
            enabled=parts[2]
            gsub(/[[:space:]]|'\''|"/, "", enabled)
            next
        }
        in_scanners && /^[[:space:]]{4}tool:/ {
            split($0, parts, ":")
            tool=parts[2]
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", tool)
            gsub(/'\''|"/, "", tool)
            next
        }
        END {
            if (in_scanners && enabled == "true" && tool != "") {
                print tool
            }
        }
    ' "$config_path" | sort -u
}

extract_ai_settings() {
    local config_path="${workspace}/.fortressci.yml"
    if [ ! -f "$config_path" ]; then
        echo "false unknown"
        return 0
    fi

    local ai_enabled
    local ai_provider
    ai_enabled=$(awk '
        /^ai:/ {in_ai=1; next}
        in_ai && /^[^[:space:]]/ {in_ai=0}
        in_ai && $1 == "enabled:" {print $2; exit}
    ' "$config_path")
    ai_provider=$(awk '
        /^ai:/ {in_ai=1; next}
        in_ai && /^[^[:space:]]/ {in_ai=0}
        in_ai && $1 == "provider:" {print $2; exit}
    ' "$config_path")

    ai_enabled="${ai_enabled:-false}"
    ai_provider="${ai_provider:-unknown}"
    echo "${ai_enabled} ${ai_provider}"
}

parse_github_repo() {
    local remote_url="$1"
    local owner=""
    local repo=""
    if [[ "$remote_url" =~ ^https://github\.com/([^/]+)/([^/]+)$ ]]; then
        owner="${BASH_REMATCH[1]}"
        repo="${BASH_REMATCH[2]}"
        repo="${repo%.git}"
        echo "${owner}/${repo}"
        return 0
    fi
    if [[ "$remote_url" =~ ^git@github\.com:([^/]+)/([^/]+)$ ]]; then
        owner="${BASH_REMATCH[1]}"
        repo="${BASH_REMATCH[2]}"
        repo="${repo%.git}"
        echo "${owner}/${repo}"
        return 0
    fi
    return 1
}

check_branch_protection() {
    if [ "$check_remote" -ne 1 ]; then
        check_warn "Remote branch protection check skipped (use --check-remote)"
        return 0
    fi

    if ! command -v gh >/dev/null 2>&1; then
        check_warn "GitHub CLI not installed; cannot check branch protection"
        return 0
    fi

    local remote_url
    remote_url=$(git -C "$workspace" remote get-url origin 2>/dev/null || true)
    if [ -z "$remote_url" ]; then
        check_warn "No origin remote configured; cannot check branch protection"
        return 0
    fi

    local owner_repo
    owner_repo=$(parse_github_repo "$remote_url" || true)
    if [ -z "$owner_repo" ]; then
        check_warn "Origin is not a github.com remote; branch protection probe skipped"
        return 0
    fi

    local default_branch
    default_branch=$(gh api "repos/${owner_repo}" --jq '.default_branch' 2>/dev/null || true)
    if [ -z "$default_branch" ]; then
        check_warn "Unable to resolve default branch via GitHub API for ${owner_repo}"
        return 0
    fi

    if gh api "repos/${owner_repo}/branches/${default_branch}/protection" >/dev/null 2>&1; then
        check_pass "Branch protection detected for ${owner_repo}:${default_branch}"
    else
        check_warn "No branch protection detected or insufficient API permissions for ${owner_repo}:${default_branch}"
    fi
}

echo "🏥 FortressCI Doctor"
echo "===================="
if [ ! -d "$workspace" ]; then
    echo "❌ FAIL: Workspace path does not exist: $workspace"
    exit 2
fi
echo "Workspace: $(cd "$workspace" && pwd)"
echo ""

if ! git -C "$workspace" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    check_fail "Workspace is not a Git repository"
else
    check_pass "Git repository detected"
fi

if [ -n "$(git -C "$workspace" status --porcelain 2>/dev/null || true)" ]; then
    check_warn "Working tree has uncommitted changes"
else
    check_pass "Working tree is clean"
fi

check_file_exists ".fortressci.yml" "FortressCI config present"
check_file_exists ".pre-commit-config.yaml" "Pre-commit config present"
check_file_exists ".security/policy.yml" "Policy file present"
check_file_exists ".security/waivers.yml" "Waivers file present"
check_file_exists ".security/compliance-mappings.yml" "Compliance mappings present"

detect_ci_file
check_precommit_hook

check_command "git" "required"
check_command "python3" "required"
check_command "jq" "required"
check_command "pre-commit" "optional"
check_command "docker" "optional"
check_command "gh" "optional"

while IFS= read -r scanner_tool; do
    [ -z "$scanner_tool" ] && continue
    check_command "$scanner_tool" "optional"
done < <(extract_enabled_scanner_tools)

check_command "syft" "optional"
check_command "cosign" "optional"

check_env_secret "SNYK_TOKEN" "optional"

read -r ai_enabled ai_provider < <(extract_ai_settings)
if [ "$ai_enabled" = "true" ] && [ "$ai_provider" = "anthropic" ]; then
    check_env_secret "ANTHROPIC_API_KEY" "optional"
fi

check_branch_protection

echo ""
echo "Summary: ${pass_count} pass, ${warn_count} warn, ${fail_count} fail"

if [ "$fail_count" -gt 0 ]; then
    echo "Result: FAIL"
    exit 1
fi

if [ "$strict_mode" -eq 1 ] && [ "$warn_count" -gt 0 ]; then
    echo "Result: WARN (strict mode)"
    exit 1
fi

if [ "$warn_count" -gt 0 ]; then
    echo "Result: WARN"
else
    echo "Result: OK"
fi

exit 0
