# FortressCI Improvement Roadmap

This roadmap focuses on the highest-leverage changes that reduce false signal, improve reproducibility, and make the platform easier to adopt and maintain.

## Priority 1: Separate Scanner Image Maintenance From App Scanning

Status: ✅ Complete

Why it matters:
- FortressCI's root `Dockerfile` builds the scanner image, not a target application image.
- Scanning that image in the main DevSecOps workflow mixes toolchain CVEs into repository code scanning results.
- This creates noisy alerts and obscures actual product issues.

Implementation:
- Add a dedicated GitHub Actions workflow for scanner image build verification and image hygiene checks.
- Stop the main `.github/workflows/devsecops.yml` pipeline from running app-oriented container build/DAST jobs in the FortressCI repository itself.
- Keep container scan/sign jobs available in the reusable reference workflow for downstream adopters.

Success criteria:
- FortressCI no longer uploads root scanner image SARIF through the main DevSecOps pipeline.
- Scanner image regressions are caught by a dedicated maintenance workflow.
- Code scanning findings better reflect application or repository issues instead of bundled scanner dependencies.

## Priority 2: Fail-Closed Binary Supply Chain

Status: ✅ Complete

Why it matters:
- The project installs several tools via remote shell scripts and binary downloads.
- Version pinning helps, but integrity verification is still the stronger control.

Implementation:
- Added checksum or signature verification for every downloaded installer and binary in `Dockerfile` and CI scripts.
- Recorded the expected versions and digests in `.security/tooling-checksums.env`.
- CI fails immediately when an external artifact changes unexpectedly.

Success criteria:
- Every `curl`-fetched binary is verified before execution.
- Tool version bumps require an explicit digest update in git.

## Priority 3: Expand Deterministic Script Tests

Status: ✅ Complete

Why it matters:
- FortressCI is script-first, but most validation is still runtime smoke testing.
- Regressions in shell glue and report generation are easy to miss without fixtures.

Implementation:
- Added fixture-driven Bats tests for `fortressci-policy-check.sh` and `fortressci-waiver.sh`.
- Added fixture-driven Python tests for `summarize.py` result aggregation and waiver status.
- Tests use in-memory fixtures so behavior changes are intentional and reviewable.

Success criteria:
- Core scripts have deterministic tests covering success and failure paths.
- CI catches logic regressions before scheduled security jobs do.

## Priority 4: Diff-Aware Scanning Modes

Status: ✅ Complete

Why it matters:
- Running every scanner across the whole repository on every PR is slower and noisier than necessary.

Implementation:
- Added `scripts/changed-files.sh` for PR changed-file detection and categorisation.
- Added `detect-changes` job to `devsecops.yml` that outputs scan category flags.
- SAST, SCA, and IaC scan jobs skip on PRs when their file category has no changes.
- Full baseline scans preserved for `main`, scheduled runs, and manual dispatches.

Success criteria:
- PR runtimes drop while retaining scheduled full coverage.
- Findings align more closely with the actual change set.

## Priority 5: Waiver Governance

Status: ✅ Complete

Why it matters:
- Exception processes degrade quickly if they are not time-bounded and attributable.

Implementation:
- Implemented FCI-POL-005 (no secrets) and FCI-POL-006 (expired waivers) in `fortressci-policy-check.sh`.
- `summarize.py` now surfaces active, expired, and expiring_soon waiver counts in `summary.json`.
- `check-thresholds.sh` properly deducts active waivers per-severity from finding counts.
- Expiring (within 14 days) and expired waivers are highlighted in scan output.

Success criteria:
- Waivers become auditable and time-boxed.
- Teams can see exception debt directly in normal reporting.
