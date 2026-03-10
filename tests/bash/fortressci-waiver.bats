#!/usr/bin/env bats

setup() {
  export REPO_ROOT="$BATS_TEST_DIRNAME/../.."
  export TMP_DIR="$BATS_TEST_TMPDIR/waiver"
  mkdir -p "$TMP_DIR/.security"
  cd "$TMP_DIR"

  # Create minimal .fortressci.yml with max_expiry_days
  cat >"$TMP_DIR/.fortressci.yml" <<'YAML'
thresholds:
  fail_on: critical
  warn_on: high
waivers:
  require_approval: true
  max_expiry_days: 90
  path: .security/waivers.yml
YAML

  # Start with empty waivers
  cat >"$TMP_DIR/.security/waivers.yml" <<'YAML'
waivers: []
YAML
}

@test "waiver add creates valid entry" {
  cd "$TMP_DIR"
  run "$REPO_ROOT/scripts/fortressci-waiver.sh" add \
    --id "CVE-2024-0001" \
    --scanner "snyk" \
    --severity "high" \
    --reason "Test waiver" \
    --expires "$(date -d '+30 days' +%Y-%m-%d)" \
    --author "@tester"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Waiver added"* ]]
  grep -q "CVE-2024-0001" "$TMP_DIR/.security/waivers.yml"
}

@test "waiver add rejects duplicate IDs" {
  cd "$TMP_DIR"
  # Add first
  "$REPO_ROOT/scripts/fortressci-waiver.sh" add \
    --id "CVE-DUP-001" \
    --scanner "snyk" \
    --severity "medium" \
    --reason "First" \
    --expires "$(date -d '+30 days' +%Y-%m-%d)" \
    --author "@first"

  # Attempt duplicate
  run "$REPO_ROOT/scripts/fortressci-waiver.sh" add \
    --id "CVE-DUP-001" \
    --scanner "trivy" \
    --severity "high" \
    --reason "Duplicate" \
    --expires "$(date -d '+30 days' +%Y-%m-%d)" \
    --author "@second"
  [ "$status" -ne 0 ]
  [[ "$output" == *"already exists"* ]]
}

@test "waiver add rejects expiry beyond max_expiry_days" {
  cd "$TMP_DIR"
  run "$REPO_ROOT/scripts/fortressci-waiver.sh" add \
    --id "CVE-LONG-001" \
    --scanner "snyk" \
    --severity "low" \
    --reason "Too long" \
    --expires "$(date -d '+365 days' +%Y-%m-%d)" \
    --author "@tester"
  [ "$status" -ne 0 ]
  [[ "$output" == *"max_expiry_days"* ]]
}

@test "waiver list filters by scanner" {
  cd "$TMP_DIR"
  # Add two waivers with different scanners
  "$REPO_ROOT/scripts/fortressci-waiver.sh" add \
    --id "CVE-SNYK-001" \
    --scanner "snyk" \
    --severity "high" \
    --reason "Snyk waiver" \
    --expires "$(date -d '+30 days' +%Y-%m-%d)" \
    --author "@tester"

  "$REPO_ROOT/scripts/fortressci-waiver.sh" add \
    --id "CVE-TRIVY-001" \
    --scanner "trivy" \
    --severity "medium" \
    --reason "Trivy waiver" \
    --expires "$(date -d '+30 days' +%Y-%m-%d)" \
    --author "@tester"

  run "$REPO_ROOT/scripts/fortressci-waiver.sh" list --scanner snyk
  [ "$status" -eq 0 ]
  [[ "$output" == *"CVE-SNYK-001"* ]]
  [[ "$output" != *"CVE-TRIVY-001"* ]]
}

@test "waiver remove deletes entry" {
  cd "$TMP_DIR"
  "$REPO_ROOT/scripts/fortressci-waiver.sh" add \
    --id "CVE-DEL-001" \
    --scanner "snyk" \
    --severity "high" \
    --reason "To be removed" \
    --expires "$(date -d '+30 days' +%Y-%m-%d)" \
    --author "@tester"

  # Verify it exists
  grep -q "CVE-DEL-001" "$TMP_DIR/.security/waivers.yml"

  # Remove it
  run "$REPO_ROOT/scripts/fortressci-waiver.sh" remove --id "CVE-DEL-001"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Removed"* ]]

  # Verify it's gone
  ! grep -q "CVE-DEL-001" "$TMP_DIR/.security/waivers.yml"
}

@test "waiver help prints usage" {
  run "$REPO_ROOT/scripts/fortressci-waiver.sh" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"FortressCI Waiver CLI"* ]]
}
