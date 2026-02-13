# Changelog

All notable changes to this project are documented in this file.

The format is based on Keep a Changelog, and the project follows Semantic Versioning.

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

