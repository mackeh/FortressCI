#!/bin/bash
# FortressCI Supply Chain Hardening — Pinning Checker
# Verifies that GitHub Actions and Docker base images use pinned references.
#
# Usage: check-pinning.sh [--actions] [--docker] [--strict]
#   --actions   Check GitHub Actions pinning (default: on)
#   --docker    Check Dockerfile base image pinning (default: on)
#   --strict    Exit 1 on any unpinned reference (default: warn only)

set -euo pipefail

CHECK_ACTIONS=true
CHECK_DOCKER=true
STRICT=false
ISSUES=0
WARNINGS=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --actions) CHECK_ACTIONS=true; CHECK_DOCKER=false ;;
        --docker) CHECK_DOCKER=true; CHECK_ACTIONS=false ;;
        --strict) STRICT=true ;;
        *) echo "Unknown option: $1"; exit 2 ;;
    esac
    shift
done

echo "🔗 FortressCI Supply Chain Pinning Check"
echo "========================================="
echo ""

# --- GitHub Actions Pinning ---

if [ "$CHECK_ACTIONS" = true ] && [ -d ".github/workflows" ]; then
    echo "📋 Checking GitHub Actions pinning..."
    echo ""

    UNPINNED=""
    while IFS= read -r line; do
        # Extract the action reference from the line
        # line is in format: filename:lineno:uses: action
        ref=$(echo "$line" | sed 's/.*uses:[[:space:]]*//' | awk '{print $1}')
        [ -z "$ref" ] && continue

        # Skip local actions (uses: ./)
        if [[ "$ref" == ./* ]]; then continue; fi

        # Check if pinned to full SHA (40 hex chars)
        if ! echo "$ref" | grep -qE "@[a-f0-9]{40}$"; then
            file=$(echo "$line" | cut -d: -f1)
            lineno=$(echo "$line" | cut -d: -f2)
            echo "  ⚠️  $ref"
            echo "     in $file:$lineno"
            WARNINGS=$((WARNINGS + 1))
        fi
    done < <(grep -rn "uses:" .github/workflows/ 2>/dev/null | grep -vE "^\s*#")

    if [ "$WARNINGS" -eq 0 ]; then
        echo "  ✅ All GitHub Actions are SHA-pinned"
    else
        echo ""
        echo "  Found $WARNINGS unpinned action(s)"
        echo "  Fix: Pin to full SHA (e.g., actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11)"
    fi
    echo ""
fi

# --- Dockerfile Base Image Pinning ---

if [ "$CHECK_DOCKER" = true ]; then
    DOCKER_WARNINGS=0

    # Find all Dockerfiles
    DOCKERFILES=$(find . -maxdepth 3 -name "Dockerfile*" -not -path "./.git/*" 2>/dev/null || true)

    if [ -n "$DOCKERFILES" ]; then
        echo "🐳 Checking Dockerfile base image pinning..."
        echo ""

        while IFS= read -r dockerfile; do
            [ -z "$dockerfile" ] && continue

            while IFS= read -r from_line; do
                [ -z "$from_line" ] && continue

                # Extract image reference (ignore ARG-based FROM, scratch, and build stages)
                image=$(echo "$from_line" | awk '{print $2}')
                [ -z "$image" ] && continue
                [[ "$image" == "scratch" ]] && continue
                [[ "$image" == \$* ]] && continue  # ARG-based

                # Strip AS alias if present
                image=$(echo "$image" | sed -E 's/[[:space:]]+[Aa][Ss][[:space:]]+.*$//')

                # Check for digest pinning (@sha256:...)
                if echo "$image" | grep -qE "@sha256:[a-f0-9]{64}"; then
                    continue  # Properly pinned
                fi

                # Check for :latest or no tag (effectively latest)
                if echo "$image" | grep -qE ":latest$" || ! echo "$image" | grep -qE ":"; then
                    echo "  ⚠️  $image (uses :latest or no tag)"
                    echo "     in $dockerfile"
                    DOCKER_WARNINGS=$((DOCKER_WARNINGS + 1))
                else
                    # Has a tag but not digest-pinned — warning in strict mode
                    if [ "$STRICT" = true ]; then
                        echo "  ⚠️  $image (tagged but not digest-pinned)"
                        echo "     in $dockerfile"
                        DOCKER_WARNINGS=$((DOCKER_WARNINGS + 1))
                    fi
                fi
            done < <(grep -iE "^FROM\s+" "$dockerfile" 2>/dev/null)
        done <<< "$DOCKERFILES"

        if [ "$DOCKER_WARNINGS" -eq 0 ]; then
            echo "  ✅ All Dockerfile base images are properly pinned"
        else
            echo ""
            echo "  Found $DOCKER_WARNINGS base image pinning issue(s)"
            echo "  Fix: Pin to digest (e.g., ubuntu:22.04@sha256:abc123...)"
        fi
        WARNINGS=$((WARNINGS + DOCKER_WARNINGS))
    fi
    echo ""
fi

# --- Summary ---

TOTAL=$((WARNINGS))
echo "================================="
if [ "$TOTAL" -eq 0 ]; then
    echo "✅ Supply chain pinning check passed"
    exit 0
elif [ "$STRICT" = true ]; then
    echo "❌ $TOTAL pinning issue(s) found (strict mode — failing)"
    exit 1
else
    echo "⚠️  $TOTAL pinning issue(s) found (non-blocking)"
    exit 0
fi
