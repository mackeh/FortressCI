#!/bin/bash
# FortressCI Waiver Management CLI
# Manages security finding waivers in .security/waivers.yml
#
# Usage:
#   fortressci-waiver.sh add --id <finding-id> --scanner <tool> --severity <level> \
#                            --reason <justification> --expires <YYYY-MM-DD> --author <name>
#   fortressci-waiver.sh list [--expired] [--scanner <tool>]
#   fortressci-waiver.sh expire [--before <YYYY-MM-DD>]
#   fortressci-waiver.sh remove --id <finding-id>

set -euo pipefail

WAIVERS_FILE=".security/waivers.yml"
TODAY=$(date +%Y-%m-%d)

# --- Helpers ---

usage() {
    cat <<'USAGE'
🏰 FortressCI Waiver CLI

Commands:
  add       Add a new waiver
  list      List waivers (active by default)
  expire    Remove expired waivers
  remove    Remove a specific waiver by ID

Usage:
  fortressci-waiver.sh add \
    --id "CVE-2024-1234" \
    --scanner "snyk" \
    --severity "high" \
    --reason "Dev-dependency only, not in production" \
    --expires "2026-06-01" \
    --author "@your-name"

  fortressci-waiver.sh list
  fortressci-waiver.sh list --expired
  fortressci-waiver.sh list --scanner snyk

  fortressci-waiver.sh expire
  fortressci-waiver.sh expire --before 2026-01-01

  fortressci-waiver.sh remove --id "CVE-2024-1234"
USAGE
    exit 0
}

die() { echo "❌ $*" >&2; exit 1; }

ensure_waivers_file() {
    if [ ! -f "$WAIVERS_FILE" ]; then
        mkdir -p "$(dirname "$WAIVERS_FILE")"
        cat > "$WAIVERS_FILE" <<'EOF'
# Security Waivers Configuration
# Use this file to document accepted risks or false positives.
# All waivers must have an expiry date.

waivers: []
EOF
        echo "Created $WAIVERS_FILE"
    fi
}

# --- Commands ---

cmd_add() {
    local id="" scanner="" severity="" reason="" expires="" author=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --id) id="$2"; shift ;;
            --scanner) scanner="$2"; shift ;;
            --severity) severity="$2"; shift ;;
            --reason) reason="$2"; shift ;;
            --expires) expires="$2"; shift ;;
            --author) author="$2"; shift ;;
            *) die "Unknown option: $1" ;;
        esac
        shift
    done

    [ -z "$id" ] && die "Missing --id"
    [ -z "$scanner" ] && die "Missing --scanner"
    [ -z "$severity" ] && die "Missing --severity"
    [ -z "$reason" ] && die "Missing --reason"
    [ -z "$expires" ] && die "Missing --expires"
    [ -z "$author" ] && die "Missing --author"

    # Validate severity
    case "$severity" in
        critical|high|medium|low) ;;
        *) die "Invalid severity: $severity (must be critical|high|medium|low)" ;;
    esac

    # Validate expiry date format
    if ! date -d "$expires" +%Y-%m-%d >/dev/null 2>&1; then
        die "Invalid date format: $expires (use YYYY-MM-DD)"
    fi

    # Check max expiry if .fortressci.yml exists
    if [ -f ".fortressci.yml" ]; then
        max_days=$(grep -E "^\s*max_expiry_days:" .fortressci.yml | sed 's/.*:\s*//' | xargs)
        if [ -n "$max_days" ]; then
            max_date=$(date -d "+${max_days} days" +%Y-%m-%d)
            if [ "$expires" \> "$max_date" ]; then
                die "Expiry date $expires exceeds max_expiry_days ($max_days days, max: $max_date)"
            fi
        fi
    fi

    # Check for duplicates
    if grep -q "id: \"$id\"" "$WAIVERS_FILE" 2>/dev/null; then
        die "Waiver with id '$id' already exists. Use 'remove' first to replace it."
    fi

    ensure_waivers_file

    # Append waiver entry
    # Remove trailing empty array if present
    sed -i 's/^waivers: \[\]/waivers:/' "$WAIVERS_FILE"

    cat >> "$WAIVERS_FILE" <<EOF

  - id: "$id"
    scanner: "$scanner"
    severity: "$severity"
    justification: "$reason"
    expires_on: "$expires"
    approved_by: "$author"
EOF

    echo "✅ Waiver added: $id ($scanner, $severity)"
    echo "   Expires: $expires"
    echo "   Approved by: $author"
}

cmd_list() {
    local show_expired=false
    local filter_scanner=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --expired) show_expired=true ;;
            --scanner) filter_scanner="$2"; shift ;;
            *) die "Unknown option: $1" ;;
        esac
        shift
    done

    if [ ! -f "$WAIVERS_FILE" ]; then
        echo "No waivers file found at $WAIVERS_FILE"
        exit 0
    fi

    echo "🏰 FortressCI Waivers"
    echo "====================="
    echo ""

    local active=0 expired=0
    local current_id="" current_scanner="" current_severity="" current_reason="" current_expires="" current_author=""

    while IFS= read -r line; do
        case "$line" in
            *"- id:"*)
                # Print previous entry if complete
                if [ -n "$current_id" ]; then
                    print_waiver
                fi
                current_id=$(echo "$line" | sed 's/.*id:\s*//' | tr -d '"')
                current_scanner="" current_severity="" current_reason="" current_expires="" current_author=""
                ;;
            *"scanner:"*)
                current_scanner=$(echo "$line" | sed 's/.*scanner:\s*//' | tr -d '"')
                ;;
            *"severity:"*)
                current_severity=$(echo "$line" | sed 's/.*severity:\s*//' | tr -d '"')
                ;;
            *"justification:"*)
                current_reason=$(echo "$line" | sed 's/.*justification:\s*//' | tr -d '"')
                ;;
            *"expires_on:"*)
                current_expires=$(echo "$line" | sed 's/.*expires_on:\s*//' | tr -d '"')
                ;;
            *"approved_by:"*)
                current_author=$(echo "$line" | sed 's/.*approved_by:\s*//' | tr -d '"')
                ;;
        esac
    done < "$WAIVERS_FILE"

    # Print last entry
    if [ -n "$current_id" ]; then
        print_waiver
    fi

    echo ""
    echo "Active: $active | Expired: $expired"
}

print_waiver() {
    local is_expired=false
    if [ -n "$current_expires" ] && [ "$current_expires" \< "$TODAY" ]; then
        is_expired=true
        expired=$((expired + 1))
    else
        active=$((active + 1))
    fi

    # Apply filters
    if [ "$show_expired" = "false" ] && [ "$is_expired" = "true" ]; then
        return
    fi
    if [ -n "$filter_scanner" ] && [ "$current_scanner" != "$filter_scanner" ]; then
        return
    fi

    local status="✅ Active"
    if [ "$is_expired" = "true" ]; then
        status="⏰ Expired"
    fi

    echo "  $status  $current_id"
    echo "          Scanner: $current_scanner | Severity: $current_severity"
    echo "          Reason: $current_reason"
    echo "          Expires: $current_expires | Approved: $current_author"
    echo ""
}

cmd_expire() {
    local before="$TODAY"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --before) before="$2"; shift ;;
            *) die "Unknown option: $1" ;;
        esac
        shift
    done

    if [ ! -f "$WAIVERS_FILE" ]; then
        echo "No waivers file found."
        exit 0
    fi

    # Count expired waivers before removal
    local count=0
    while IFS= read -r line; do
        expires=$(echo "$line" | grep -oP 'expires_on:\s*"\K[^"]+' || true)
        if [ -n "$expires" ] && [ "$expires" \< "$before" ]; then
            count=$((count + 1))
        fi
    done < <(grep "expires_on:" "$WAIVERS_FILE")

    if [ "$count" -eq 0 ]; then
        echo "No expired waivers found (before $before)."
        exit 0
    fi

    # Create temp file without expired entries
    python3 -c "
import yaml, sys
from datetime import datetime

before = datetime.strptime('$before', '%Y-%m-%d').date()
with open('$WAIVERS_FILE') as f:
    data = yaml.safe_load(f)

if not data or 'waivers' not in data or not data['waivers']:
    sys.exit(0)

original = len(data['waivers'])
data['waivers'] = [
    w for w in data['waivers']
    if datetime.strptime(w.get('expires_on', '9999-12-31'), '%Y-%m-%d').date() >= before
]
removed = original - len(data['waivers'])

with open('$WAIVERS_FILE', 'w') as f:
    f.write('# Security Waivers Configuration\n')
    f.write('# Use this file to document accepted risks or false positives.\n')
    f.write('# All waivers must have an expiry date.\n\n')
    yaml.dump(data, f, default_flow_style=False, sort_keys=False)

print(f'🗑️  Removed {removed} expired waiver(s) (before {before})')
" 2>/dev/null || {
        echo "⚠️  Python yaml module not available. $count expired waiver(s) found — remove manually."
        exit 1
    }
}

cmd_remove() {
    local id=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --id) id="$2"; shift ;;
            *) die "Unknown option: $1" ;;
        esac
        shift
    done

    [ -z "$id" ] && die "Missing --id"

    if ! grep -q "id: \"$id\"" "$WAIVERS_FILE" 2>/dev/null; then
        die "Waiver '$id' not found"
    fi

    python3 -c "
import yaml
with open('$WAIVERS_FILE') as f:
    data = yaml.safe_load(f)

data['waivers'] = [w for w in (data.get('waivers') or []) if w.get('id') != '$id']

with open('$WAIVERS_FILE', 'w') as f:
    f.write('# Security Waivers Configuration\n')
    f.write('# Use this file to document accepted risks or false positives.\n')
    f.write('# All waivers must have an expiry date.\n\n')
    yaml.dump(data, f, default_flow_style=False, sort_keys=False)

print('✅ Removed waiver: $id')
" 2>/dev/null || {
        die "Python yaml module not available. Remove the waiver manually from $WAIVERS_FILE"
    }
}

# --- Main ---

[ $# -eq 0 ] && usage

COMMAND="$1"
shift

case "$COMMAND" in
    add)    cmd_add "$@" ;;
    list)   cmd_list "$@" ;;
    expire) cmd_expire "$@" ;;
    remove) cmd_remove "$@" ;;
    help|-h|--help) usage ;;
    *) die "Unknown command: $COMMAND (use: add, list, expire, remove)" ;;
esac
