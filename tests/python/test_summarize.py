#!/usr/bin/env python3
"""Fixture-driven tests for scripts/summarize.py."""
import json
import subprocess
from pathlib import Path


SCRIPT = Path("scripts/summarize.py")


def run_summarize(results_dir: Path):
    return subprocess.run(
        ["python3", str(SCRIPT), str(results_dir)],
        capture_output=True,
        text=True,
    )


def write_json(path: Path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data), encoding="utf-8")


def write_text(path: Path, content: str):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def load_summary(results_dir: Path):
    return json.loads((results_dir / "summary.json").read_text(encoding="utf-8"))


# --- SARIF fixture helper ---

def make_sarif(results):
    """Build a minimal SARIF with the given results (list of {level: ...})."""
    return {
        "$schema": "https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json",
        "version": "2.1.0",
        "runs": [{"results": results}],
    }


# --- Tests ---

def test_summarize_aggregates_all_tools(tmp_path: Path):
    """Core test: SARIF + TruffleHog + Snyk data aggregated correctly."""
    results = tmp_path / "results"
    results.mkdir()

    # TruffleHog: 2 secrets (2 lines = 2 critical)
    write_text(results / "secrets.json", '{"key":"val"}\n{"key2":"val2"}\n')

    # Semgrep SARIF: 1 error (high), 1 warning (medium)
    write_json(
        results / "sast.sarif",
        make_sarif([{"level": "error"}, {"level": "warning"}]),
    )

    # Snyk: 1 high, 1 low
    write_json(
        results / "sca.json",
        {
            "vulnerabilities": [
                {"severity": "high"},
                {"severity": "low"},
            ]
        },
    )

    # Checkov SARIF: 1 note (low)
    write_json(
        results / "results_sarif.sarif",
        make_sarif([{"level": "note"}]),
    )

    # No Bicep, no container
    # (missing files → counts should be zero)

    proc = run_summarize(results)
    # summarize.py exits 1 when findings > 0
    assert proc.returncode == 1, proc.stderr

    summary = load_summary(results)

    # TruffleHog: 2 critical
    assert summary["tools"]["trufflehog"]["critical"] == 2

    # Semgrep: 1 high, 1 medium
    assert summary["tools"]["semgrep"]["high"] == 1
    assert summary["tools"]["semgrep"]["medium"] == 1

    # Snyk: 1 high, 1 low
    assert summary["tools"]["snyk"]["high"] == 1
    assert summary["tools"]["snyk"]["low"] == 1

    # Checkov: 1 low
    assert summary["tools"]["checkov"]["low"] == 1

    # Totals
    assert summary["totals"]["critical"] == 2
    assert summary["totals"]["high"] == 2
    assert summary["totals"]["medium"] == 1
    assert summary["totals"]["low"] == 2
    assert summary["total_findings"] == 7


def test_summarize_empty_results(tmp_path: Path):
    """Empty results dir should produce zero counts and exit 0."""
    results = tmp_path / "results"
    results.mkdir()

    proc = run_summarize(results)
    assert proc.returncode == 0, proc.stderr

    summary = load_summary(results)
    assert summary["total_findings"] == 0
    for sev in ("critical", "high", "medium", "low"):
        assert summary["totals"][sev] == 0


def test_summarize_bicep_sarif(tmp_path: Path):
    """Bicep SARIF should be aggregated under a separate tool key."""
    results = tmp_path / "results"
    results.mkdir()

    write_json(
        results / "bicep.sarif",
        make_sarif([{"level": "error"}, {"level": "warning"}, {"level": "warning"}]),
    )

    proc = run_summarize(results)
    assert proc.returncode == 1, proc.stderr

    summary = load_summary(results)
    assert summary["tools"]["bicep"]["high"] == 1
    assert summary["tools"]["bicep"]["medium"] == 2
    assert summary["totals"]["high"] == 1
    assert summary["totals"]["medium"] == 2


def test_summarize_includes_waiver_status(tmp_path: Path):
    """When waivers.yml exists, summary should include waiver counts."""
    results = tmp_path / "results"
    results.mkdir()

    # Create a .security/waivers.yml with 1 expired and 1 active waiver
    waivers_content = """\
waivers:
  - id: "CVE-OLD"
    scanner: "snyk"
    severity: "high"
    justification: "Old waiver"
    expires_on: "2020-01-01"
    approved_by: "@old"

  - id: "CVE-FUTURE"
    scanner: "snyk"
    severity: "medium"
    justification: "Future waiver"
    expires_on: "2099-12-31"
    approved_by: "@new"
"""
    security_dir = tmp_path / ".security"
    security_dir.mkdir()
    write_text(security_dir / "waivers.yml", waivers_content)

    proc = run_summarize(results)
    assert proc.returncode == 0, proc.stderr

    summary = load_summary(results)
    assert "waivers" in summary
    assert summary["waivers"]["expired"] == 1
    assert summary["waivers"]["active"] == 1
