#!/usr/bin/env python3
import json
import os
import sys
import argparse
from pathlib import Path

def analyze_repos(base_dir):
    """
    Analyzes multiple SBOM files in a directory to find shared dependencies 
    and propagate vulnerability status.
    """
    print(f"🕸️ FortressCI Cross-Repo Dependency Analyzer")
    print(f"===========================================")
    
    # Map of dependency -> list of repos using it
    dep_map = {}
    # Map of repo -> list of its dependencies
    repo_deps = {}
    
    # Find all sbom-source.cdx.json files in subdirectories
    sbom_files = list(Path(base_dir).rglob('sbom-source.cdx.json'))
    
    if not sbom_files:
        print("No CycloneDX SBOM files found.")
        return

    for sbom_path in sbom_files:
        repo_name = sbom_path.parent.name
        print(f"Analyzing {repo_name}...")
        
        with open(sbom_path, 'r') as f:
            data = json.load(f)
            
        repo_deps[repo_name] = []
        for component in data.get('components', []):
            name = component.get('name')
            version = component.get('version')
            dep_id = f"{name}@{version}"
            
            repo_deps[repo_name].append(dep_id)
            
            if dep_id not in dep_map:
                dep_map[dep_id] = []
            dep_map[dep_id].append(repo_name)

    # Find shared dependencies
    shared = {k: v for k, v in dep_map.items() if len(v) > 1}
    
    print(f"
Found {len(repo_deps)} repositories with {len(dep_map)} unique dependencies.")
    print(f"Found {len(shared)} shared dependencies.")
    
    # Generate cross-repo report
    report = {
        "repositories": repo_deps,
        "shared_dependencies": shared,
        "analysis_summary": {
            "total_repos": len(repo_deps),
            "unique_deps": len(dep_map),
            "shared_deps": len(shared)
        }
    }
    
    output_path = os.path.join(base_dir, 'cross-repo-analysis.json')
    with open(output_path, 'w') as f:
        json.dump(report, f, indent=2)
    
    print(f"
✅ Cross-repo analysis complete: {output_path}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='FortressCI Cross-Repo Analyzer')
    parser.add_argument('--dir', default='./results', help='Base directory containing repo results')
    args = parser.parse_args()
    
    analyze_repos(args.dir)
