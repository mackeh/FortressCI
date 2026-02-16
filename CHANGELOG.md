# Changelog

All notable changes to this project are documented in this file.

The format is based on Keep a Changelog, and the project follows Semantic Versioning.

## [Unreleased]

## [2.2.0] - 2026-02-16

### Added
- Added `scripts/generate-adoption-roadmap.py` to generate prioritized 30/60/90-day DevSecOps plans with maturity and feasibility scoring.
- Added roadmap outputs in scan flow: `results/adoption-roadmap.json` and `results/adoption-roadmap.md`.
- Added MCP tool `get_devsecops_adoption_roadmap` for assistant access to roadmap data.
- Added dedicated Bicep SARIF handling (`bicep.sarif`) in local scan orchestration and reporting pipelines.
- Added Bicep summary regression test: `tests/python/test_summarize_bicep.py`.
- Added roadmap generator tests: `tests/python/test_generate_adoption_roadmap.py`.
- Added an end-to-end Azure DevOps template flow in `templates/azure/azure-pipelines.yml` (build, scan, gate, publish artifacts, roadmap highlights).

### Changed
- Updated GitHub IaC scan scope from `./terraform` to repository root (`.`) to include Bicep and non-Terraform IaC paths.
- Updated setup wizard detection to identify Bicep repositories.
- Updated README and roadmap documentation to reflect roadmap intelligence, Azure integration, and Bicep coverage.

### Fixed
- Updated `.github/workflows/devsecops.yml` run blocks to satisfy actionlint ShellCheck checks (quoted expansions and consolidated audit JSON generation).

## [2.1.6] - 2026-02-13

### Added
- Added `scripts/fortressci-doctor.sh` for health checks across config files, hooks, tools, secrets, and CI setup.
- Added initial script test suites:
  - Python tests in `tests/python/` (cross-repo analyzer)
  - Bash tests in `tests/bash/` (doctor and threshold gating)
- Added `.yamllint.yml` baseline project lint rules for stable YAML linting in CI.

### Changed
- Added doctor guidance to `scripts/fortressci-init.sh` output.
- Included doctor utility in the Docker image as `fortressci-doctor`.
- Updated README and roadmap documentation for doctor workflow and status.
- Added a non-blocking `doctor-check` job in `.github/workflows/devsecops.yml` that uploads `fortressci-doctor.log`.
- Added blocking `quality-lint` and `script-tests` jobs to `.github/workflows/devsecops.yml`.

## [2.1.5] - 2026-02-13

### Fixed
- Fixed a syntax error in `scripts/cross-repo-analyzer.py` that prevented execution.

### Changed
- Rebuilt cross-repo analysis logic with stronger error handling and deterministic output.
- Added optional Snyk correlation (`sca.json`) to identify vulnerable shared dependencies.
- Added ranked `top_shared_risk_hotspots` to prioritize high-impact remediation work.

### Documentation
- Added cross-repo analyzer usage docs in `README.md`.
- Updated `ROADMAP.md` and `fortressci-roadmap.md` to reflect current delivery status.
