#!/usr/bin/env python3
import json
import subprocess
from pathlib import Path


SCRIPT = Path("scripts/generate-adoption-roadmap.py")


def run_generator(workspace: Path, results_dir: Path):
    return subprocess.run(
        [
            "python3",
            str(SCRIPT),
            "--workspace",
            str(workspace),
            "--results-dir",
            str(results_dir),
            "--config",
            str(workspace / ".fortressci.yml"),
        ],
        capture_output=True,
        text=True,
    )


def write_json(path: Path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data), encoding="utf-8")


def write_text(path: Path, content: str):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def load_roadmap(results_dir: Path):
    return json.loads((results_dir / "adoption-roadmap.json").read_text(encoding="utf-8"))


def test_roadmap_includes_high_urgency_actions_for_risky_repo(tmp_path: Path):
    workspace = tmp_path / "repo"
    results = workspace / "results"

    write_text(
        workspace / ".fortressci.yml",
        """
thresholds:
  fail_on: none
  warn_on: high
scanners:
  secrets:
    enabled: true
  sast:
    enabled: false
  sca:
    enabled: true
  iac:
    enabled: false
  container:
    enabled: true
  dast:
    enabled: false
ai:
  enabled: false
""".strip()
        + "\n",
    )
    write_json(
        results / "summary.json",
        {
            "totals": {"critical": 2, "high": 4, "medium": 5, "low": 3},
            "tools": {"trufflehog": {}, "snyk": {}, "trivy": {}},
            "total_findings": 14,
        },
    )

    proc = run_generator(workspace, results)
    assert proc.returncode == 0, proc.stderr + proc.stdout

    roadmap = load_roadmap(results)
    action_ids = [action["id"] for action in roadmap["recommended_actions"]]

    assert "remediate-critical-findings" in action_ids
    assert "enforce-threshold-gates" in action_ids
    assert "policy-as-code-foundation" in action_ids
    assert roadmap["scores"]["adoption_feasibility"] < 80
    assert (results / "adoption-roadmap.md").exists()


def test_roadmap_handles_mature_repo_with_low_risk(tmp_path: Path):
    workspace = tmp_path / "repo"
    results = workspace / "results"

    write_text(
        workspace / ".fortressci.yml",
        """
thresholds:
  fail_on: high
  warn_on: medium
waivers:
  require_approval: true
scanners:
  secrets:
    enabled: true
  sast:
    enabled: true
  sca:
    enabled: true
  iac:
    enabled: true
  container:
    enabled: true
  dast:
    enabled: true
ai:
  enabled: true
""".strip()
        + "\n",
    )
    write_text(workspace / ".pre-commit-config.yaml", "repos: []\n")
    write_text(workspace / ".security" / "policy.yml", "policies: []\n")
    write_text(workspace / ".security" / "waivers.yml", "waivers: []\n")
    write_text(workspace / ".github" / "workflows" / "devsecops.yml", "name: test\n")
    write_json(
        results / "summary.json",
        {"totals": {"critical": 0, "high": 0, "medium": 1, "low": 2}, "tools": {}, "total_findings": 3},
    )
    write_json(results / "compliance-report.json", {"framework_summary": {}})
    write_json(results / "badge.json", {"score": 95, "grade": "A+"})
    write_text(results / "sbom-source.spdx.json", "{}\n")

    proc = run_generator(workspace, results)
    assert proc.returncode == 0, proc.stderr + proc.stdout

    roadmap = load_roadmap(results)
    assert roadmap["scores"]["devsecops_maturity"] >= 80
    assert roadmap["scores"]["adoption_feasibility"] >= 70
    assert roadmap["current_state"]["scanner_coverage"]["disabled"] == []
