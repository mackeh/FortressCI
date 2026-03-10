#!/usr/bin/env bats

setup() {
  export REPO_ROOT="$BATS_TEST_DIRNAME/../.."
  export TMP_DIR="$BATS_TEST_TMPDIR/policy"
  mkdir -p "$TMP_DIR/results" "$TMP_DIR/.security"

  # Minimal policy file with all checks enabled
  cat >"$TMP_DIR/.security/policy.yml" <<'YAML'
policies:
  - id: FCI-POL-003
    name: No critical CVEs
    check: no-critical-cves
    severity: critical
    enabled: true

  - id: FCI-POL-005
    name: No secrets detected
    check: no-secrets
    severity: critical
    enabled: true

  - id: FCI-POL-006
    name: Security waivers must not be expired
    check: waivers-current
    severity: medium
    enabled: true
YAML

  # Default: no waivers
  cat >"$TMP_DIR/.security/waivers.yml" <<'YAML'
waivers: []
YAML

  # Default summary: no findings
  cat >"$TMP_DIR/results/summary.json" <<'JSON'
{"tools":{"trufflehog":{"critical":0,"high":0,"medium":0,"low":0}},"totals":{"critical":0,"high":0,"medium":0,"low":0},"total_findings":0}
JSON
}

@test "policy pass when no critical CVEs and no secrets" {
  cd "$TMP_DIR"
  run "$REPO_ROOT/scripts/fortressci-policy-check.sh" "$TMP_DIR/.security/policy.yml" "$TMP_DIR/results"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Policy check PASSED"* ]]
}

@test "policy fail when critical CVEs exist (FCI-POL-003)" {
  cat >"$TMP_DIR/results/summary.json" <<'JSON'
{"tools":{"trufflehog":{"critical":0,"high":0,"medium":0,"low":0}},"totals":{"critical":2,"high":0,"medium":0,"low":0},"total_findings":2}
JSON

  cd "$TMP_DIR"
  run "$REPO_ROOT/scripts/fortressci-policy-check.sh" "$TMP_DIR/.security/policy.yml" "$TMP_DIR/results"
  [ "$status" -eq 1 ]
  [[ "$output" == *"FCI-POL-003"* ]]
  [[ "$output" == *"Fail"* ]]
}

@test "policy fail when secrets detected (FCI-POL-005)" {
  cat >"$TMP_DIR/results/summary.json" <<'JSON'
{"tools":{"trufflehog":{"critical":3,"high":0,"medium":0,"low":0}},"totals":{"critical":3,"high":0,"medium":0,"low":0},"total_findings":3}
JSON

  cd "$TMP_DIR"
  run "$REPO_ROOT/scripts/fortressci-policy-check.sh" "$TMP_DIR/.security/policy.yml" "$TMP_DIR/results"
  [ "$status" -eq 1 ]
  [[ "$output" == *"FCI-POL-005"* ]]
  [[ "$output" == *"secret"* ]]
}

@test "policy fail when expired waivers exist (FCI-POL-006)" {
  cat >"$TMP_DIR/.security/waivers.yml" <<'YAML'
waivers:
  - id: "CVE-EXPIRED"
    scanner: "snyk"
    severity: "high"
    justification: "Already expired"
    expires_on: "2020-01-01"
    approved_by: "@old"
YAML

  cd "$TMP_DIR"
  run "$REPO_ROOT/scripts/fortressci-policy-check.sh" "$TMP_DIR/.security/policy.yml" "$TMP_DIR/results"
  [ "$status" -eq 1 ]
  [[ "$output" == *"FCI-POL-006"* ]]
  [[ "$output" == *"expired"* ]]
}

@test "policy pass when waivers are all active (FCI-POL-006)" {
  cat >"$TMP_DIR/.security/waivers.yml" <<'YAML'
waivers:
  - id: "CVE-ACTIVE"
    scanner: "snyk"
    severity: "high"
    justification: "Still valid"
    expires_on: "2099-12-31"
    approved_by: "@current"
YAML

  cd "$TMP_DIR"
  run "$REPO_ROOT/scripts/fortressci-policy-check.sh" "$TMP_DIR/.security/policy.yml" "$TMP_DIR/results"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Policy check PASSED"* ]]
}
