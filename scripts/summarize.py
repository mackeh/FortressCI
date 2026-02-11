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

def summarize_trufflehog(path):
    data = load_json(path)
    # TruffleHog output is a stream of JSON objects, need to handle that if strictly following that format.
    # For now, assuming standard JSON array or line-delimited.
    # If line delimited:
    count = 0
    try:
        with open(path, 'r') as f:
            for line in f:
                if line.strip():
                    count += 1
    except FileNotFoundError:
        pass
    return count

def summarize_sarif(path):
    data = load_json(path)
    count = 0
    for run in data.get("runs", []):
        count += len(run.get("results", []))
    return count

def summarize_snyk(path):
    data = load_json(path)
    # Snyk can return a list or dict
    if isinstance(data, list):
        count = 0
        for project in data:
            count += len(project.get("vulnerabilities", []))
        return count
    return len(data.get("vulnerabilities", []))

def main():
    if len(sys.argv) < 2:
        print("Usage: summarize.py <results_dir>")
        sys.exit(1)

    results_dir = Path(sys.argv[1])
    
    summary = {
        "secrets": summarize_trufflehog(results_dir / "secrets.json"),
        "sast": summarize_sarif(results_dir / "sast.sarif"),
        "sca": summarize_snyk(results_dir / "sca.json"),
        "iac": summarize_sarif(results_dir / "results_sarif.sarif"), # Checkov output name might vary
        "container": summarize_sarif(results_dir / "container.sarif")
    }
    
    # Checkov specific adjustment if filename differs
    if not (results_dir / "results_sarif.sarif").exists() and (results_dir / "checkov.sarif").exists():
         summary["iac"] = summarize_sarif(results_dir / "checkov.sarif")

    print("\n📊 Scan Summary")
    print("----------------")
    print(f"🔑 Secrets:    {summary['secrets']}")
    print(f"🐛 SAST Issues: {summary['sast']}")
    print(f"📦 Dependencies: {summary['sca']}")
    print(f"🏗️ IaC Issues:  {summary['iac']}")
    print(f"🐳 Container:    {summary['container']}")
    print("----------------")
    
    total = sum(summary.values())
    print(f"Total Findings: {total}")

    if total > 0:
        sys.exit(1)
    sys.exit(0)

if __name__ == "__main__":
    main()
