#!/usr/bin/env python3
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


def test_bicep_sarif_is_included_in_summary(tmp_path: Path):
    results = tmp_path / "results"
    write_json(results / "sast.sarif", {"runs": []})
    write_json(results / "container.sarif", {"runs": []})
    write_json(results / "checkov.sarif", {"runs": []})
    write_json(results / "sca.json", [])
    (results / "secrets.json").write_text("", encoding="utf-8")
    write_json(
        results / "bicep.sarif",
        {
            "runs": [
                {
                    "results": [
                        {"level": "error", "message": {"text": "bicep issue 1"}},
                        {"level": "warning", "message": {"text": "bicep issue 2"}},
                    ]
                }
            ]
        },
    )

    proc = run_summarize(results)
    # summarize.py exits non-zero when findings exist.
    assert proc.returncode == 1, proc.stderr + proc.stdout

    summary = json.loads((results / "summary.json").read_text(encoding="utf-8"))
    assert summary["tools"]["bicep"]["high"] == 1
    assert summary["tools"]["bicep"]["medium"] == 1
