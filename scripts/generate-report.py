import json
import sys
import os
from pathlib import Path
from datetime import datetime
from jinja2 import Template

def load_json(path):
    try:
        with open(path) as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {}

def parse_trufflehog(path):
    findings = []
    try:
        with open(path, 'r') as f:
            for line in f:
                if not line.strip(): continue
                try:
                    data = json.loads(line)
                    # TruffleHog format varies, adapting to common structure
                    # SourceMetadata.Data.Git.file / line
                    source = data.get("SourceMetadata", {}).get("Data", {}).get("Git", {})
                    file = source.get("file", "unknown")
                    line_no = source.get("line", 0)
                    
                    findings.append({
                        "tool": "TruffleHog",
                        "severity": "Critical", # Secrets are always critical
                        "message": f"Secret found: {data.get('DetectorName', 'Unknown detector')}",
                        "file": file,
                        "line": line_no
                    })
                except json.JSONDecodeError:
                    continue
    except FileNotFoundError:
        pass
    return findings

def parse_sarif(path, tool_name):
    findings = []
    data = load_json(path)
    for run in data.get("runs", []):
        for result in run.get("results", []):
            try:
                msg = result.get("message", {}).get("text", "No description")
                
                # Map SARIF levels to severity
                level = result.get("level", "warning")
                severity = "Medium"
                if level == "error": severity = "High"
                if level == "note": severity = "Low"
                
                # Try to get specific rule severity if available
                rule_id = result.get("ruleId", "")
                
                loc = result.get("locations", [{}])[0].get("physicalLocation", {})
                file = loc.get("artifactLocation", {}).get("uri", "unknown")
                line = loc.get("region", {}).get("startLine", 0)

                findings.append({
                    "tool": tool_name,
                    "severity": severity,
                    "message": msg,
                    "file": file,
                    "line": line,
                    "rule_id": rule_id
                })
            except Exception as e:
                print(f"Error parsing result in {path}: {e}")
                continue
    return findings

def parse_snyk(path):
    findings = []
    data = load_json(path)
    if isinstance(data, dict): data = [data] # Handle single project vs list
    
    for project in data:
        for vuln in project.get("vulnerabilities", []):
            try:
                severity = vuln.get("severity", "low").capitalize()
                msg = f"{vuln.get('packageName')}@{vuln.get('version')}: {vuln.get('title')}"
                file = vuln.get("from", ["unknown"])[0] # Approximation of source
                
                findings.append({
                    "tool": "Snyk",
                    "severity": severity,
                    "message": msg,
                    "file": project.get("displayTargetFile", file),
                    "line": 0 # Snyk often doesn't give line numbers for deps
                })
            except Exception:
                continue
    return findings

def main():
    if len(sys.argv) < 2:
        print("Usage: generate-report.py <results_dir>")
        sys.exit(1)

    results_dir = Path(sys.argv[1])
    all_findings = []

    # Parse all results
    all_findings.extend(parse_trufflehog(results_dir / "secrets.json"))
    all_findings.extend(parse_sarif(results_dir / "sast.sarif", "Semgrep"))
    all_findings.extend(parse_snyk(results_dir / "sca.json"))
    
    # Checkov might be named differently depending on run-all.sh changes
    if (results_dir / "checkov.sarif").exists():
        all_findings.extend(parse_sarif(results_dir / "checkov.sarif", "Checkov"))
    elif (results_dir / "results_sarif.sarif").exists():
        all_findings.extend(parse_sarif(results_dir / "results_sarif.sarif", "Checkov"))
        
    all_findings.extend(parse_sarif(results_dir / "container.sarif", "Trivy"))

    # Stats
    stats = {
        "critical": 0,
        "high": 0,
        "medium": 0,
        "low": 0
    }
    
    tool_counts = {}

    for f in all_findings:
        sev = f["severity"].lower()
        if sev in stats:
            stats[sev] += 1
        
        tool = f["tool"]
        tool_counts[tool] = tool_counts.get(tool, 0) + 1

    # Render Template
    # We are in /usr/local/bin, templates are likely mounted or copied.
    # For Docker, we copied templates to /usr/local/share/templates or similar? 
    # Let's assume we copy to /templates in Dockerfile
    
    template_path = Path("/templates/report.html.j2")
    if not template_path.exists():
        # Fallback for local testing
        template_path = Path("templates/report.html.j2")
        
    if not template_path.exists():
        print("Template not found!")
        sys.exit(1)

    with open(template_path) as f:
        template = Template(f.read())

    html = template.render(
        generated_at=datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        findings=all_findings,
        total=len(all_findings),
        critical=stats["critical"],
        high=stats["high"],
        medium=stats["medium"],
        low=stats["low"],
        tools=list(tool_counts.keys()),
        tool_counts=tool_counts
    )

    with open(results_dir / "report.html", "w") as f:
        f.write(html)
    
    print(f"✅ Report generated: {results_dir / 'report.html'}")

if __name__ == "__main__":
    main()
