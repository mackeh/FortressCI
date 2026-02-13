#!/usr/bin/env bats

setup() {
  export REPO_ROOT="$BATS_TEST_DIRNAME/../.."
  export TMP_WORK="$BATS_TEST_TMPDIR/workspace"
  mkdir -p "$TMP_WORK/.security" "$TMP_WORK/.github/workflows"

  cat >"$TMP_WORK/.fortressci.yml" <<'YAML'
thresholds:
  fail_on: critical
  warn_on: high

scanners:
  secrets:
    enabled: true
    tool: trufflehog
YAML

  cat >"$TMP_WORK/.pre-commit-config.yaml" <<'YAML'
repos: []
YAML

  cat >"$TMP_WORK/.security/policy.yml" <<'YAML'
policies: []
YAML

  cat >"$TMP_WORK/.security/waivers.yml" <<'YAML'
waivers: []
YAML

  cat >"$TMP_WORK/.security/compliance-mappings.yml" <<'YAML'
mappings: []
YAML

  cat >"$TMP_WORK/.github/workflows/devsecops.yml" <<'YAML'
name: test
on: [push]
jobs: {}
YAML

  git -C "$TMP_WORK" init >/dev/null
}

@test "doctor --help prints usage and exits 0" {
  run "$REPO_ROOT/scripts/fortressci-doctor.sh" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: fortressci-doctor.sh"* ]]
}

@test "doctor exits 2 for missing workspace" {
  run "$REPO_ROOT/scripts/fortressci-doctor.sh" --workspace "$BATS_TEST_TMPDIR/does-not-exist"
  [ "$status" -eq 2 ]
  [[ "$output" == *"Workspace path does not exist"* ]]
}

@test "doctor runs in non-strict mode and returns 0 on warnings" {
  run "$REPO_ROOT/scripts/fortressci-doctor.sh" --workspace "$TMP_WORK"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Summary:"* ]]
}
