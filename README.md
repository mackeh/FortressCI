# FortressCI: The DevSecOps Platform

FortressCI is a secure-by-default DevSecOps platform blueprint designed to implement "Shift Left" security, automated pipelines, and infrastructure protection. It integrates best-in-class open source security tools to ensure your code and infrastructure are secure from day one.

## 🚀 Features

### Phase 1: Shift Left (Local Development)

Catch issues before they are committed.

- **Secrets Detection**: [TruffleHog](https://github.com/trufflesecurity/trufflehog) scans for hardcoded credentials.
- **Code Quality**: Standard hooks for trailing whitespace and file integrity.
- **IaC Scanning**: [Checkov](https://www.checkov.io/) runs locally to catch Terraform/CloudFormation issues.

### Phase 2: Automated Pipeline (CI/CD)

Automated checks on every push and pull request via GitHub Actions.

- **Secret Scanning**: TruffleHog deep scan on git history.
- **SAST (Static Application Security Testing)**: [Semgrep](https://semgrep.dev/) scans source code for vulnerabilities (OWASP Top 10).
- **SCA (Software Composition Analysis)**: [Snyk](https://snyk.io/) checks dependencies for known CVEs.

### Phase 3: Infrastructure Security

Secure your infrastructure and containers.

- **IaC Scanning**: Checkov scans Terraform, CloudFormation, and Kubernetes manifests.
- **Container Security**: [Trivy](https://github.com/aquasecurity/trivy) scans Docker images for OS and library vulnerabilities.

---

## 🛠️ Getting Started

### Prerequisites

- [pre-commit](https://pre-commit.com/#install) installed.
- [trufflehog](https://github.com/trufflesecurity/trufflehog) installed locally.
- GitHub Repository with Actions enabled.

### Local Setup (Shift Left)

1.  **Clone the repository:**

    ```bash
    git clone https://github.com/your-org/FortressCI.git
    cd FortressCI
    ```

2.  **Install Git Hooks:**

    ```bash
    pre-commit install
    ```

3.  **Test Locally:**
    Try committing a dummy secret (e.g., `AWS_ACCESS_KEY_ID=AKIA...`) and watch TruffleHog block it.

### CI/CD Setup

1.  **Secrets Configuration:**
    Go to your GitHub Repository > Settings > Secrets and variables > Actions.
    Add the following secrets:
    - `SNYK_TOKEN`: Your Snyk API token (get it from [snyk.io](https://app.snyk.io/account)).

2.  **Run the Pipeline:**
    Push code to the `main` branch or open a Pull Request. The `DevSecOps Pipeline` workflow will automatically run.

---

## 📂 Repository Structure

```
.
├── .github/workflows/
│   └── devsecops.yml    # Main CI/CD Pipeline definition
├── terraform/
│   └── main.tf          # Sample Terraform file (for testing Checkov)
├── Dockerfile           # Sample Dockerfile (for testing Trivy)
├── .pre-commit-config.yaml # Local hook configuration
└── README.md            # This documentation
```

## 🛡️ Tools & Configuration

| Tool           | Type       | Configuration Context                       |
| :------------- | :--------- | :------------------------------------------ |
| **TruffleHog** | Secrets    | `.pre-commit-config.yaml` / `devsecops.yml` |
| **Semgrep**    | SAST       | `devsecops.yml` (auto-config)               |
| **Snyk**       | SCA        | `devsecops.yml` (Node/Python/etc.)          |
| **Checkov**    | IaC        | `.pre-commit-config.yaml` / `devsecops.yml` |
| **Trivy**      | Containers | `devsecops.yml`                             |

## 🤝 Contributing

This is a blueprint repository. Fork it and adapt the `devsecops.yml` to fit your specific build requirements (e.g., usually you would build your application before running the container scan).
