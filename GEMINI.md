# FortressCI: DevSecOps Platform Blueprint

## Project Overview
FortressCI is a "secure-by-default" DevSecOps platform blueprint designed to implement "Shift Left" security. It orchestrates a suite of best-in-class open-source security tools to automate secrets detection, SAST, SCA, IaC scanning, container security, and DAST across multiple CI/CD platforms.

### Core Technologies
- **Scripting:** Bash (orchestration), Python (reporting/summarization)
- **Containerization:** Docker (all-in-one scanner image)
- **CI/CD Support:** GitHub Actions, GitLab CI, Bitbucket, Azure Pipelines, Jenkins, CircleCI
- **Security Tools:**
  - **Secrets:** [TruffleHog](https://github.com/trufflesecurity/trufflehog)
  - **SAST:** [Semgrep](https://semgrep.dev/)
  - **SCA:** [Snyk](https://snyk.io/)
  - **IaC:** [Checkov](https://www.checkov.io/)
  - **Container:** [Trivy](https://github.com/aquasecurity/trivy)
  - **DAST:** [OWASP ZAP](https://www.zaproxy.org/)
  - **Signing:** [Cosign](https://github.com/sigstore/cosign)

## Building and Running

### Setup and Initialization
To initialize FortressCI in a project, run the interactive setup wizard:
```bash
./scripts/fortressci-init.sh
```
This script detects the project type (Node, Python, Go, Java) and CI platform, then generates the necessary configuration files and CI workflows.

### Local Development (Shift Left)
Install the pre-commit hooks to catch issues before they are committed:
```bash
pre-commit install
```

### All-in-One Local Scan (Docker)
You can run the entire security suite locally using Docker:
```bash
# Build the scanner image
docker build -t fortressci/scan .

# Run the scan (mounts workspace and results directory)
docker run --rm \
  -v $(pwd):/workspace \
  -v $(pwd)/results:/results \
  fortressci/scan /workspace
```

### Supply Chain Hardening
Check for unpinned GitHub Actions and Docker base images:
```bash
./scripts/check-pinning.sh --strict
```

## Configuration and Policies

### Severity Thresholds (`.fortressci.yml`)
Configures when the pipeline should fail or warn based on finding severity.
- `fail_on`: Severity level that causes pipeline failure (e.g., `critical`).
- `warn_on`: Severity level that triggers a warning.

### Policy-as-Code (`.security/policy.yml`)
Defines organizational security policies (e.g., mandatory SHA-pinning, no root containers). These are enforced during scans.

### Waiver Management
Exceptions to security findings are managed via the waiver CLI:
```bash
# Add a new waiver
./scripts/fortressci-waiver.sh add --id "CVE-ID" --scanner "snyk" --severity "high" --reason "Justification" --expires "YYYY-MM-DD" --author "@user"

# List active waivers
./scripts/fortressci-waiver.sh list
```
Waivers are stored in `.security/waivers.yml`.

## Development Conventions

1.  **Template-First:** Logic changes to CI/CD pipelines should be implemented in the `templates/` directory to ensure they propagate across all supported platforms.
2.  **Config-Driven:** Scanner behavior and gating should be controlled via `.fortressci.yml` rather than hardcoded in scripts.
3.  **Validation:** Use `scripts/check-thresholds.sh` for gating checks and `scripts/generate-report.py` for human-readable output.
4.  **Security-First:** All scripts and Dockerfiles should adhere to the project's own pinning and security policies.

## Key Files
- `scripts/fortressci-init.sh`: Project initialization wizard.
- `scripts/run-all.sh`: Orchestration script for the Docker scanner.
- `scripts/fortressci-waiver.sh`: CLI for managing security exceptions.
- `scripts/check-thresholds.sh`: Gating logic for CI/CD pipelines.
- `Dockerfile`: Defines the environment for the all-in-one security scanner.
- `templates/`: Contains baseline configurations for CI platforms and security tools.
- `.fortressci.yml`: Global configuration for the project's security posture.
