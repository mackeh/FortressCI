# FortressCI: The DevSecOps Platform

FortressCI is a secure-by-default DevSecOps platform blueprint designed to implement "Shift Left" security, automated pipelines, and infrastructure protection. It integrates best-in-class open-source security tools to ensure your code and infrastructure are secure from day one.

> **[View our Roadmap](ROADMAP.md)** for upcoming features and long-term vision.

## Features

### Phase 1: Shift Left (Local Development)

Catch issues before they are committed.

- **Secrets Detection**: [TruffleHog](https://github.com/trufflesecurity/trufflehog) scans for hardcoded credentials.
- **Code Quality**: Standard hooks for trailing whitespace and file integrity.
- **IaC Scanning**: [Checkov](https://www.checkov.io/) runs locally to catch Terraform/CloudFormation issues.

### Phase 2: Automated Pipeline (CI/CD)

Automated checks on every push and pull request across **6 CI platforms**.

- **Secret Scanning**: TruffleHog deep scan on git history.
- **SAST**: [Semgrep](https://semgrep.dev/) scans source code for vulnerabilities (OWASP Top 10).
- **SCA**: [Snyk](https://snyk.io/) checks dependencies for known CVEs.
- **IaC Scanning**: Checkov scans Terraform, CloudFormation, and Kubernetes manifests.
- **Container Security**: [Trivy](https://github.com/aquasecurity/trivy) scans Docker images for OS and library vulnerabilities.
- **DAST**: [OWASP ZAP](https://www.zaproxy.org/) baseline scan for runtime attack surface.
- **Signing**: [Cosign](https://github.com/sigstore/cosign) signs container images with SBOM generation.

### Phase 3: Infrastructure Security

- Container registry signing and attestation
- SBOM generation via Trivy
- Compliance audit artifacts

---

## Quick Start

### Option 1: Setup Wizard (Recommended)

```bash
git clone https://github.com/mackeh/FortressCI.git
cd FortressCI

# Run the interactive wizard — detects your project type and CI platform
./scripts/fortressci-init.sh

# Or skip prompts by specifying the CI platform
./scripts/fortressci-init.sh --ci github-actions
```

The wizard generates:
- CI/CD workflow file for your platform
- `.pre-commit-config.yaml` (local hooks)
- `.security/waivers.yml` (finding exceptions)
- `.fortressci.yml` (severity thresholds and scanner config)

Then install the hooks:

```bash
pre-commit install
```

### Option 2: Docker Local Scan

Run all security scans locally in a single container:

```bash
# Build the all-in-one scanner image
docker build -t fortressci/scan .

# Scan your project (results output to ./results/)
docker run --rm \
  -v $(pwd):/workspace \
  -v $(pwd)/results:/results \
  fortressci/scan /workspace
```

This runs TruffleHog, Semgrep, Snyk, Checkov, and Trivy in sequence, then generates an interactive HTML report and checks severity thresholds.

---

## Supported CI Platforms

| Platform | Template | Generated File |
|----------|----------|----------------|
| **GitHub Actions** | `templates/github-actions/devsecops.yml` | `.github/workflows/devsecops.yml` |
| **GitLab CI** | `templates/gitlab-ci/devsecops.yml` | `.gitlab-ci.yml` |
| **Bitbucket Pipelines** | `templates/bitbucket/bitbucket-pipelines.yml` | `bitbucket-pipelines.yml` |
| **Azure Pipelines** | `templates/azure/azure-pipelines.yml` | `azure-pipelines.yml` |
| **Jenkins** | `templates/jenkins/Jenkinsfile` | `Jenkinsfile` |
| **CircleCI** | `templates/circleci/config.yml` | `.circleci/config.yml` |

All templates implement the same 5 scan stages with platform-specific syntax.

---

## Severity Thresholds

Configure when your pipeline should fail or warn in `.fortressci.yml`:

```yaml
thresholds:
  fail_on: critical   # critical | high | medium | low | none
  warn_on: high
```

Run the gating check manually:

```bash
./scripts/check-thresholds.sh <results_dir> [.fortressci.yml]
```

---

## Waiver Management

Manage security finding exceptions with the waiver CLI:

```bash
# Add a waiver
./scripts/fortressci-waiver.sh add \
  --id "CVE-2024-1234" \
  --scanner snyk \
  --severity high \
  --reason "Dev-dependency only, not used in production" \
  --expires 2026-06-01 \
  --author "@your-name"

# List active waivers
./scripts/fortressci-waiver.sh list

# List including expired
./scripts/fortressci-waiver.sh list --expired

# Remove expired waivers
./scripts/fortressci-waiver.sh expire

# Remove a specific waiver
./scripts/fortressci-waiver.sh remove --id "CVE-2024-1234"
```

Waivers are stored in `.security/waivers.yml` with required fields: `id`, `scanner`, `severity`, `justification`, `expires_on`, `approved_by`.

---

## HTML Reporting

After scans complete, an interactive HTML report is generated with:

- Severity breakdown cards (critical, high, medium, low)
- Findings by tool (doughnut chart)
- Severity distribution (bar chart)
- Filterable, searchable findings table

Generate manually:

```bash
python3 scripts/generate-report.py <results_dir>
```

---

## CI/CD Secrets

Add these to your CI platform's secret store:

| Secret | Required | Purpose |
|--------|----------|---------|
| `SNYK_TOKEN` | For SCA scans | [Get token](https://app.snyk.io/account) |
| `COSIGN_KEY` | For image signing | Generate with `./scripts/generate_keys.sh` |
| `COSIGN_PASSWORD` | For image signing | Passphrase for Cosign key |
| `INFRACOST_API_KEY` | For cost estimation | [Get token](https://www.infracost.io/) |

---

## Tools & Configuration

| Tool | Type | Configuration |
|------|------|---------------|
| **TruffleHog** | Secrets | `.pre-commit-config.yaml` / CI workflow |
| **Semgrep** | SAST | CI workflow (auto-config, OWASP Top 10) |
| **Snyk** | SCA | CI workflow (Node/Python/Go/Java) |
| **Checkov** | IaC | `.pre-commit-config.yaml` / CI workflow |
| **Trivy** | Containers | CI workflow |
| **OWASP ZAP** | DAST | CI workflow (baseline scan) |
| **Cosign** | Signing | CI workflow (image signing + SBOM) |

---

## Repository Structure

```
.
├── .github/
│   ├── workflows/devsecops.yml    # Primary GitHub Actions pipeline
│   └── scripts/post_summary.js    # PR comment posting script
├── .security/
│   └── waivers.yml                # Security finding exceptions
├── scripts/
│   ├── fortressci-init.sh         # Setup wizard CLI
│   ├── run-all.sh                 # Docker scan orchestrator
│   ├── generate-report.py         # HTML report generator
│   ├── summarize.py               # Summary JSON generator
│   ├── check-thresholds.sh        # Severity threshold gating
│   ├── fortressci-waiver.sh       # Waiver management CLI
│   └── generate_keys.sh           # Cosign key generation
├── templates/                     # CI/CD configs for all 6 platforms
│   ├── github-actions/
│   ├── gitlab-ci/
│   ├── bitbucket/
│   ├── azure/
│   ├── jenkins/
│   ├── circleci/
│   ├── report.html.j2             # Jinja2 HTML report template
│   ├── fortressci.yml             # Default threshold config
│   ├── pre-commit-config.yaml
│   └── waivers.yml
├── terraform/main.tf              # Sample (intentionally vulnerable) IaC
├── .fortressci.yml                # Threshold & scanner configuration
├── .pre-commit-config.yaml        # Local Git hooks
├── Dockerfile                     # All-in-one scanner image
└── Dockerfile.example             # Sample vulnerable Dockerfile
```

## Operational Recommendations

### Branch Protection

Enable [Branch Protection Rules](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/defining-the-mergeability-of-pull-requests/managing-a-branch-protection-rule) on `main`:

- Require status checks to pass before merging (select all scan jobs).
- Require pull request reviews before merging.
- Do not allow bypassing the above settings.

### Scheduled Scans

The GitHub Actions pipeline runs a baseline secret scan weekly (Sundays at 00:00 UTC) to catch newly-identified vulnerability patterns.

### Incident Triage

- **Findings**: All SARIF results appear in GitHub's **Security > Code Scanning** tab (if Advanced Security is enabled) or as downloadable artifacts.
- **Waivers**: For false positives, use the waiver CLI to document the exception with a justification and expiry date.

---

## Contributing

This is a blueprint repository. Fork it and adapt to your needs. Changes to scan logic should be reflected across all 6 CI platform templates.
