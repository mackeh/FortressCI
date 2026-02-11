import json
import sys
import os
from pathlib import Path


def load_json(path):
    try:
        with open(path) as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {}


def empty_severity():
    return {"critical": 0, "high": 0, "medium": 0, "low": 0}


def summarize_trufflehog(path):
    counts = empty_severity()
    try:
        with open(path, 'r') as f:
            for line in f:
                if line.strip():
                    # All secrets are critical
                    counts["critical"] += 1
    except FileNotFoundError:
        pass
    return counts


def map_sarif_level(level):
    mapping = {
        "error": "high",
        "warning": "medium",
        "note": "low",
        "none": "low",
    }
    return mapping.get(level, "medium")


def summarize_sarif(path):
    counts = empty_severity()
    data = load_json(path)
    for run in data.get("runs", []):
        for result in run.get("results", []):
            level = result.get("level", "warning")
            severity = map_sarif_level(level)
            counts[severity] += 1
    return counts


def summarize_snyk(path):
    counts = empty_severity()
    data = load_json(path)
    if isinstance(data, dict):
        data = [data]
    for project in data:
        for vuln in project.get("vulnerabilities", []):
            sev = vuln.get("severity", "low").lower()
            if sev in counts:
                counts[sev] += 1
    return counts


def total_for(counts):
    return sum(counts.values())


def main():
    if len(sys.argv) < 2:
        print("Usage: summarize.py <results_dir>")
        sys.exit(1)

    results_dir = Path(sys.argv[1])

    tools = {}
    tools["trufflehog"] = summarize_trufflehog(results_dir / "secrets.json")
    tools["semgrep"] = summarize_sarif(results_dir / "sast.sarif")
    tools["snyk"] = summarize_snyk(results_dir / "sca.json")

    # Checkov output name varies
    if (results_dir / "results_sarif.sarif").exists():
        tools["checkov"] = summarize_sarif(results_dir / "results_sarif.sarif")
    elif (results_dir / "checkov.sarif").exists():
        tools["checkov"] = summarize_sarif(results_dir / "checkov.sarif")
    else:
        tools["checkov"] = empty_severity()

    tools["trivy"] = summarize_sarif(results_dir / "container.sarif")

    # Aggregate totals across all tools
    totals = empty_severity()
    for tool_counts in tools.values():
        for sev, count in tool_counts.items():
            totals[sev] += count

    summary = {
        "tools": tools,
        "totals": totals,
        "total_findings": sum(totals.values()),
    }

    # Write structured JSON for downstream tools (check-thresholds, PR comments)
    summary_path = results_dir / "summary.json"
    with open(summary_path, "w") as f:
        json.dump(summary, f, indent=2)

    # Print human-readable summary
    print("\n📊 Scan Summary")
    print("=" * 45)
    print(f"{'Tool':<14} {'Crit':>5} {'High':>5} {'Med':>5} {'Low':>5} {'Total':>6}")
    print("-" * 45)
    for tool, counts in tools.items():
        t = total_for(counts)
        print(f"{tool:<14} {counts['critical']:>5} {counts['high']:>5} {counts['medium']:>5} {counts['low']:>5} {t:>6}")
    print("-" * 45)
    t = summary["total_findings"]
    print(f"{'TOTAL':<14} {totals['critical']:>5} {totals['high']:>5} {totals['medium']:>5} {totals['low']:>5} {t:>6}")
    print()

    if totals["critical"] > 0:
        print(f"\u274c {totals['critical']} critical finding(s) detected!")
    if totals["high"] > 0:
        print(f"\u26a0\ufe0f  {totals['high']} high finding(s) detected!")

    print(f"\n\u2139\ufe0f  Summary written to {summary_path}")

    # Exit code based on whether any findings exist
    if summary["total_findings"] > 0:
        sys.exit(1)
    sys.exit(0)


if __name__ == "__main__":
    main()
