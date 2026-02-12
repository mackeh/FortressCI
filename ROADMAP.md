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

### 1.1.1 — `fortressci init` CLI Tool

**Goal:** Interactive setup that generates tailored configs.

**Steps:**

1. **Create CLI tool** (Python or Shell — keeping it accessible for DevSecOps audience):
   ```bash
   # scripts/fortressci-init.sh
   #!/bin/bash
   echo "🏰 FortressCI Setup Wizard"
   echo ""
   
   # Detect project type
   if [ -f "package.json" ]; then echo "✓ Detected: Node.js"; LANG="node"; fi
   if [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then echo "✓ Detected: Python"; LANG="python"; fi
   if [ -f "go.mod" ]; then echo "✓ Detected: Go"; LANG="go"; fi
   if [ -f "pom.xml" ] || [ -f "build.gradle" ]; then echo "✓ Detected: Java"; LANG="java"; fi
   
   # Detect CI platform
   if [ -d ".github/workflows" ]; then CI="github-actions"; fi
   if [ -f ".gitlab-ci.yml" ]; then CI="gitlab-ci"; fi
   
   # Prompt for missing info
   read -p "? Snyk token configured? (y/n): " HAS_SNYK
   read -p "? Enable container scanning? (y/n): " HAS_DOCKER
   read -p "? Enable IaC scanning? (y/n): " HAS_IAC
   
   # Generate files
   cp templates/${CI}/devsecops.yml .github/workflows/devsecops.yml
   cp templates/pre-commit-config.yaml .pre-commit-config.yaml
   mkdir -p .security && cp templates/waivers.yml .security/waivers.yml
   
   echo "✅ Generated .github/workflows/devsecops.yml"
   echo "✅ Generated .pre-commit-config.yaml"
   echo "✅ Generated .security/waivers.yml"
   echo ""
   echo "Next: Run 'pre-commit install' and add SNYK_TOKEN to GitHub Secrets"
   ```

2. **Template variants** for each CI platform:
   - `templates/github-actions/devsecops.yml`
   - `templates/gitlab-ci/devsecops.yml`
   - `templates/bitbucket/devsecops.yml`
   - `templates/azure/devsecops.yml`
   - `templates/jenkins/Jenkinsfile`

3. **Language-specific customisation:**
   - Node.js → Snyk scans `package-lock.json`
   - Python → Snyk + Bandit + Safety
   - Go → Snyk + govulncheck
   - Java → Snyk + SpotBugs

**Estimated effort:** 2 weeks
**Key files:** `scripts/fortressci-init.sh`, `templates/`

---

### 1.1.2 — Multi-CI Platform Templates

**Goal:** Workflow templates beyond GitHub Actions.

**Steps:**

1. **GitLab CI** (`.gitlab-ci.yml`):
   ```yaml
   stages: [secret-scan, sast, sca, iac-scan, container-scan, dast]
   
   secret-scan:
     stage: secret-scan
     image: trufflesecurity/trufflehog:latest
     script:
       - trufflehog git file://. --since-commit HEAD~1 --fail
   
   sast:
     stage: sast
     image: returntocorp/semgrep
     script:
       - semgrep --config auto --sarif -o semgrep.sarif .
     artifacts:
       reports:
         sast: semgrep.sarif
   
   # ... sca, iac, container, dast stages
   ```

2. **Bitbucket Pipelines** (`bitbucket-pipelines.yml`):
   ```yaml
   pipelines:
     default:
       - parallel:
           - step:
               name: Secret Scan
               script:
                 - pipe: trufflesecurity/trufflehog-pipe:latest
           - step:
               name: SAST
               script:
                 - pip install semgrep
                 - semgrep --config auto .
   ```

3. **Azure Pipelines** (`azure-pipelines.yml`)
4. **Jenkins** (`Jenkinsfile`) — declarative pipeline with parallel stages
5. **CircleCI** (`.circleci/config.yml`) — with orbs for Snyk and Trivy

6. **Each template includes:**
   - All 5 scan stages (secrets, SAST, SCA, IaC, containers)
   - SARIF output where supported
   - Artifact upload
   - Configurable failure thresholds

**Estimated effort:** 3–4 weeks
**Key files:** `templates/gitlab-ci/`, `templates/bitbucket/`, `templates/azure/`, `templates/jenkins/`, `templates/circleci/`

---

### 1.1.3 — Docker-Based Local Runner

**Goal:** Run full pipeline locally in a single container.

**Steps:**

1. **Build all-in-one Docker image:**
   ```dockerfile
   FROM ubuntu:22.04
   
   # Install all scanning tools
   RUN apt-get update && apt-get install -y python3 python3-pip nodejs npm curl git
   
   # TruffleHog
   RUN curl -sSfL https://raw.githubusercontent.com/trufflesecurity/trufflehog/main/scripts/install.sh | sh
   
   # Semgrep
   RUN pip3 install semgrep
   
   # Snyk
   RUN npm install -g snyk
   
   # Checkov
   RUN pip3 install checkov
   
   # Trivy
   RUN curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh
   
   # OWASP ZAP (headless)
   RUN pip3 install zaproxy
   
   # Cosign
   RUN curl -sSfL https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64 -o /usr/local/bin/cosign && chmod +x /usr/local/bin/cosign
   
   COPY scripts/run-all.sh /usr/local/bin/fortressci-scan
   ENTRYPOINT ["fortressci-scan"]
   ```

2. **Orchestration script** (`scripts/run-all.sh`):
   ```bash
   #!/bin/bash
   set -e
   WORKSPACE=${1:-.}
   RESULTS_DIR="/results"
   mkdir -p $RESULTS_DIR
   
   echo "🏰 FortressCI Local Scan"
   echo "========================"
   
   echo "🔐 [1/5] Secret scanning..."
   trufflehog filesystem $WORKSPACE --json > $RESULTS_DIR/secrets.json 2>&1 || true
   
   echo "🔍 [2/5] SAST (Semgrep)..."
   semgrep --config auto --sarif -o $RESULTS_DIR/sast.sarif $WORKSPACE || true
   
   echo "📦 [3/5] SCA (Snyk)..."
   snyk test --json > $RESULTS_DIR/sca.json $WORKSPACE || true
   
   echo "🏗️ [4/5] IaC (Checkov)..."
   checkov -d $WORKSPACE --output-file-path $RESULTS_DIR -o sarif || true
   
   echo "🐳 [5/5] Container scan (Trivy)..."
   if [ -f "$WORKSPACE/Dockerfile" ]; then
       trivy fs --scanners vuln --format sarif -o $RESULTS_DIR/container.sarif $WORKSPACE
   fi
   
   echo ""
   echo "✅ Scan complete. Results in $RESULTS_DIR/"
   
   # Generate unified summary
   python3 /usr/local/bin/summarize.py $RESULTS_DIR
   ```

3. **Usage:**
   ```bash
   docker run --rm -v $(pwd):/workspace -v $(pwd)/results:/results fortressci/scan /workspace
   ```

4. **Publish** to Docker Hub and ghcr.io

**Estimated effort:** 2–3 weeks
**Key files:** `Dockerfile`, `scripts/run-all.sh`, `scripts/summarize.py`

---

### 1.1.4 — Unified Findings Dashboard

**Goal:** Single HTML report aggregating all tool results.

**Steps:**

1. **Create report generator** (`scripts/generate-report.py`):
   ```python
   import json, sys
   from pathlib import Path
   from jinja2 import Template
   
   def parse_sarif(path):
       with open(path) as f:
           data = json.load(f)
       findings = []
       for run in data.get("runs", []):
           tool = run["tool"]["driver"]["name"]
           for result in run.get("results", []):
               findings.append({
                   "tool": tool,
                   "severity": result.get("level", "warning"),
                   "message": result["message"]["text"],
                   "file": result["locations"][0]["physicalLocation"]["artifactLocation"]["uri"],
                   "line": result["locations"][0]["physicalLocation"]["region"]["startLine"],
               })
       return findings
   
   def generate_html(findings, output_path):
       template = Template(open("templates/report.html.j2").read())
       html = template.render(
           findings=findings,
           total=len(findings),
           critical=len([f for f in findings if f["severity"] == "error"]),
           high=len([f for f in findings if f["severity"] == "warning"]),
       )
       with open(output_path, "w") as f:
           f.write(html)
   ```

2. **HTML template** with:
   - Summary cards (total, by severity, by tool)
   - Filterable/sortable findings table
   - Waiver status column (cross-referenced with `.security/waivers.yml`)
   - Dark mode support
   - Tool breakdown pie chart
   - Print-friendly layout

3. **Integration:** Auto-generated at end of CI pipeline, uploaded as artifact

**Estimated effort:** 2–3 weeks
**Key files:** `scripts/generate-report.py`, `templates/report.html.j2`

---

### 1.1.5 — PR Comment Summary

**Goal:** Consolidated security summary on PRs.

**Steps:**

1. **GitHub Action step** added to `devsecops.yml`:
   ```yaml
   - name: Post Security Summary
     if: github.event_name == 'pull_request'
     uses: actions/github-script@v7
     with:
       script: |
         const fs = require('fs');
         const findings = JSON.parse(fs.readFileSync('results/summary.json', 'utf8'));
         
         const body = `## 🏰 FortressCI Security Summary
         
         | Tool | Critical | High | Medium | Low |
         |------|----------|------|--------|-----|
         | TruffleHog | ${findings.trufflehog.critical} | ${findings.trufflehog.high} | - | - |
         | Semgrep | ${findings.semgrep.critical} | ${findings.semgrep.high} | ${findings.semgrep.medium} | ${findings.semgrep.low} |
         | Snyk | ${findings.snyk.critical} | ${findings.snyk.high} | ${findings.snyk.medium} | ${findings.snyk.low} |
         | Checkov | ${findings.checkov.critical} | ${findings.checkov.high} | ${findings.checkov.medium} | - |
         | Trivy | ${findings.trivy.critical} | ${findings.trivy.high} | ${findings.trivy.medium} | ${findings.trivy.low} |
         
         **New findings:** ${findings.new_count} | **Resolved:** ${findings.resolved_count} | **Waivers:** ${findings.waiver_count}
         `;
         
         github.rest.issues.createComment({
           ...context.repo,
           issue_number: context.payload.pull_request.number,
           body: body
         });
   ```

2. **Summary generation** — compare current scan against baseline (main branch last scan)

**Estimated effort:** 1–2 weeks
**Key files:** `.github/workflows/devsecops.yml`, `scripts/generate-summary.py`

---

### 1.1.6 — Severity Threshold Gating & Waiver CLI

**Goal:** Configurable failure thresholds and easier waiver management.

**Steps:**

1. **Config file** (`.fortressci.yml`):
   ```yaml
   thresholds:
     fail_on: critical  # critical | high | medium | low | none
     warn_on: high
     
   waivers:
     require_approval: true
     max_expiry_days: 90
   ```

2. **Gating logic** in CI:
   ```bash
   # scripts/check-thresholds.sh
   CRITICAL=$(jq '.critical' results/summary.json)
   HIGH=$(jq '.high' results/summary.json)
   FAIL_ON=$(yq '.thresholds.fail_on' .fortressci.yml)
   
   case $FAIL_ON in
     critical) [ "$CRITICAL" -gt 0 ] && exit 1 ;;
     high) [ "$CRITICAL" -gt 0 ] || [ "$HIGH" -gt 0 ] && exit 1 ;;
     *) ;;
   esac
   ```

3. **Waiver CLI** (`scripts/fortressci-waiver.sh`):
   ```bash
   # Add a waiver
   fortressci waiver add \
     --finding-id "semgrep:python.flask.security.open-redirect" \
     --reason "False positive: URL is validated upstream" \
     --expires "2026-06-01" \
     --author "mackeh"
   
   # List active waivers
   fortressci waiver list
   
   # Expire old waivers
   fortressci waiver expire --before today
   ```

**Estimated effort:** 1–2 weeks
**Key files:** `.fortressci.yml`, `scripts/fortressci-waiver.sh`, `scripts/check-thresholds.sh`

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

### Cross-Repo Dependency Graph [IN PROGRESS 🏗️]

**Goal:** Visualise how vulnerabilities propagate across shared libraries.

**Achievements:**
- Implemented `scripts/cross-repo-analyzer.py` to aggregate SBOM data across multiple projects.
- Enabled identification of shared dependencies and their usage across the organisation.
- Automated generation of cross-repo dependency reports in JSON format.

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
