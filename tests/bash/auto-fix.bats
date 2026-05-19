#!/usr/bin/env bats

setup() {
  export REPO_ROOT="$BATS_TEST_DIRNAME/../.."
  export TMP_DIR="$BATS_TEST_TMPDIR/auto-fix"
  mkdir -p "$TMP_DIR"
  cd "$TMP_DIR"
}

@test "auto-fix --help prints usage and exits 0" {
  run "$REPO_ROOT/scripts/auto-fix.sh" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: auto-fix.sh"* ]]
  [[ "$output" == *"WORKSPACE"* ]]
  [[ "$output" == *"DRY_RUN"* ]]
}

@test "auto-fix -h prints usage and exits 0" {
  run "$REPO_ROOT/scripts/auto-fix.sh" -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: auto-fix.sh"* ]]
}

@test "auto-fix runs without scanners installed and reports skipped" {
  # Fresh git repo so the final `git diff` check is well-defined.
  # No commits needed — `git diff --name-only` works on an empty repo.
  git init -q

  # Provide a `git` shim on PATH so the script's missing-tool branches fire
  # for snyk/checkov but `git diff` still works.
  mkdir -p bin
  ln -s "$(command -v git)" bin/git
  export PATH="$PWD/bin"

  run "$REPO_ROOT/scripts/auto-fix.sh" .
  [ "$status" -eq 0 ]
  [[ "$output" == *"Snyk CLI not found"* ]]
  [[ "$output" == *"Checkov CLI not found"* ]]
  [[ "$output" == *"Auto-remediation attempt complete"* ]]
}
