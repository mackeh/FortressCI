#!/usr/bin/env python3
import json
import yaml
import sys
import os
from datetime import datetime

def load_json(path):
    if os.path.exists(path):
        with open(path, 'r') as f:
            return json.load(f)
    return {}

def load_yaml(path):
    if os.path.exists(path):
        with open(path, 'r') as f:
            return yaml.safe_load(f)
    return {}

def generate_report(results_dir, mapping_file, output_file):
    summary = load_json(os.path.join(results_dir, 'summary.json'))
    mappings = load_yaml(mapping_file)
    
    if not summary or not mappings:
        print("Error: Summary or Mappings not found.")
        return

    report = {
        "generated_at": datetime.utcnow().isoformat() + "Z",
        "project": os.path.basename(os.getcwd()),
        "overall_status": "PASS" if summary.get('total_findings', 0) == 0 else "REVIEW_REQUIRED",
        "framework_summary": {},
        "findings": []
    }

    # Simplified mapping logic for demo
    for m in mappings.get('mappings', []):
        tool = m.get('tool')
        if tool in summary.get('scanners', {}):
            tool_results = summary['scanners'][tool]
            for fw in m.get('frameworks', []):
                fw_name = fw.get('framework')
                if fw_name not in report['framework_summary']:
                    report['framework_summary'][fw_name] = {"status": "PASS", "findings_count": 0}
                
                if tool_results.get('critical', 0) > 0 or tool_results.get('high', 0) > 0:
                    report['framework_summary'][fw_name]['status'] = "FAIL"
                
                report['framework_summary'][fw_name]['findings_count'] += tool_results.get('total', 0)

    with open(output_file, 'w') as f:
        json.dump(report, f, indent=2)
    
    print(f"✅ Compliance report generated: {output_file}")

if __name__ == "__main__":
    results_dir = sys.argv[1] if len(sys.argv) > 1 else "./results"
    mapping_file = sys.argv[2] if len(sys.argv) > 2 else ".security/compliance-mappings.yml"
    output_file = os.path.join(results_dir, 'compliance-report.json')
    generate_report(results_dir, mapping_file, output_file)
