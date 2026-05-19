# FortressCI Roadmap

> Last updated: May 19, 2026

> See [`ROADMAP.md`](./ROADMAP.md) for the deep-dive implementation guide.
> This file is the high-level summary kept in sync with `CHANGELOG.md`.

---

## Completed Phases

### v1.0.x — Foundation

#### Phase 1: Shift Left (Local Development)
- Pre-commit hooks via `.pre-commit-config.yaml`
- TruffleHog secrets detection (blocks commits with hardcoded credentials)
- Checkov IaC scanning locally (Terraform, CloudFormation, Bicep)
- Standard code quality hooks (trailing whitespace, file integrity)

#### Phase 2: Automated Pipeline (CI/CD)
- GitHub Actions workflow (`devsecops.yml`) triggered on push and PR
- TruffleHog deep scan on git history
- Semgrep SAST (OWASP Top 10, auto-config)
- Snyk SCA for dependency vulnerability scanning
- Checkov IaC scanning in CI
- Trivy container image scanning (OS + library vulnerabilities)
- SARIF output for GitHub Code Scanning integration
- Scheduled weekly baseline secret scans

#### Phase 3: Infrastructure & Trust
- Sample Terraform configs for testing
- Sample Dockerfile for container scan testing
- Cosign container image signing (supply chain trust)
- OWASP ZAP baseline DAST scanning
- Security waivers system (`.security/waivers.yml`) with justification and expiry
- Branch protection recommendations and operational guidance
- `scripts/generate_keys.sh` for Cosign key generation

### v1.1.x — Usability & Adoption

- `fortressci init` CLI wizard: detects project type and CI platform, generates tailored configs
- Multi-CI platform templates: GitHub Actions, GitLab CI, Bitbucket, Azure, Jenkins, CircleCI
- Docker-based local runner: `fortressci/scan` all-in-one scanner image
- Unified findings dashboard: Jinja2-based HTML report with severity charts and filtering
- PR comment summary: `post_summary.js` for automated pull request feedback
- Severity threshold gating and waiver CLI: configurable failure thresholds and `fortressci-waiver.sh`
- Example repos: vulnerable Node.js, Python, and Terraform samples under `examples/`
- `fortressci doctor` health checks: local readiness validation with optional governance probe
- Script quality gates and test harness: `actionlint`, `shellcheck`, `yamllint`, `pytest`, `bats`

### v1.2.x — Advanced Security

- Runtime security monitoring: baseline Falco rules in `.security/falco-rules.yaml`
- SBOM generation: `generate-sbom.sh` producing SPDX/CycloneDX via Syft
- SLSA provenance: Level 3 build provenance via `slsa-github-generator`
- Supply chain hardening: `check-pinning.sh` enforcing SHA-pinned Actions and Docker images
- Policy-as-code framework: `.security/policy.yml` with automated enforcement
- Compliance report generation: `generate-compliance-report.py` mapping to SOC2, NIST, OWASP
- Bicep IaC support: dedicated Bicep SARIF output and aggregation

### v2.x — Platform & Intelligence

- Security Operations Dashboard (`dashboard/index.html`)
- Fortress Score badge (`generate-badge.py`, A+ to F grading)
- Attack surface map (`build-attack-graph.py`)
- AI-powered triage (`ai-triage.py`)
- Auto-remediation PRs (`auto-fix.sh`)
- MCP server for AI assistants (`integrations/mcp-server/`)
- Online playground (`playground/index.html`)
- DevSecOps adoption roadmap engine (`generate-adoption-roadmap.py`)
- Azure DevOps end-to-end integration
- Cross-repo dependency graph (`cross-repo-analyzer.py`)
- Waiver governance: FCI-POL-005/006 enforcement, expired/expiring waiver visibility
- Diff-aware PR scanning: skip irrelevant scanners based on changed file types
- Expanded deterministic test suite: fixture-driven pytest and bats tests

### v2.5.x — Script Hardening & Developer Experience (2026-05)

- Python linting via `ruff` + `ruff-format` pre-commit hooks (`ruff.toml` config; pyflakes + bugbear rules)
- `--help` / `-h` flag support across CLI scripts (`auto-fix.sh`, `fortressci-init.sh`, `generate_keys.sh`)
- `set -euo pipefail` and explicit unknown-arg handling across previously-unsafe shell scripts
- Cosign key generator: overwrite protection, post-generation output verification, `.gitignore` reminder
- MCP server hardening: try/except around all file I/O, structured logging, env-var overrides for paths and log level
- Refreshed default AI model (`claude-sonnet-4-5`) with env-var override (`FORTRESSCI_AI_MODEL`)
- Bats test coverage extended from 16 to 27 tests (`auto-fix.bats`, `fortressci-init.bats`, `generate-keys.bats`)

---

## Future Vision (2027+)

- **FortressCI Cloud**: Hosted SaaS with org management, centralised dashboards, SSO, and managed scan infrastructure
- **Runtime protection agent**: Lightweight sidecar enforcing security policies at runtime based on CI-time analysis
- **Cross-repo dependency graph UI**: Interactive org-wide graph experience extending the current JSON analyzer
- **Security debt tracking**: Treat findings like tech debt with remediation cost estimation and velocity tracking
- **Regulatory auto-mapping**: Automatically track evolving frameworks (NIST revisions, EU CRA, PCI DSS v4)
- **Zero-trust CI pipeline**: Isolated, attested environments with cryptographic verification at every handoff
- **VS Code extension**: Sidebar with inline diagnostics from Semgrep and Checkov
- **License compliance scanning**: Detect problematic open-source licenses
- **Gamified security training**: Interactive challenges in the dashboard

---

## How to Contribute

FortressCI is a blueprint — fork it and adapt it! See the README for getting started.

**High-impact contribution areas:**

- CI platform templates (GitLab CI, Bitbucket, Azure Pipelines, Jenkins)
- Tool integration guides and "how to fix" recipes
- Policy-as-code templates for common compliance frameworks
- Dashboard development
- Test fixtures for false positive edge cases

Report bugs or request features via [GitHub Issues](https://github.com/mackeh/FortressCI/issues).
