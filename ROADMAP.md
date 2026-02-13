# FortressCI — Detailed Build Process

> Implementation guide for Roadmap v1.1.x–v2.0.x and Long-Term Vision

---

## Table of Contents

1. [v1.1.x: Usability & Adoption](#v11x-usability--adoption)
2. [v1.2.x: Advanced Security](#v12x-advanced-security)
3. [v2.0.x: Woo Factor & Platform](#v20x-woo-factor--platform)
4. [Long-Term Vision](#long-term-vision)
5. [Infrastructure & DevOps Requirements](#infrastructure--devops-requirements)
6. [Dependency Map](#dependency-map)

---

## v1.1.x: Usability & Adoption

### 1.1.1 — `fortressci init` CLI Tool [COMPLETED ✅]

**Goal:** Interactive setup that generates tailored configs.

**Achievements:**
- Implemented `scripts/fortressci-init.sh` setup wizard.
- Automated detection of project types (Node, Python, Go, Java).
- Generated tailored CI/CD workflows and security configurations.

### 1.1.2 — Multi-CI Platform Templates [COMPLETED ✅]

**Goal:** Workflow templates beyond GitHub Actions.

**Achievements:**
- Created production-ready templates for GitHub, GitLab, Bitbucket, Azure, Jenkins, and CircleCI.
- Standardised scan stages across all platforms.

### 1.1.3 — Docker-Based Local Runner [COMPLETED ✅]

**Goal:** Run full pipeline locally in a single container.

**Achievements:**
- Built the `fortressci/scan` all-in-one scanner image.
- Orchestrated 7 security stages in `scripts/run-all.sh`.

### 1.1.4 — Unified Findings Dashboard [COMPLETED ✅]

**Goal:** Single HTML report aggregating all tool results.

**Achievements:**
- Implemented `scripts/generate-report.py` with Jinja2 templating.
- Created interactive HTML reports with severity charts and filters.

### 1.1.5 — PR Comment Summary [COMPLETED ✅]

**Goal:** Consolidated security summary on PRs.

**Achievements:**
- Added `post_summary.js` script for automated PR feedback.
- Integrated high-level security status into the developer workflow.

### 1.1.6 — Severity Threshold Gating & Waiver CLI [COMPLETED ✅]

**Goal:** Configurable failure thresholds and easier waiver management.

**Achievements:**
- Implemented `scripts/check-thresholds.sh` for pipeline gating.
- Created `scripts/fortressci-waiver.sh` for documented security exceptions.

---

### 1.1.7 — Example Repos & Documentation [COMPLETED ✅]

**Goal:** Fork-ready templates for common project types.

**Achievements:**
- Created `examples/` directory with vulnerable sample applications.
- `examples/nodejs-app`: Node.js/Express with SQLi and hardcoded secrets.
- `examples/python-app`: Flask with SQLi, SSTI, and insecure debug mode.
- `examples/terraform`: IaC with public S3 buckets and open security groups.
- Verified that FortressCI scanners correctly identify these vulnerabilities.

---

### 1.1.8 — `fortressci doctor` Health Checks [COMPLETED ✅]

**Goal:** Fast environment and governance readiness checks before CI enforcement.

**Achievements:**
- Implemented `scripts/fortressci-doctor.sh` for local readiness validation.
- Added checks for config presence, hooks, required tooling, and CI file detection.
- Added optional GitHub branch protection probe (`--check-remote`) for governance posture.
- Integrated doctor guidance into init flow and project documentation.

---

## v1.2.x: Advanced Security

### 1.2.1 — Runtime Security (Falco) [COMPLETED ✅]

**Goal:** Detect anomalous container behaviour in staging/production.

**Achievements:**
- Defined baseline custom Falco rules in `.security/falco-rules.yaml`.
- Provided patterns for detecting unexpected network connections and sensitive file access.
- Integrated runtime security policy definitions into the project blueprint.

---

### 1.2.2 — SBOM Generation [COMPLETED ✅]

**Goal:** Produce Software Bill of Materials at build time.

**Achievements:**
- Added `syft` to the Docker scanner image.
- Implemented `scripts/generate-sbom.sh` for source and container SBOMs.
- Integrated SBOM generation into `run-all.sh` and CI workflows.
- Uploaded SBOMs as CI artifacts (SPDX/CycloneDX).

### 1.2.3 — SLSA Provenance [COMPLETED ✅]

**Goal:** Generate SLSA Level 3 build provenance.

**Achievements:**
- Integrated `slsa-github-generator` into the DevSecOps pipeline.
- Automated generation of non-forgeable provenance for compliance artifacts.
- Enabled verification of build integrity via SLSA attestations.

---

### 1.2.4 — Supply Chain Hardening [COMPLETED ✅]

**Goal:** Enforce pinning and vet third-party actions.

**Achievements:**
- Added `scripts/check-pinning.sh` to verify GitHub Actions and Docker base image pinning.
- Integrated as a pre-commit hook in `.pre-commit-config.yaml`.
- Enforced full SHA pinning across all CI workflows.

### 1.2.5 — Policy-as-Code Framework [COMPLETED ✅]

**Goal:** Enforce organisational security rules.

**Achievements:**
- Defined core policies in `.security/policy.yml`.
- Implemented policy enforcement logic (used in scanning and gating).
- Automated policy validation in the DevSecOps pipeline.

---

### 1.2.6 — Compliance Report Generation [COMPLETED ✅]

**Goal:** Map findings to compliance frameworks.

**Achievements:**
- Defined framework mappings in `.security/compliance-mappings.yml` (SOC2, NIST, OWASP).
- Implemented `scripts/generate-compliance-report.py` to automate mapping.
- Integrated compliance reporting into both local scans and CI/CD pipelines.

---

## v2.0.x: Woo Factor & Platform

### 2.0.1 — Security Operations Dashboard [COMPLETED ✅]

**Goal:** Web-based real-time security posture dashboard.

**Achievements:**
- Implemented `dashboard/index.html` using Tailwind CSS and Chart.js.
- Provided high-level visualisations of severity distribution and tool findings.
- Included compliance framework status and security grade reporting.

---

### 2.0.2 — Fortress Score Badge [COMPLETED ✅]

**Goal:** Embeddable trust signal.

**Achievements:**
- Implemented `scripts/generate-badge.py` to calculate security grades (A+ to F).
- Integrated badge generation into local scans and CI pipelines.
- Produced shields.io compatible badge URLs based on real-time scan results.

---

### 2.0.3 — Attack Surface Map [COMPLETED ✅]

**Goal:** Visualise how vulnerabilities chain together.

**Achievements:**
- Implemented `scripts/build-attack-graph.py` to generate relationship graphs.
- Visualised the path from external entry points to sensitive assets.
- Integrated attack surface analysis into CI/CD and local scan workflows.

---

### 2.0.4 — AI-Powered Triage [COMPLETED ✅]

**Goal:** LLM-based explanation and prioritisation of findings.

**Achievements:**
- Implemented `scripts/ai-triage.py` for automated findings analysis.
- Integrated AI orchestration into local scans and CI/CD workflows.
- Added configuration options for AI providers and severity filtering.

---

### 2.0.5 — Auto-Remediation PRs [COMPLETED ✅]

**Goal:** Automatically fix findings and open PRs.

**Achievements:**
- Implemented `scripts/auto-fix.sh` to apply Snyk and Checkov fixes.
- Integrated automated PR creation into the CI pipeline for scheduled runs.
- Enabled self-healing capabilities for dependency and IaC vulnerabilities.

---

### 2.0.6 — MCP Server & Integrations [COMPLETED ✅]

**Goal:** AI assistant and chat tool integrations.

**Achievements:**
- Implemented a FastMCP-based server in `integrations/mcp-server/`.
- Provided tools for AI assistants to query scan summaries, compliance status, and waivers.
- Enabled seamless integration between FortressCI data and AI-powered development workflows.

---

### 2.0.7 — Online Playground [COMPLETED ✅]

**Goal:** Browser-based demo for instant FortressCI experience.

**Achievements:**
- Implemented `playground/index.html` as an interactive code-to-findings simulator.
- Provided pre-loaded samples for Docker, Terraform, and Python.
- Demonstrated real-time vulnerability detection directly in the browser.

---

## Long-Term Vision

### FortressCI Cloud (SaaS)
- Multi-tenant API with org management
- Centralised dashboard, SSO, RBAC
- Managed scanning infrastructure
- **Effort:** 3–6 months

### Cross-Repo Dependency Graph [COMPLETED ✅]

**Goal:** Visualise how vulnerabilities propagate across shared libraries.

**Achievements:**
- Implemented `scripts/cross-repo-analyzer.py` to aggregate SBOM data across multiple projects.
- Enabled identification of shared dependencies and their usage across the organisation.
- Automated generation of cross-repo dependency reports in JSON format.
- Added optional Snyk correlation from sibling `sca.json` files to highlight shared vulnerable dependencies.
- Added prioritized `top_shared_risk_hotspots` output to support CISO-level remediation planning.

### Zero-Trust CI Pipeline
- Every step runs in isolated, attested environment
- Cryptographic verification at every handoff
- No shared runners, no persistent state
- **Effort:** 8–12 weeks (significant architecture)

---

## Infrastructure & DevOps Requirements

| Component | Technology | Purpose |
|-----------|-----------|---------|
| CI/CD | GitHub Actions (primary) | Pipeline execution |
| Container registry | ghcr.io, Docker Hub | All-in-one scanner image |
| Scanning tools | TruffleHog, Semgrep, Snyk, Checkov, Trivy, ZAP | Core scanning |
| Dashboard | Next.js, Tailwind, Recharts | Web UI |
| Database | SQLite / PostgreSQL | Scan results storage |
| LLM API | Anthropic / OpenAI | AI triage |
| Signing | Cosign, SLSA | Supply chain trust |
| MCP | Python MCP SDK | AI assistant integration |

---

## Dependency Map

```
1.1.1 (Init wizard) ──→ 1.1.2 (Templates used by wizard)
                    ──→ 1.1.6 (Thresholds configured in init)
                    ──→ 1.1.8 (Doctor validates generated setup)

1.1.3 (Docker runner) ──→ 2.0.7 (Playground reuses runner image)
1.1.4 (Unified report) ──→ 2.0.1 (Dashboard extends report data)

1.2.2 (SBOM) ──→ 1.2.3 (SLSA attests SBOM)
1.2.4 (Pinning) ──→ 1.2.5 (Policy enforces pinning rules)

2.0.1 (Dashboard) ──→ 2.0.2 (Badge served from dashboard)
                  ──→ 2.0.3 (Attack map is a dashboard view)

2.0.4 (AI triage) — independent, needs API key
2.0.5 (Auto-remediation) — independent
2.0.6 (MCP/Slack/GitHub App) — independent per integration
```
