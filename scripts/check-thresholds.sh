#!/bin/bash
# FortressCI Threshold Gating
# Reads .fortressci.yml thresholds and summary.json, applies waiver exclusions,
# and exits non-zero if severity thresholds are exceeded.
#
# Usage: check-thresholds.sh <results_dir> [config_path]

set -euo pipefail

RESULTS_DIR="${1:-.}"
CONFIG_PATH="${2:-.fortressci.yml}"

# --- Helpers ---

die() { echo "❌ $*" >&2; exit 2; }

# Parse YAML value (simple key: value, no nested support needed here)
yaml_get() {
    local file="$1" key="$2"
    grep -E "^\s*${key}:" "$file" 2>/dev/null | head -1 | sed 's/.*:\s*//' | tr -d '"' | tr -d "'" | xargs
}

# --- Load config ---

if [ ! -f "$CONFIG_PATH" ]; then
    echo "⚠️  No $CONFIG_PATH found, using defaults (fail_on: critical, warn_on: high)"
    FAIL_ON="critical"
    WARN_ON="high"
else
    FAIL_ON=$(yaml_get "$CONFIG_PATH" "fail_on")
    WARN_ON=$(yaml_get "$CONFIG_PATH" "warn_on")
    FAIL_ON="${FAIL_ON:-critical}"
    WARN_ON="${WARN_ON:-high}"
fi

# --- Load summary ---

SUMMARY_FILE="${RESULTS_DIR}/summary.json"
if [ ! -f "$SUMMARY_FILE" ]; then
    die "summary.json not found at $SUMMARY_FILE — run summarize.py first"
fi

CRITICAL=$(jq '.totals.critical' "$SUMMARY_FILE")
HIGH=$(jq '.totals.high' "$SUMMARY_FILE")
MEDIUM=$(jq '.totals.medium' "$SUMMARY_FILE")
LOW=$(jq '.totals.low' "$SUMMARY_FILE")
TOTAL=$(jq '.total_findings' "$SUMMARY_FILE")

# --- Load waivers and subtract from counts ---

WAIVERS_PATH=$(yaml_get "$CONFIG_PATH" "path" 2>/dev/null || echo ".security/waivers.yml")
WAIVERS_PATH="${WAIVERS_PATH:-.security/waivers.yml}"
WAIVER_COUNT=0
WAIVER_CRITICAL=0
WAIVER_HIGH=0
WAIVER_MEDIUM=0
WAIVER_LOW=0
TODAY=$(date +%Y-%m-%d)

if [ -f "$WAIVERS_PATH" ]; then
    # Count active (non-expired) waivers by severity
    while IFS= read -r line; do
        expires=$(echo "$line" | grep -oP 'expires_on:\s*"\K[^"]+' || true)
        severity=$(echo "$line" | grep -oP 'severity:\s*"\K[^"]+' || true)
        if [ -n "$expires" ] && { [ "$expires" \> "$TODAY" ] || [ "$expires" = "$TODAY" ]; }; then
            WAIVER_COUNT=$((WAIVER_COUNT + 1))
            case "$severity" in
                critical) WAIVER_CRITICAL=$((WAIVER_CRITICAL + 1)) ;;
                high)     WAIVER_HIGH=$((WAIVER_HIGH + 1)) ;;
                medium)   WAIVER_MEDIUM=$((WAIVER_MEDIUM + 1)) ;;
                low)      WAIVER_LOW=$((WAIVER_LOW + 1)) ;;
            esac
        fi
    done < <(grep -A5 "^  - id:" "$WAIVERS_PATH" 2>/dev/null | paste -d' ' - - - - - -)
fi

# Subtract active waivers per-severity (floor at 0)
subtract() { local v=$(( $1 - $2 )); echo $(( v > 0 ? v : 0 )); }
CRITICAL=$(subtract "$CRITICAL" "$WAIVER_CRITICAL")
HIGH=$(subtract "$HIGH" "$WAIVER_HIGH")
MEDIUM=$(subtract "$MEDIUM" "$WAIVER_MEDIUM")
LOW=$(subtract "$LOW" "$WAIVER_LOW")

echo "🏰 FortressCI Threshold Check"
echo "=============================="
echo "Config:     $CONFIG_PATH"
echo "Fail on:    $FAIL_ON"
echo "Warn on:    $WARN_ON"
echo ""
echo "Findings:   $TOTAL total"
echo "  Critical: $CRITICAL (after waivers)"
echo "  High:     $HIGH (after waivers)"
echo "  Medium:   $MEDIUM (after waivers)"
echo "  Low:      $LOW (after waivers)"
echo "Waivers:    $WAIVER_COUNT active"
echo ""

# --- Evaluate thresholds ---

FAILED=0
WARNED=0

check_severity() {
    local level="$1" count="$2" action="$3"
    if [ "$count" -gt 0 ]; then
        if [ "$action" = "fail" ]; then
            echo "❌ FAIL: $count $level finding(s) exceed threshold (fail_on: $FAIL_ON)"
            FAILED=1
        elif [ "$action" = "warn" ]; then
            echo "⚠️  WARN: $count $level finding(s) (warn_on: $WARN_ON)"
            WARNED=1
        fi
    fi
}

# Severity levels in order: critical > high > medium > low
# fail_on means: fail if there are findings at that level or above
# warn_on means: warn if there are findings at that level or above

case "$FAIL_ON" in
    critical)
        check_severity "critical" "$CRITICAL" "fail"
        ;;
    high)
        check_severity "critical" "$CRITICAL" "fail"
        check_severity "high" "$HIGH" "fail"
        ;;
    medium)
        check_severity "critical" "$CRITICAL" "fail"
        check_severity "high" "$HIGH" "fail"
        check_severity "medium" "$MEDIUM" "fail"
        ;;
    low)
        check_severity "critical" "$CRITICAL" "fail"
        check_severity "high" "$HIGH" "fail"
        check_severity "medium" "$MEDIUM" "fail"
        check_severity "low" "$LOW" "fail"
        ;;
    none)
        # Never fail on findings
        ;;
    *)
        die "Unknown fail_on value: $FAIL_ON"
        ;;
esac

# Only warn on levels not already covered by fail
case "$WARN_ON" in
    critical)
        [ "$FAIL_ON" != "critical" ] && check_severity "critical" "$CRITICAL" "warn"
        ;;
    high)
        [ "$FAIL_ON" = "none" ] || [ "$FAIL_ON" = "critical" ] && check_severity "high" "$HIGH" "warn"
        ;;
    medium)
        case "$FAIL_ON" in
            none|critical|high) check_severity "medium" "$MEDIUM" "warn" ;;
        esac
        ;;
    low)
        case "$FAIL_ON" in
            none|critical|high|medium) check_severity "low" "$LOW" "warn" ;;
        esac
        ;;
esac

# --- Result ---

if [ "$FAILED" -eq 1 ]; then
    echo ""
    echo "🚫 Pipeline FAILED — findings exceed configured thresholds"
    echo "   To adjust: edit 'thresholds.fail_on' in $CONFIG_PATH"
    echo "   To waive: use 'scripts/fortressci-waiver.sh add ...'"
    exit 1
elif [ "$WARNED" -eq 1 ]; then
    echo ""
    echo "⚠️  Pipeline PASSED with warnings"
    exit 0
else
    echo "✅ All clear — no findings exceed thresholds"
    exit 0
fi
