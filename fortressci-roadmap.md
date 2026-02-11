# FortressCI Roadmap

> Last updated: February 2026

---

## Completed Phases

### ✅ v1.0.x — Foundation (Complete)

#### Phase 1: Shift Left (Local Development)
- Pre-commit hooks via `.pre-commit-config.yaml`
- TruffleHog secrets detection (blocks commits with hardcoded credentials)
- Checkov IaC scanning locally (Terraform, CloudFormation)
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

---

## Upcoming Phases

### 🔜 v1.1.x — Usability & Adoption (Q2 2026)

#### Onboarding & Setup

- **`fortressci init` CLI tool**: Interactive setup script that detects your project type (Node, Python, Go, Java, etc.), CI platform, and IaC tooling — generates a tailored `devsecops.yml`, `.pre-commit-config.yaml`, and `.security/` directory in one command
- **Multi-CI platform support**: Workflow templates for GitLab CI, Bitbucket Pipelines, Azure Pipelines, CircleCI, and Jenkins — not just GitHub Actions
- **Docker-based local runner**: `docker run fortressci/scan .` — run the full pipeline locally in a container without installing any tools individually
- **`fortressci doctor`**: Health check command that verifies all tools are installed, secrets are configured, hooks are active, and branch protection is set correctly

#### Developer Experience

- **Unified findings dashboard**: Single HTML report aggregating results from all tools (TruffleHog, Semgrep, Snyk, Checkov, Trivy, ZAP) with severity sorting, deduplication, and waiver status — instead of checking each tool's output separately
- **PR comment summary**: GitHub Action step that posts a consolidated security summary as a PR comment — total findings by severity, new vs existing, waiver coverage — so reviewers see the security posture at a glance
- **Waiver management CLI**: `fortressci waiver add/list/expire` commands to manage false positives without manually editing YAML — includes approval workflow for team environments
- **Severity threshold gating**: Configurable thresholds in `.fortressci.yml` (e.g., "fail pipeline on critical or high, warn on medium, ignore low") so teams can adopt gradually without being overwhelmed
- **VS Code extension**: Sidebar showing current security findings, waiver status, and inline diagnostics from Semgrep and Checkov — fix issues without leaving the editor

#### Documentation

- **Step-by-step tutorials**: Walkthrough guides for each tool integration, common false positive patterns, and "how to fix" recipes for the top 20 findings
- **Architecture decision records**: Document why each tool was chosen, trade-offs considered, and alternatives evaluated
- **Example repos**: Fork-ready templates for Node.js, Python, Go, and Java projects with FortressCI pre-configured

---

### 🛡️ v1.2.x — Advanced Security (Q3 2026)

#### Expanded Scanning

- **Runtime security monitoring**: Falco integration for detecting anomalous container behaviour in staging/production — extends FortressCI beyond CI/CD into runtime
- **API security testing**: OWASP ZAP active scan mode with authenticated endpoints — test APIs for injection, broken auth, and data exposure (not just baseline passive scan)
- **License compliance scanning**: Detect problematic open-source licenses (GPL in proprietary codebases, AGPL in SaaS) using `licensee` or `scancode-toolkit`
- **Malware detection**: ClamAV scan on build artifacts and container images before signing — catch trojanised dependencies and compromised base images
- **SBOM generation**: Produce Software Bill of Materials (SPDX/CycloneDX) at build time, tied to Cosign-signed images — increasingly required for compliance (US Executive Order, EU CRA)

#### Supply Chain Hardening

- **SLSA provenance**: Generate SLSA Level 3 build provenance attestations alongside Cosign signatures — prove not just who built it, but how
- **Dependency pinning enforcer**: Check that all GitHub Actions use SHA pins (not tags), all Docker base images use digests (not tags), and all package versions are locked
- **Vulnerability SLA tracking**: Track time-to-remediation per finding severity — flag overdue vulnerabilities and escalate automatically
- **Third-party action vetting**: Automated review of GitHub Actions used in workflows — check for known compromises, maintenance status, and permission requirements

#### Policy & Compliance

- **Policy-as-code framework**: Define organisational security policies in OPA/Rego or YAML — enforce rules like "no container runs as root", "all images must be signed", "no critical CVEs in production dependencies"
- **Compliance report generation**: One-command PDF/HTML reports mapping FortressCI findings to SOC 2, ISO 27001, NIST 800-53, and CIS Benchmarks controls
- **Audit log**: Immutable, timestamped record of every scan, waiver, and policy decision — exportable for auditors
- **Multi-environment policies**: Different policy strictness for dev, staging, and production branches

---

### ✨ v2.0.x — Woo Factor & Platform (Q4 2026)

#### Dashboard & Visualisation

- **Security Operations Dashboard**: Web-based real-time dashboard showing security posture across all repos — findings heatmap, trend lines, tool coverage, and waiver burn-down charts
- **"Fortress Score" badge**: Embeddable shields.io-style badge for READMEs (`FortressCI: A+ | 0 Critical | 2 Waivers`) — instant trust signal for open-source projects and internal teams
- **Attack surface map**: Visual graph showing how vulnerabilities chain together — *"This unpatched npm dependency (Snyk) is used in an API endpoint (Semgrep) that's exposed without auth (ZAP) running in a container with root privileges (Trivy)"* — turns isolated findings into threat narratives
- **Scan timeline replay**: Animated visualisation showing how security posture evolved over time — watch findings appear, get fixed, and waivers expire in fast-forward

#### Intelligence & Automation

- **AI-powered triage**: LLM-based analysis of each finding that explains the risk in plain English, estimates exploitability, and suggests the fastest remediation — *"This SQL injection in `api/users.py:42` is reachable from an unauthenticated endpoint. Fix: use parameterised queries. Estimated effort: 15 minutes."*
- **Auto-remediation PRs**: When a finding has a known fix (dependency upgrade, config change), automatically open a PR with the fix, test it, and tag reviewers — close the loop without manual intervention
- **Smart waiver recommendations**: Analyse recurring false positives across the org and suggest permanent exclusion rules — reduce waiver fatigue
- **Predictive vulnerability alerts**: Monitor upstream advisories and alert when a dependency you use is likely to be affected by an emerging CVE — before it's formally published

#### Ecosystem & Integration

- **GitHub Marketplace App**: One-click install that adds FortressCI to any repo — no workflow file editing needed
- **MCP (Model Context Protocol) server**: Expose FortressCI as an MCP tool so AI coding assistants can query security posture, check findings, and trigger scans conversationally
- **Slack/Teams bot**: Interactive bot that notifies on new findings, accepts waiver requests via emoji reactions, and posts daily security digests
- **Terraform module**: IaC module that provisions FortressCI infrastructure (dashboard, policy engine, scan runners) alongside your cloud resources
- **Plugin architecture**: Bring-your-own-scanner support — wrap any security tool in a simple adapter interface and plug it into the FortressCI pipeline alongside the built-in tools

#### Developer Advocacy

- **Online playground**: Browser-based demo where visitors paste a Dockerfile, Terraform file, or code snippet and instantly see FortressCI findings — zero install, shareable results URL
- **"Security Score" for open-source**: Run FortressCI against popular GitHub repos and publish results (responsibly, with private disclosure) — *"Top 10 most-scanned repos this week"* — drives awareness and adoption
- **Gamified security training**: Interactive challenges built into the dashboard — *"Fix 5 Semgrep findings this sprint to earn the 'Code Guardian' badge"* — makes security engagement fun for developers

---

## Long-Term Vision (2027+)

- **FortressCI Cloud**: Hosted SaaS with org management, centralised dashboards, SSO, and managed scan infrastructure — no self-hosting required
- **Runtime protection agent**: Lightweight sidecar that enforces security policies at runtime (network egress, file access, process execution) based on CI-time analysis — extends "shift left" to "shift everywhere"
- **Cross-repo dependency graph**: Visualise how vulnerabilities in shared libraries propagate across all repos in an organisation — *"Upgrading `lodash` in `shared-utils` fixes findings in 14 downstream repos"*
- **Security debt tracking**: Treat security findings like tech debt — estimate remediation cost, track velocity, forecast when the backlog will be clear at current fix rate
- **Regulatory auto-mapping**: Automatically map findings and controls to evolving regulatory frameworks as they change (new NIST revisions, EU CRA updates, PCI DSS v4)
- **Zero-trust CI pipeline**: Every step in the pipeline runs in an isolated, attested environment with minimal permissions — no shared runners, no persistent state, cryptographic verification at every handoff

---

## How to Contribute

FortressCI is a blueprint — fork it and adapt it! See the README for getting started.

**High-impact contribution areas:**

- 🔌 CI platform templates (GitLab CI, Bitbucket, Azure Pipelines, Jenkins)
- 📝 Tool integration guides and "how to fix" recipes
- 🛡️ Policy-as-code templates for common compliance frameworks
- 🐳 Dockerfile and Terraform examples for testing
- 📊 Dashboard development
- 🧪 Test fixtures for false positive edge cases

Report bugs or request features via [GitHub Issues](https://github.com/mackeh/FortressCI/issues).
