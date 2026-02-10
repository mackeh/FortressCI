# Security Policy

## 1. "Zero Secrets" Mandate

**No credentials, tokens, or private keys shall be committed to this repository.**

- **Prevention**: Pre-commit hooks and CI pipelines scan every commit.
- **Remediation**: Any detected secret must be immediately rotated. Simply deleting the file is **insufficient**.
- **Baseline**: Weekly scans run on the full history to detect legacy secrets.

## 2. "Fail Fast" Policy

The build pipeline is the primary gatekeeper. It will **fail and block merging** if:

| Scanner       | Threshold           | Description                                         |
| :------------ | :------------------ | :-------------------------------------------------- |
| **Secrets**   | **ANY**             | Zero tolerance for verified secrets.                |
| **SAST**      | **High / Critical** | Code vulnerabilities that pose immediate risk.      |
| **SCA**       | **High / Critical** | Dependencies with known explitable CVEs.            |
| **IaC**       | **High / Critical** | Misconfigurations like public buckets or 0.0.0.0/0. |
| **Container** | **High / Critical** | OS/Library vulnerabilities in the shipping image.   |

## 3. Exceptions & Waivers

If a finding is a false positive or an accepted risk, it must be explicitly waived.

**Review Process:**

1.  Add the finding to `.security/waivers.yml`.
2.  Open a Pull Request.
3.  **Required Approval**: Must be approved by a Repository Admin or Security Champion.
4.  **Expiry**: Waivers must have an `expires_on` date (max 30 days).

## 4. Reporting Vulnerabilities

If you find a security issue that the scanners missed, please open a standard GitHub Issue with the label `security`.
