#!/usr/bin/env bats

setup() {
  export REPO_ROOT="$BATS_TEST_DIRNAME/../.."
  export TMP_DIR="$BATS_TEST_TMPDIR/generate-keys"
  mkdir -p "$TMP_DIR"
  cd "$TMP_DIR"
}

@test "generate_keys --help prints usage and exits 0" {
  run "$REPO_ROOT/scripts/generate_keys.sh" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: generate_keys.sh"* ]]
  [[ "$output" == *"Cosign"* ]]
}

@test "generate_keys rejects unknown arguments" {
  run "$REPO_ROOT/scripts/generate_keys.sh" --bogus
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unknown argument"* ]]
}

@test "generate_keys fails clearly when cosign is missing" {
  export PATH="/nonexistent"
  run "$REPO_ROOT/scripts/generate_keys.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"cosign is not installed"* ]]
}

@test "generate_keys refuses to overwrite existing cosign.key" {
  echo "existing" > cosign.key
  # Provide a fake cosign on PATH so we get past the installed-check.
  mkdir -p bin
  cat >bin/cosign <<'SH'
#!/bin/bash
echo "fake cosign called: should not happen"
exit 0
SH
  chmod +x bin/cosign
  export PATH="$PWD/bin:$PATH"

  run "$REPO_ROOT/scripts/generate_keys.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"cosign.key already exists"* ]]
  # Original file untouched
  [ "$(cat cosign.key)" = "existing" ]
}
