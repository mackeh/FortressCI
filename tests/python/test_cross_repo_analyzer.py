#!/usr/bin/env python3
import json
import subprocess
from pathlib import Path


SCRIPT = Path("scripts/cross-repo-analyzer.py")


def run_analyzer(tmp_path: Path, extra_args=None):
    args = ["python3", str(SCRIPT), "--dir", str(tmp_path)]
    if extra_args:
        args.extend(extra_args)
    return subprocess.run(args, capture_output=True, text=True)


def write_json(path: Path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data), encoding="utf-8")


def test_cross_repo_hotspots_with_sca_correlation(tmp_path: Path):
    write_json(
        tmp_path / "repo-a" / "sbom-source.cdx.json",
        {"components": [{"name": "lodash", "version": "4.17.15"}]},
    )
    write_json(
        tmp_path / "repo-b" / "sbom-source.cdx.json",
        {"components": [{"name": "lodash", "version": "4.17.15"}]},
    )
    write_json(
        tmp_path / "repo-a" / "sca.json",
        {"vulnerabilities": [{"packageName": "lodash", "version": "4.17.15"}]},
    )

    proc = run_analyzer(tmp_path, ["--top", "5", "--quiet"])
    assert proc.returncode == 0, proc.stderr + proc.stdout

    report_path = tmp_path / "cross-repo-analysis.json"
    assert report_path.exists()
    report = json.loads(report_path.read_text(encoding="utf-8"))

    assert report["analysis_summary"]["total_repos"] == 2
    assert report["analysis_summary"]["shared_deps"] == 1
    assert report["analysis_summary"]["shared_deps_with_known_vulns"] == 1
    assert report["top_shared_risk_hotspots"][0]["dependency"] == "lodash@4.17.15"
    assert report["top_shared_risk_hotspots"][0]["vulnerable_repository_count"] == 1


def test_cross_repo_no_sbom_returns_non_zero_and_error_report(tmp_path: Path):
    output_path = tmp_path / "out.json"
    proc = run_analyzer(tmp_path, ["--output", str(output_path)])
    assert proc.returncode == 1
    assert output_path.exists()

    report = json.loads(output_path.read_text(encoding="utf-8"))
    assert "error" in report
    assert "No SBOM files named" in report["error"]
