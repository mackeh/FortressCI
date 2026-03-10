#!/bin/bash
# FortressCI Diff-Aware File Detection
# Detects changed files in a PR context and categorises them by scan type.
#
# Usage:
#   changed-files.sh [--base <ref>] [--head <ref>]
#
# Outputs (to stdout) a JSON object:
#   { "has_source": true/false, "has_iac": true/false, "has_container": true/false,
#     "has_deps": true/false, "has_ci": true/false, "files": [...] }
#
# Environment variables:
#   GITHUB_BASE_REF — set automatically in GitHub Actions PR context
#
# Exit codes:
#   0 — changed files detected (or full-scan fallback)
#   0 — always succeeds; the output JSON indicates what changed

set -euo pipefail

BASE_REF="${GITHUB_BASE_REF:-}"
HEAD_REF="HEAD"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --base) BASE_REF="$2"; shift ;;
        --head) HEAD_REF="$2"; shift ;;
        --help|-h)
            echo "Usage: changed-files.sh [--base <ref>] [--head <ref>]"
            echo ""
            echo "Detects changed files between base and head refs."
            echo "Outputs a JSON object with scan category flags."
            exit 0
            ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
    shift
done

# Fallback: if no base ref, output full-scan signal
if [ -z "$BASE_REF" ]; then
    echo '{"full_scan":true,"has_source":true,"has_iac":true,"has_container":true,"has_deps":true,"has_ci":true,"files":[]}'
    exit 0
fi

# Ensure the base ref is fetchable
if ! git rev-parse --verify "$BASE_REF" >/dev/null 2>&1; then
    # Try to fetch it (e.g., in shallow clones)
    git fetch --depth=1 origin "$BASE_REF" 2>/dev/null || true
    BASE_REF="origin/$BASE_REF"
fi

# Get merge base for cleaner diff
MERGE_BASE=$(git merge-base "$BASE_REF" "$HEAD_REF" 2>/dev/null || echo "$BASE_REF")

# Get the list of changed files
CHANGED_FILES=$(git diff --name-only "$MERGE_BASE" "$HEAD_REF" 2>/dev/null || echo "")

if [ -z "$CHANGED_FILES" ]; then
    echo '{"full_scan":true,"has_source":true,"has_iac":true,"has_container":true,"has_deps":true,"has_ci":true,"files":[]}'
    exit 0
fi

# Categorise files
has_source=false
has_iac=false
has_container=false
has_deps=false
has_ci=false

while IFS= read -r file; do
    [ -z "$file" ] && continue

    case "$file" in
        # Source code files
        *.py|*.js|*.ts|*.go|*.java|*.rb|*.php|*.cs|*.rs|*.c|*.cpp|*.h)
            has_source=true
            ;;
        # IaC files
        *.tf|*.bicep|*.yaml|*.yml)
            # YAML could be CI or IaC — check path
            case "$file" in
                terraform/*|*.tf|*.bicep)
                    has_iac=true
                    ;;
                .github/*|.gitlab-ci*|Jenkinsfile|bitbucket-pipelines*|azure-pipelines*)
                    has_ci=true
                    ;;
                *)
                    has_iac=true  # Default YAML to IaC
                    ;;
            esac
            ;;
        # Container files
        Dockerfile*|docker-compose*|*.dockerfile)
            has_container=true
            ;;
        # Dependency manifests
        package.json|package-lock.json|yarn.lock|pnpm-lock.yaml|\
        requirements.txt|Pipfile|Pipfile.lock|poetry.lock|\
        go.mod|go.sum|Gemfile|Gemfile.lock|*.csproj|Cargo.toml|Cargo.lock)
            has_deps=true
            ;;
        # CI/CD configs
        .github/workflows/*|.gitlab-ci.yml|Jenkinsfile|bitbucket-pipelines.yml|\
        azure-pipelines.yml|.circleci/*)
            has_ci=true
            ;;
    esac
done <<< "$CHANGED_FILES"

# Build JSON output
FILES_JSON=$(echo "$CHANGED_FILES" | jq -R -s 'split("\n") | map(select(length > 0))')

cat <<EOF
{"full_scan":false,"has_source":$has_source,"has_iac":$has_iac,"has_container":$has_container,"has_deps":$has_deps,"has_ci":$has_ci,"files":$FILES_JSON}
EOF
