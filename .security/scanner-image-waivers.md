# Scanner Image Temporary Waivers

This file documents temporary exceptions for vulnerabilities reported in the FortressCI scanner image itself.

These are not application waivers. They exist because the scanner image embeds third-party security tools, and the latest available upstream releases may temporarily ship with unresolved transitive vulnerabilities.

## Active temporary waivers

Review date: 2026-03-02

- `CVE-2026-24051`
  Affects the embedded `go.opentelemetry.io/otel/sdk` dependency inside the current `cosign` and `syft` binaries.
  Current pinned versions:
  - `cosign v3.0.5`
  - `syft v1.42.1`
  Upstream status:
  - No newer stable releases were available on 2026-03-02.
  Exit criteria:
  - Remove this waiver when a newer `cosign` or `syft` release includes `go.opentelemetry.io/otel/sdk >= 1.40.0`.

- `CVE-2025-46569`
  Affects the embedded `github.com/open-policy-agent/opa` dependency inside the current `snyk` wrapper binary.
  Current pinned version:
  - `snyk 1.1303.0`
  Upstream status:
  - No newer stable npm release was available on 2026-03-02.
  Exit criteria:
  - Remove this waiver when a newer `snyk` release updates the embedded OPA dependency beyond `v0.69.0`.

## Policy

- The dedicated scanner-image workflow remains the place where these issues are observed and tracked.
- Trivy results for the scanner image are currently report-only while these upstream issues remain unresolved.
- The main DevSecOps workflow must not suppress or inherit these waivers for application or repository scans.
