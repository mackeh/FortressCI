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

### 1.1.7 — Example Repos & Documentation

**Goal:** Fork-ready templates for common project types.

**Steps:**

1. **Create example repos** (or directories in `examples/`):
   - `examples/nodejs-app/` — Express.js with FortressCI pre-configured
   - `examples/python-app/` — Flask with FortressCI pre-configured
   - `examples/go-app/` — Go API with FortressCI pre-configured
   - `examples/java-app/` — Spring Boot with FortressCI pre-configured

2. **Each example includes:**
   - Application code with intentional test vulnerabilities
   - Pre-configured `.github/workflows/devsecops.yml`
   - `.pre-commit-config.yaml`
   - `.security/waivers.yml` with sample waivers
   - `.fortressci.yml` with thresholds
   - README with walkthrough

3. **Tutorials** in `docs/`:
   - "Getting Started in 10 Minutes"
   - "Handling False Positives with Waivers"
   - "Customising Scan Thresholds"
   - "Adding FortressCI to an Existing Project"

**Estimated effort:** 2–3 weeks
**Key files:** `examples/`, `docs/tutorials/`

---

## v1.2.x: Advanced Security

### 1.2.1 — Runtime Security (Falco)

**Goal:** Detect anomalous container behaviour in staging/production.

**Steps:**

1. **Add Falco rule file** (`.security/falco-rules.yaml`):
   ```yaml
   - rule: Unexpected outbound connection
     desc: Detect unexpected outbound network connections from application containers
     condition: >
       evt.type=connect and fd.typechar=4 and
       not fd.sip in (allowed_ips) and
       container.name startswith "app-"
     output: "Unexpected outbound connection (container=%container.name ip=%fd.sip port=%fd.sport)"
     priority: WARNING
   
   - rule: Sensitive file access
     desc: Detect reads of sensitive files
     condition: >
       evt.type in (open, openat) and
       fd.name in (/etc/shadow, /etc/passwd, /proc/self/environ)
     output: "Sensitive file access (file=%fd.name container=%container.name)"
     priority: CRITICAL
   ```

2. **Deployment guide:**
   - Helm chart for Falco in Kubernetes
   - Docker Compose sidecar for non-k8s environments
   - Configuration to load custom rules

3. **Integration with CI:**
   - `devsecops.yml` step that validates Falco rules syntax
   - Optional: deploy Falco rules as part of CD pipeline

4. **Alert routing:**
   - Falco → Falcosidekick → Slack/PagerDuty/webhook

**Estimated effort:** 2–3 weeks
**Key files:** `.security/falco-rules.yaml`, `deploy/helm/falco-values.yaml`, `docs/runtime-security.md`

---

### 1.2.2 — SBOM Generation [COMPLETED ✅]

**Goal:** Produce Software Bill of Materials at build time.

**Achievements:**
- Added `syft` to the Docker scanner image.
- Implemented `scripts/generate-sbom.sh` for source and container SBOMs.
- Integrated SBOM generation into `run-all.sh` and CI workflows.
- Uploaded SBOMs as CI artifacts (SPDX/CycloneDX).

### 1.2.3 — SLSA Provenance

**Goal:** Generate SLSA Level 3 build provenance.

**Steps:**

1. **Use `slsa-github-generator`:**
   ```yaml
   provenance:
     needs: build
     uses: slsa-framework/slsa-github-generator/.github/workflows/generator_container_slsa3.yml@v1.9.0
     with:
       image: ${{ needs.build.outputs.image }}
       digest: ${{ needs.build.outputs.digest }}
   ```

2. **Verify provenance:**
   ```bash
   slsa-verifier verify-image ${IMAGE_NAME}@${DIGEST} \
     --source-uri github.com/mackeh/FortressCI \
     --source-tag v1.2.0
   ```

3. **Document** the provenance chain: source → build → sign → attest → verify

**Estimated effort:** 1 week
**Key files:** `.github/workflows/devsecops.yml`

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

### 1.2.6 — Compliance Report Generation

**Goal:** Map findings to compliance frameworks.

**Steps:**

1. **Create mapping file** (`.security/compliance-mappings.yml`):
   ```yaml
   mappings:
     - tool: semgrep
       rule_prefix: "python.flask.security"
       frameworks:
         - { framework: "SOC2", control: "CC6.1" }
         - { framework: "NIST-800-53", control: "SI-10" }
         - { framework: "OWASP", category: "A03:2021-Injection" }
     
     - tool: trivy
       category: "os-vulnerability"
       frameworks:
         - { framework: "SOC2", control: "CC7.1" }
         - { framework: "CIS", benchmark: "4.4" }
   ```

2. **Report generator** (`scripts/generate-compliance-report.py`):
   - Load scan results + compliance mappings
   - Generate HTML/PDF report with:
     - Framework coverage matrix (control → status)
     - Findings mapped to specific controls
     - Gap analysis (controls without coverage)
     - Remediation priority list

3. **Template:** Professional-looking report suitable for auditors

**Estimated effort:** 2–3 weeks
**Key files:** `.security/compliance-mappings.yml`, `scripts/generate-compliance-report.py`, `templates/compliance-report.html.j2`

---

## v2.0.x: Woo Factor & Platform

### 2.0.1 — Security Operations Dashboard

**Goal:** Web-based real-time security posture dashboard.

**Steps:**

1. **Tech stack:**
   - Frontend: Next.js + Tailwind CSS + shadcn/ui
   - Backend: Next.js API routes
   - Database: SQLite (local) or PostgreSQL (team)
   - Charts: Recharts

2. **Data ingestion:**
   - CI pipeline uploads scan results to API endpoint after each run:
     ```bash
     curl -X POST https://dashboard.example.com/api/scans \
       -H "Authorization: Bearer $TOKEN" \
       -d @results/summary.json
     ```
   - Webhook receiver for CI completion events

3. **Dashboard views:**
   - **Overview:** Total findings by severity (trend chart), tool coverage, repos scanned
   - **Findings:** Filterable table with tool, severity, file, waiver status
   - **Trends:** Line charts showing findings over time, mean-time-to-remediate
   - **Compliance:** Framework coverage matrix
   - **Waivers:** Active waivers with expiry countdown

4. **Real-time updates** via SWR polling (30-second interval)

**Estimated effort:** 4–6 weeks
**Key files:** `dashboard/`, `dashboard/src/app/`, `dashboard/src/components/`

---

### 2.0.2 — Fortress Score Badge

**Goal:** Embeddable trust signal.

**Steps:**

1. **Scoring algorithm:**
   ```python
   def fortress_score(scan_results):
       score = 100
       score -= scan_results['critical'] * 25
       score -= scan_results['high'] * 10
       score -= scan_results['medium'] * 3
       score -= scan_results['low'] * 1
       
       # Bonus for good practices
       if scan_results['cosign_signed']: score += 5
       if scan_results['sbom_generated']: score += 5
       if scan_results['slsa_provenance']: score += 5
       if scan_results['all_actions_pinned']: score += 5
       
       score = max(0, min(100, score))
       grade = next(g for threshold, g in [
           (95, 'A+'), (85, 'A'), (70, 'B'), (50, 'C'), (25, 'D'), (0, 'F')
       ] if score >= threshold)
       
       return score, grade
   ```

2. **Badge endpoint:** `GET /api/badge/{repo}` → shields.io redirect
3. **Static badge** for repos without dashboard — generate markdown after scan
4. **README snippet:**
   ```markdown
   ![FortressCI](https://img.shields.io/badge/FortressCI-A%2B%20(97)-brightgreen)
   ```

**Estimated effort:** 1 week
**Key files:** `scripts/generate-badge.sh`, `dashboard/src/app/api/badge/route.ts`

---

### 2.0.3 — Attack Surface Map

**Goal:** Visualise how vulnerabilities chain together.

**Steps:**

1. **Graph construction:**
   - Nodes: findings from each tool
   - Edges: relationships (e.g., vulnerable dependency → used in endpoint → exposed without auth)
   - Data sources: cross-reference Semgrep file/line with Snyk package with Trivy image with ZAP endpoint

2. **Frontend visualisation** (D3.js force-directed graph):
   - Colour nodes by tool (Semgrep=blue, Snyk=green, Trivy=orange, ZAP=red)
   - Edge thickness by risk
   - Click node to see finding details
   - Hover to see chain narrative

3. **Chain narrative generation:**
   ```python
   def generate_narrative(chain):
       return f"This {chain.snyk.package} dependency (CVE-{chain.snyk.cve}) " \
              f"is used in {chain.semgrep.file}:{chain.semgrep.line} " \
              f"which is exposed at {chain.zap.endpoint} " \
              f"running in a container with {chain.trivy.finding}."
   ```

**Estimated effort:** 3–4 weeks
**Key files:** `dashboard/src/components/AttackSurface.tsx`, `scripts/build-attack-graph.py`

---

### 2.0.4 — AI-Powered Triage

**Goal:** LLM-based explanation and prioritisation of findings.

**Steps:**

1. **LLM integration:**
   ```python
   import anthropic
   
   def explain_finding(finding):
       client = anthropic.Anthropic()
       response = client.messages.create(
           model="claude-sonnet-4-20250514",
           max_tokens=300,
           messages=[{
               "role": "user",
               "content": f"""Explain this security finding in 2-3 sentences for a developer:
               Tool: {finding['tool']}
               Severity: {finding['severity']}
               Finding: {finding['message']}
               File: {finding['file']}:{finding['line']}
               
               Include: what the risk is, how exploitable it is, and the simplest fix."""
           }]
       )
       return response.content[0].text
   ```

2. **Batch processing** — explain all critical/high findings after scan completes
3. **Cache explanations** — don't re-explain identical findings
4. **Configuration:**
   ```yaml
   # .fortressci.yml
   ai:
     enabled: true
     provider: anthropic
     api_key_env: ANTHROPIC_API_KEY
     explain_severity: [critical, high]
   ```

**Estimated effort:** 1–2 weeks
**Key files:** `scripts/ai-triage.py`

---

### 2.0.5 — Auto-Remediation PRs

**Goal:** Automatically fix findings and open PRs.

**Steps:**

1. **Dependency upgrade PRs** (Snyk findings):
   ```bash
   snyk fix --dry-run > fix-plan.json
   # Parse fix plan, apply changes, commit, open PR
   ```

2. **Config fix PRs** (Checkov/IaC findings):
   ```bash
   checkov -d terraform/ --fix
   git diff --name-only  # See what changed
   # Commit and open PR
   ```

3. **GitHub Action for auto-PR:**
   ```yaml
   - name: Auto-remediation
     if: steps.scan.outputs.auto_fixable > 0
     run: |
       git checkout -b fix/fortressci-$(date +%Y%m%d)
       # Apply fixes
       snyk fix || true
       checkov -d terraform/ --fix || true
       git add .
       git commit -m "fix: auto-remediation from FortressCI scan"
       git push origin fix/fortressci-$(date +%Y%m%d)
       gh pr create --title "🏰 FortressCI Auto-Remediation" \
         --body "$(cat results/fix-summary.md)" \
         --reviewer $REVIEWERS
   ```

4. **Fix summary** in PR body: what was fixed, which findings resolved, before/after severity counts

**Estimated effort:** 2–3 weeks
**Key files:** `.github/workflows/auto-remediation.yml`, `scripts/auto-fix.sh`

---

### 2.0.6 — MCP Server & Integrations

**Goal:** AI assistant and chat tool integrations.

**Steps:**

1. **MCP Server** (Python):
   ```python
   from mcp import Server, Tool
   
   server = Server("fortressci")
   
   @server.tool("fortressci_scan_status")
   async def scan_status(repo: str) -> str:
       """Get latest scan results for a repository."""
       results = load_latest_results(repo)
       return format_summary(results)
   
   @server.tool("fortressci_explain_finding")
   async def explain_finding(finding_id: str) -> str:
       """Explain a specific security finding."""
       finding = get_finding(finding_id)
       return ai_explain(finding)
   
   @server.tool("fortressci_waiver_request")
   async def waiver_request(finding_id: str, reason: str) -> str:
       """Request a waiver for a false positive."""
       return create_waiver(finding_id, reason)
   ```

2. **Slack bot:**
   - Daily security digest message
   - `/fortressci status` command
   - Interactive waiver approval (approve/deny buttons)
   - Alert on new critical findings

3. **GitHub Marketplace App:**
   - One-click install
   - Auto-adds `devsecops.yml` workflow to repos
   - Webhook handler for scan results

**Estimated effort:** 3–4 weeks
**Key files:** `integrations/mcp-server/`, `integrations/slack-bot/`, `integrations/github-app/`

---

### 2.0.7 — Online Playground

**Goal:** Browser-based demo for instant FortressCI experience.

**Steps:**

1. **Frontend** (React SPA):
   - Tabs for: Dockerfile, Terraform, Python, JavaScript
   - Pre-loaded with intentionally vulnerable samples
   - "Scan" button runs analysis
   - Results panel showing findings with severity badges

2. **Backend** — lightweight API that runs Semgrep + Checkov + Trivy on submitted code
   - Sandboxed execution (Docker container with timeout)
   - Rate-limited (5 scans/minute per IP)
   - No persistent storage

3. **Alternatively** — run Semgrep via WASM (Semgrep has experimental WASM support) for client-side scanning

4. **Host** on Vercel/Render with the scanning API as a serverless function

5. **Shareable URLs** — encode findings in URL for sharing

**Estimated effort:** 3–4 weeks
**Key files:** `playground/`

---

## Long-Term Vision

### FortressCI Cloud (SaaS)
- Multi-tenant API with org management
- Centralised dashboard, SSO, RBAC
- Managed scanning infrastructure
- **Effort:** 3–6 months

### Cross-Repo Dependency Graph
- Visualise how vulnerabilities propagate across shared libraries
- "Upgrading `lodash` in `shared-utils` fixes 14 downstream repos"
- Requires org-wide scan data aggregation
- **Effort:** 4–6 weeks

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
