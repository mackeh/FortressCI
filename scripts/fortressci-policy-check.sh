#!/bin/bash
# FortressCI Policy-as-Code Checker
# Enforces organisational security rules defined in .security/policy.yml.

set -euo pipefail

POLICY_FILE=${1:-.security/policy.yml}
RESULTS_DIR=${2:-./results}

if [ ! -f "$POLICY_FILE" ]; then
    echo "⚠️  Policy file $POLICY_FILE not found. Skipping policy check."
    exit 0
fi

echo "🛡️  FortressCI Policy Check"
echo "=========================="
echo "Policy: $POLICY_FILE"
echo ""

FAILED=0
TOTAL_POLICIES=0

# Helper to check if a policy is enabled
is_enabled() {
    local policy_id="$1"
    grep -A 5 "id: $policy_id" "$POLICY_FILE" | grep "enabled: true" > /dev/null
}

# 1. Action Pinning (FCI-POL-001)
if is_enabled "FCI-POL-001"; then
    TOTAL_POLICIES=$((TOTAL_POLICIES + 1))
    echo "🔍 [FCI-POL-001] Checking GitHub Actions pinning..."
    if ./scripts/check-pinning.sh --actions --strict > /dev/null 2>&1; then
        echo "   ✅ Pass"
    else
        echo "   ❌ Fail: All GitHub Actions must be SHA-pinned"
        FAILED=1
    fi
fi

# 2. Docker Base Pinning (FCI-POL-004)
if is_enabled "FCI-POL-004"; then
    TOTAL_POLICIES=$((TOTAL_POLICIES + 1))
    echo "🔍 [FCI-POL-004] Checking Docker base image pinning..."
    if ./scripts/check-pinning.sh --docker --strict > /dev/null 2>&1; then
        echo "   ✅ Pass"
    else
        echo "   ❌ Fail: Docker base images must be version-pinned with digests"
        FAILED=1
    fi
fi

# 3. No Critical CVEs (FCI-POL-003)
if is_enabled "FCI-POL-003"; then
    TOTAL_POLICIES=$((TOTAL_POLICIES + 1))
    echo "🔍 [FCI-POL-003] Checking for critical CVEs..."
    SUMMARY_FILE="$RESULTS_DIR/summary.json"
    if [ -f "$SUMMARY_FILE" ]; then
        CRITICAL=$(jq '.totals.critical' "$SUMMARY_FILE")
        if [ "$CRITICAL" -eq 0 ]; then
            echo "   ✅ Pass"
        else
            echo "   ❌ Fail: Found $CRITICAL critical vulnerability/ies"
            FAILED=1
        fi
    else
        echo "   ⚠️  Skip: summary.json not found"
    fi
fi

# 4. SBOM Generated (FCI-POL-007 - New)
# (Adding a check for SBOM even if not in policy.yml yet)
if [ -f "$RESULTS_DIR/sbom-source.spdx.json" ]; then
    echo "🔍 [FCI-POL-007] Checking SBOM generation..."
    echo "   ✅ Pass"
fi

echo ""
if [ "$FAILED" -eq 1 ]; then
    echo "❌ Policy check FAILED"
    exit 1
else
    echo "✅ Policy check PASSED ($TOTAL_POLICIES policies checked)"
    exit 0
fi
