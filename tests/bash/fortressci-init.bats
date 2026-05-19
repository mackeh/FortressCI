#!/usr/bin/env bats

setup() {
  export REPO_ROOT="$BATS_TEST_DIRNAME/../.."
}

@test "fortressci-init --help prints usage and exits 0" {
  run "$REPO_ROOT/scripts/fortressci-init.sh" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: fortressci-init.sh"* ]]
  [[ "$output" == *"--ci"* ]]
}

@test "fortressci-init -h prints usage" {
  run "$REPO_ROOT/scripts/fortressci-init.sh" -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "fortressci-init rejects unknown arguments" {
  run "$REPO_ROOT/scripts/fortressci-init.sh" --bogus
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unknown parameter"* ]]
}

@test "fortressci-init --ci <platform> writes expected files" {
  export TMP_DIR="$BATS_TEST_TMPDIR/init-run"
  mkdir -p "$TMP_DIR"
  cd "$TMP_DIR"
  # Force github-actions and provide a marker package.json so language
  # detection has something to find.
  echo '{}' > package.json
  run "$REPO_ROOT/scripts/fortressci-init.sh" --ci github-actions
  [ "$status" -eq 0 ]
  [ -f ".github/workflows/devsecops.yml" ]
  [ -f ".pre-commit-config.yaml" ]
  [ -f ".security/waivers.yml" ]
  [ -f ".security/policy.yml" ]
  [ -f ".fortressci.yml" ]
}
