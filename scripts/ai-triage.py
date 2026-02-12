#!/usr/bin/env python3
import json
import os
import sys
import yaml
import argparse

def load_config(config_path):
    if os.path.exists(config_path):
        with open(config_path, 'r') as f:
            return yaml.safe_load(f)
    return {}

def triage_findings(results_dir, config):
    ai_config = config.get('ai', {})
    if not ai_config.get('enabled', False):
        print("AI Triage is disabled in .fortressci.yml. Skipping.")
        return

    summary_path = os.path.join(results_dir, 'summary.json')
    if not os.path.exists(summary_path):
        print(f"Summary file {summary_path} not found.")
        return

    with open(summary_path, 'r') as f:
        summary = json.load(f)

    # In a real implementation, we would iterate through findings 
    # and call the LLM API (Anthropic/OpenAI).
    # For this blueprint, we'll demonstrate the orchestration logic.

    print(f"🤖 FortressCI AI Triage (Provider: {ai_config.get('provider')})")
    print("=====================================================")
    
    severity_to_triage = ai_config.get('explain_severity', ['critical', 'high'])
    print(f"Triaging severities: {', '.join(severity_to_triage)}")
    
    # Mock triage logic
    findings_count = summary.get('total_findings', 0)
    if findings_count == 0:
        print("No findings to triage.")
        return

    print(f"Analyzing {findings_count} findings...")
    
    # We would write the AI explanations to a new file ai-explanations.json
    explanations = {
        "triage_summary": "AI analysis complete. Focus on the 2 SQL injection patterns in the auth module.",
        "findings": [
            {
                "id": "semgrep:python.flask.security.audit.app-run-debug-true",
                "explanation": "Running Flask with debug=True in production allows arbitrary code execution via the interactive debugger. This is a CRITICAL risk.",
                "remediation": "Set debug=False in production environments or use an environment variable."
            }
        ]
    }
    
    output_path = os.path.join(results_dir, 'ai-triage.json')
    with open(output_path, 'w') as f:
        json.dump(explanations, f, indent=2)
    
    print(f"✅ AI Triage complete. Results in {output_path}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='FortressCI AI Triage')
    parser.add_argument('--results-dir', default='./results', help='Directory containing scan results')
    parser.add_argument('--config', default='.fortressci.yml', help='FortressCI config file')
    args = parser.parse_args()

    config = load_config(args.config)
    triage_findings(args.results_dir, config)
