# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

FortressCI is a secure-by-default DevSecOps platform blueprint. It integrates open-source security tools (TruffleHog, Semgrep, Snyk, Checkov, Trivy, OWASP ZAP, Cosign) into CI/CD pipelines across 6 platforms (GitHub Actions, GitLab CI, Bitbucket, Azure, Jenkins, CircleCI). It is a template project — users fork it and adapt to their needs.

## Common Commands

```bash
# Build the all-in-one scanner Docker image
docker build -t fortressci/scan .

# Run all scans locally via Docker (outputs to ./results/)
docker run --rm -v $(pwd):/workspace -v $(pwd)/results:/results fortressci/scan /workspace

# Run the interactive setup wizard (generates CI config, pre-commit hooks, waivers)
./scripts/fortressci-init.sh
./scripts/fortressci-init.sh --ci github-actions  # skip interactive prompts

# Install pre-commit hooks locally
pre-commit install

# Generate HTML report from scan results
python3 scripts/generate-report.py

# Generate SARIF summary statistics
python3 scripts/summarize.py

# Generate Cosign signing keys
./scripts/generate_keys.sh
```

There are no unit tests or linters — this is a blueprint/template project, not a library.

## Architecture

**Three-phase security model:**
1. **Phase 1 (Local):** Pre-commit hooks (`.pre-commit-config.yaml`) run TruffleHog + Checkov before each commit
2. **Phase 2 (CI/CD):** Pipeline runs 6 parallel security scans + signing/attestation + reporting
3. **Phase 3 (Infrastructure):** Container registry signing, SBOM generation, artifact storage

**Primary CI workflow** (`.github/workflows/devsecops.yml`): 9 jobs — secret-scan, sast-scan, sca-scan, iac-scan, cost-estimation, container-build-sign, dast-scan, compliance-audit, pr-feedback. Most jobs use `continue-on-error: true` with separate gatekeeper steps for severity thresholds.

**Report pipeline:** SARIF/JSON scan outputs → `generate-report.py` (parses findings) → `templates/report.html.j2` (Jinja2) → interactive HTML report with charts/filtering.

**CLI init wizard** (`scripts/fortressci-init.sh`): Detects project type (Node.js/Python/Go/Java) and CI platform, copies appropriate template from `templates/`, generates `.pre-commit-config.yaml` and `.security/waivers.yml`.

## Key Files

| File | Purpose |
|------|---------|
| `scripts/fortressci-init.sh` | Interactive setup wizard CLI (Bash) |
| `scripts/run-all.sh` | Docker entrypoint — orchestrates all 5 scans sequentially |
| `scripts/generate-report.py` | Parses SARIF+JSON → HTML report via Jinja2 |
| `scripts/summarize.py` | Aggregates scan results into summary statistics |
| `.github/workflows/devsecops.yml` | Primary GitHub Actions pipeline |
| `.github/scripts/post_summary.js` | Posts security summary as PR comment |
| `.security/waivers.yml` | Approved security finding exceptions (with expiry dates) |
| `templates/` | CI/CD configs for all 6 platforms + pre-commit + waivers templates |
| `terraform/main.tf` | Sample (intentionally vulnerable) IaC for demo purposes |

## Languages and Tools

- **Bash**: CLI wizard, scan orchestration, key generation
- **Python**: Report generation, SARIF parsing (uses `jinja2`, `json`, `argparse`)
- **JavaScript**: PR comment posting (GitHub Actions script)
- **YAML**: All CI/CD configs, pre-commit hooks, waivers
- **Docker**: All-in-one scanner image (Ubuntu 22.04 base, installs all tools via pip/npm/curl)

## Conventions

- **Output format**: SARIF standard for all scanners that support it; JSON for TruffleHog/Snyk native output
- **Waiver structure**: Each waiver in `.security/waivers.yml` requires `id`, `scanner`, `severity`, `justification`, `expires_on`, `approved_by`
- **Template mirroring**: All 6 CI platform templates implement the same scan stages with platform-specific syntax — changes to scan logic should be reflected across all templates
- **Commit style**: Conventional commits (`feat:`, `fix:`, `docs:`)
- **Environment secrets**: `SNYK_TOKEN`, `COSIGN_KEY`/`COSIGN_PASSWORD`, `INFRACOST_API_KEY` — never hardcode these
