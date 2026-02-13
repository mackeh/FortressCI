#!/usr/bin/env bats

setup() {
  export REPO_ROOT="$BATS_TEST_DIRNAME/../.."
  export TMP_DIR="$BATS_TEST_TMPDIR/thresholds"
  mkdir -p "$TMP_DIR/results" "$TMP_DIR/.security"

  cat >"$TMP_DIR/.fortressci.yml" <<'YAML'
thresholds:
  fail_on: critical
  warn_on: high
waivers:
  path: .security/waivers.yml
YAML

  cat >"$TMP_DIR/.security/waivers.yml" <<'YAML'
waivers: []
YAML
}

@test "thresholds pass when no findings exceed fail_on" {
  cat >"$TMP_DIR/results/summary.json" <<'JSON'
{"tools":{},"totals":{"critical":0,"high":0,"medium":1,"low":2},"total_findings":3}
JSON

  run "$REPO_ROOT/scripts/check-thresholds.sh" "$TMP_DIR/results" "$TMP_DIR/.fortressci.yml"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Pipeline PASSED"* || "$output" == *"All clear"* ]]
}

@test "thresholds fail when critical findings exist and fail_on is critical" {
  cat >"$TMP_DIR/results/summary.json" <<'JSON'
{"tools":{},"totals":{"critical":1,"high":0,"medium":0,"low":0},"total_findings":1}
JSON

  run "$REPO_ROOT/scripts/check-thresholds.sh" "$TMP_DIR/results" "$TMP_DIR/.fortressci.yml"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Pipeline FAILED"* ]]
}
