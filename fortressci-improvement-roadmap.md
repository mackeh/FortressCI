# FortressCI Improvement Roadmap

This roadmap focuses on the highest-leverage changes that reduce false signal, improve reproducibility, and make the platform easier to adopt and maintain.

## Priority 1: Separate Scanner Image Maintenance From App Scanning

Status: In progress

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

Status: Planned

Why it matters:
- The project installs several tools via remote shell scripts and binary downloads.
- Version pinning helps, but integrity verification is still the stronger control.

Implementation:
- Add checksum or signature verification for every downloaded installer and binary in `Dockerfile` and CI scripts.
- Record the expected versions and digests in one tracked manifest.
- Make CI fail immediately when an external artifact changes unexpectedly.

Success criteria:
- Every `curl`-fetched binary is verified before execution.
- Tool version bumps require an explicit digest update in git.

## Priority 3: Expand Deterministic Script Tests

Status: Planned

Why it matters:
- FortressCI is script-first, but most validation is still runtime smoke testing.
- Regressions in shell glue and report generation are easy to miss without fixtures.

Implementation:
- Add fixture-driven Bash tests for `run-all.sh`, `check-thresholds.sh`, and `fortressci-policy-check.sh`.
- Add Python tests for report generation and result normalization paths.
- Use stable sample `results/` fixtures so behavior changes are intentional and reviewable.

Success criteria:
- Core scripts have deterministic tests covering success and failure paths.
- CI catches logic regressions before scheduled security jobs do.

## Priority 4: Diff-Aware Scanning Modes

Status: Planned

Why it matters:
- Running every scanner across the whole repository on every PR is slower and noisier than necessary.

Implementation:
- Add changed-file detection for PRs.
- Run focused scans in PRs and preserve full baseline scans for `main`, scheduled runs, and manual dispatches.
- Report which files were scanned so the reduced scope is explicit.

Success criteria:
- PR runtimes drop while retaining scheduled full coverage.
- Findings align more closely with the actual change set.

## Priority 5: Waiver Governance

Status: Planned

Why it matters:
- Exception processes degrade quickly if they are not time-bounded and attributable.

Implementation:
- Require owner, reason, and expiration metadata on waivers.
- Surface expiring and expired waivers in generated reports.
- Add policy checks that fail on invalid or stale exceptions.

Success criteria:
- Waivers become auditable and time-boxed.
- Teams can see exception debt directly in normal reporting.
