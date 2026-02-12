#!/usr/bin/env python3
import json
import os
import sys

def build_graph(results_dir):
    summary_path = os.path.join(results_dir, 'summary.json')
    if not os.path.exists(summary_path):
        print("Summary not found.")
        return

    # In a real implementation, we would parse all SARIF files 
    # to find relationships between files, packages, and vulnerabilities.
    
    graph = {
        "nodes": [
            {"id": "Internet", "type": "entrypoint", "severity": "none"},
            {"id": "Vulnerable Endpoint", "type": "attack-surface", "severity": "high"},
            {"id": "SQL Injection", "type": "vulnerability", "severity": "critical"},
            {"id": "Sensitive Data", "type": "asset", "severity": "none"}
        ],
        "links": [
            {"source": "Internet", "target": "Vulnerable Endpoint"},
            {"source": "Vulnerable Endpoint", "target": "SQL Injection"},
            {"source": "SQL Injection", "target": "Sensitive Data"}
        ]
    }
    
    output_path = os.path.join(results_dir, 'attack-graph.json')
    with open(output_path, 'w') as f:
        json.dump(graph, f, indent=2)
    
    print(f"✅ Attack graph generated: {output_path}")

if __name__ == "__main__":
    results_dir = sys.argv[1] if len(sys.argv) > 1 else "./results"
    build_graph(results_dir)
