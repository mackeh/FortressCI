# FortressCI: The DevSecOps Platform

FortressCI is a secure-by-default DevSecOps platform blueprint designed to implement "Shift Left" security, automated pipelines, and infrastructure protection. It integrates best-in-class open-source security tools to ensure your code and infrastructure are secure from day one.

> **[View our Roadmap](ROADMAP.md)** for upcoming features and long-term vision.
> **[Try the Interactive Playground](playground/index.html)** to see FortressCI in action.

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
- **Signing**: [Cosign](https://github.com/sigstore/cosign) signs container images.
- **SBOM**: [Syft](https://github.com/anchore/syft) generates SPDX/CycloneDX Bill of Materials.
- **Provenance**: [SLSA](https://slsa.dev/) Level 3 build provenance via slsa-github-generator.

### Phase 3: Platform & Intelligence

- **AI Triage**: Automated findings analysis and prioritisation via LLMs.
- **Auto-Remediation**: Self-healing pipelines that open PRs to fix vulnerabilities.
- **Security Dashboard**: Real-time visualisations of security posture and trends.
- **MCP Server**: Native integration for AI assistants to query security data.

---

## Quick Start

### Option 1: Setup Wizard (Recommended)

```bash
git clone https://github.com/mackeh/FortressCI.git
cd FortressCI

# Run the interactive wizard — detects your project type and CI platform
./scripts/fortressci-init.sh
```

The wizard generates:
- CI/CD workflow file for your platform
- `.pre-commit-config.yaml` (local hooks)
- `.security/` configurations (policy, waivers, compliance mappings, falco rules)
- `.fortressci.yml` (severity thresholds and scanner config)

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

This runs the full suite including AI triage, SBOM generation, and threshold gating.

---

## Security Scoring

FortressCI calculates a real-time security grade (A+ to F) based on findings and practices.

```bash
# Generate your security badge
./scripts/generate-badge.py <results_dir>
```

![FortressCI Badge](https://img.shields.io/badge/FortressCI-A%2B%20(95)-brightgreen)

---

## Policy-as-Code

Define organisational security policies in `.security/policy.yml`. Policies are enforced during scans and can gate your pipeline.

```bash
# Run policy enforcement
./scripts/fortressci-policy-check.sh .security/policy.yml results/
```

---

## Compliance Reporting

Map technical findings to regulatory frameworks (SOC2, NIST, OWASP).

```bash
# Generate compliance report
python3 scripts/generate-compliance-report.py results/ .security/compliance-mappings.yml
```

---

## Auto-Remediation

FortressCI can automatically apply fixes for dependency and IaC vulnerabilities.

```bash
# Attempt automatic fixes
./scripts/auto-fix.sh
```

---

## AI-Powered Triage

Use LLMs to explain complex vulnerabilities and prioritise remediation.

```bash
# Run AI triage (requires ANTHROPIC_API_KEY)
python3 scripts/ai-triage.py --results-dir results/ --config .fortressci.yml
```

---

## Repository Structure

```
.
├── .github/
│   ├── workflows/devsecops.yml    # Primary GitHub Actions pipeline
│   └── scripts/post_summary.js    # PR comment posting script
├── .security/
│   ├── policy.yml                 # Policy-as-code definitions
│   ├── waivers.yml                # Security finding exceptions
│   ├── compliance-mappings.yml    # Framework mapping definitions
│   └── falco-rules.yaml           # Runtime security rules
├── dashboard/                     # Security Operations Dashboard
├── playground/                    # Interactive Browser Playground
├── examples/                      # Vulnerable sample apps (Node/Python/TF)
├── integrations/
│   └── mcp-server/                # Model Context Protocol server
├── scripts/
│   ├── fortressci-init.sh         # Setup wizard CLI
│   ├── run-all.sh                 # Docker scan orchestrator
│   ├── ai-triage.py               # AI findings analysis
│   ├── auto-fix.sh                # Automated remediation
│   ├── generate-badge.py          # Security scoring & badges
│   ├── generate-sbom.sh           # SBOM generator
│   ├── fortressci-policy-check.sh # Policy enforcement
│   ├── generate-report.py         # HTML report generator
│   └── check-pinning.sh           # Supply chain pinning checker
├── templates/                     # CI/CD and config templates
├── .fortressci.yml                # Global project configuration
└── Dockerfile                     # All-in-one scanner image
```

---

## CI/CD Secrets

| Secret | Required | Purpose |
|--------|----------|---------|
| `SNYK_TOKEN` | For SCA scans | [Get token](https://app.snyk.io/account) |
| `ANTHROPIC_API_KEY` | For AI Triage | [Get key](https://console.anthropic.com/) |
| `COSIGN_KEY` | For image signing | Generate with `./scripts/generate_keys.sh` |
| `INFRACOST_API_KEY` | For cost estimation | [Get token](https://www.infracost.io/) |

---

## Contributing

Please see [CONTRIBUTING.md](CONTRIBUTING.md) and our [Code of Conduct](CODE_OF_CONDUCT.md).
