# Security Policy

## 1. "Zero Secrets" Mandate

**No credentials, tokens, or private keys shall be committed to this repository.**

- **Prevention**: Pre-commit hooks and CI pipelines scan every commit.
- **Remediation**: Any detected secret must be immediately rotated. Simply deleting the file is **insufficient**.
- **Baseline**: Weekly scans run on the full history to detect legacy secrets.

## 2. "Fail Fast" Policy

The build pipeline is the primary gatekeeper. Severity thresholds are configured in `.fortressci.yml`:

```yaml
thresholds:
  fail_on: critical   # critical | high | medium | low | none
  warn_on: high
```

Default thresholds by scanner:

| Scanner       | Threshold           | Description                                         |
| :------------ | :------------------ | :-------------------------------------------------- |
| **Secrets**   | **ANY**             | Zero tolerance for verified secrets.                |
| **SAST**      | **High / Critical** | Code vulnerabilities that pose immediate risk.      |
| **SCA**       | **High / Critical** | Dependencies with known exploitable CVEs.           |
| **IaC**       | **High / Critical** | Misconfigurations like public buckets or 0.0.0.0/0. |
| **Container** | **High / Critical** | OS/Library vulnerabilities in the shipping image.   |

Run the threshold check manually:

```bash
./scripts/check-thresholds.sh <results_dir> [.fortressci.yml]
```

## 3. Exceptions & Waivers

If a finding is a false positive or an accepted risk, it must be explicitly waived.

**Using the CLI:**

```bash
./scripts/fortressci-waiver.sh add \
  --id "CVE-2024-1234" \
  --scanner snyk \
  --severity high \
  --reason "Dev-dependency only, not used in production" \
  --expires 2026-06-01 \
  --author "@your-name"
```

**Review Process:**

1. Add the waiver via the CLI (writes to `.security/waivers.yml`).
2. Open a Pull Request.
3. **Required Approval**: Must be approved by a Repository Admin or Security Champion.
4. **Expiry**: Waivers must have an `expires_on` date (max configurable in `.fortressci.yml` via `waivers.max_expiry_days`, default 90 days).

**Manage waivers:**

```bash
./scripts/fortressci-waiver.sh list           # Active waivers
./scripts/fortressci-waiver.sh list --expired  # Include expired
./scripts/fortressci-waiver.sh expire          # Remove expired entries
./scripts/fortressci-waiver.sh remove --id "CVE-2024-1234"
```

## 4. Supply Chain Hardening

All third-party dependencies in CI pipelines should be pinned:

- **GitHub Actions**: Pin to full commit SHA, not tags (enforced by `scripts/check-pinning.sh`)
- **Docker base images**: Pin to version tags or digest hashes

```bash
./scripts/check-pinning.sh           # Check both (warnings)
./scripts/check-pinning.sh --strict  # Fail on any unpinned reference
```

## 5. Policy-as-Code

Organisational security policies are defined in `.security/policy.yml`. Each policy maps to an automated check and severity level. Policies can be enabled/disabled per project.

## 6. Reporting Vulnerabilities

If you find a security issue that the scanners missed, please open a standard GitHub Issue with the label `security`.
