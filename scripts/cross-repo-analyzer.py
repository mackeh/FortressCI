#!/usr/bin/env python3
"""FortressCI cross-repo dependency analyzer.

Scans one base directory for CycloneDX SBOM files (default: sbom-source.cdx.json),
aggregates shared dependencies across repositories, and correlates Snyk findings
when sibling sca.json files are available.
"""

import argparse
import json
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def load_json(path: Path) -> dict[str, Any]:
    try:
        with path.open("r", encoding="utf-8") as handle:
            data = json.load(handle)
            return data if isinstance(data, dict) else {}
    except (OSError, json.JSONDecodeError):
        return {}


def normalize_repo_name(base_dir: Path, sbom_path: Path) -> str:
    rel_parent = sbom_path.parent.relative_to(base_dir)
    if str(rel_parent) == ".":
        return "root"
    return str(rel_parent)


def component_identity(component: dict[str, Any]) -> tuple[str, str, str]:
    name = str(component.get("name") or "").strip()
    version = str(component.get("version") or "").strip()
    purl = str(component.get("purl") or "").strip()

    if purl:
        dep_id = purl
    elif name and version:
        dep_id = f"{name}@{version}"
    elif name:
        dep_id = name
    else:
        dep_id = str(component.get("bom-ref") or "unknown-component").strip()

    return dep_id, name.lower(), version.lower()


def build_aliases(dep_id: str, name: str, version: str) -> set[str]:
    aliases: set[str] = {dep_id.lower()}
    if name:
        aliases.add(name)
        if version:
            aliases.add(f"{name}@{version}")
    return aliases


def parse_sca_vulnerabilities(sca_path: Path) -> list[dict[str, str]]:
    data: Any
    try:
        with sca_path.open("r", encoding="utf-8") as handle:
            data = json.load(handle)
    except (OSError, json.JSONDecodeError):
        return []

    projects = data if isinstance(data, list) else [data]
    normalized: list[dict[str, str]] = []

    for project in projects:
        if not isinstance(project, dict):
            continue
        for vuln in project.get("vulnerabilities", []):
            if not isinstance(vuln, dict):
                continue
            pkg = str(
                vuln.get("packageName")
                or vuln.get("package")
                or vuln.get("name")
                or ""
            ).strip().lower()
            version = str(vuln.get("version") or "").strip().lower()
            if pkg:
                normalized.append({"package": pkg, "version": version})

    return normalized


def analyze_repos(base_dir: Path, sbom_name: str, top_n: int, quiet: bool) -> tuple[dict[str, Any], int]:
    sbom_files = sorted(base_dir.rglob(sbom_name))
    if not sbom_files:
        message = f"No SBOM files named '{sbom_name}' found under {base_dir}."
        return {"error": message}, 1

    repo_deps: dict[str, set[str]] = defaultdict(set)
    repo_vuln_deps: dict[str, set[str]] = defaultdict(set)
    dep_to_repos: dict[str, set[str]] = defaultdict(set)
    repo_aliases: dict[str, dict[str, set[str]]] = defaultdict(lambda: defaultdict(set))

    sca_file_count = 0

    for sbom_path in sbom_files:
        repo_name = normalize_repo_name(base_dir, sbom_path)
        sbom_data = load_json(sbom_path)
        components = sbom_data.get("components", [])
        if not isinstance(components, list):
            components = []

        if not quiet:
            print(f"Analyzing {repo_name} ({sbom_path})")

        for component in components:
            if not isinstance(component, dict):
                continue
            dep_id, name, version = component_identity(component)
            repo_deps[repo_name].add(dep_id)
            dep_to_repos[dep_id].add(repo_name)
            for alias in build_aliases(dep_id, name, version):
                repo_aliases[repo_name][alias].add(dep_id)

        sca_path = sbom_path.parent / "sca.json"
        if not sca_path.exists():
            continue

        sca_file_count += 1
        vulnerabilities = parse_sca_vulnerabilities(sca_path)
        for vuln in vulnerabilities:
            pkg = vuln["package"]
            version = vuln["version"]
            candidate_aliases = {pkg}
            if version:
                candidate_aliases.add(f"{pkg}@{version}")

            for alias in candidate_aliases:
                repo_vuln_deps[repo_name].update(repo_aliases[repo_name].get(alias, set()))

    shared = {dep: sorted(repos) for dep, repos in dep_to_repos.items() if len(repos) > 1}
    shared_details = []
    for dep, repos in shared.items():
        vulnerable_repos = sorted([repo for repo in repos if dep in repo_vuln_deps.get(repo, set())])
        shared_details.append(
            {
                "dependency": dep,
                "repository_count": len(repos),
                "repositories": repos,
                "vulnerable_in_repositories": vulnerable_repos,
                "vulnerable_repository_count": len(vulnerable_repos),
            }
        )

    shared_details.sort(
        key=lambda item: (
            -item["vulnerable_repository_count"],
            -item["repository_count"],
            item["dependency"],
        )
    )

    repositories_report = {repo: sorted(deps) for repo, deps in repo_deps.items()}
    vulnerable_dep_report = {repo: sorted(deps) for repo, deps in repo_vuln_deps.items() if deps}

    report: dict[str, Any] = {
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "base_dir": str(base_dir.resolve()),
        "sbom_file_name": sbom_name,
        "repositories": repositories_report,
        "shared_dependencies": shared,
        "shared_dependency_details": shared_details,
        "top_shared_risk_hotspots": shared_details[:top_n],
        "repositories_vulnerable_dependencies": vulnerable_dep_report,
        "analysis_summary": {
            "total_repos": len(repositories_report),
            "repos_with_sca": sca_file_count,
            "unique_deps": len(dep_to_repos),
            "shared_deps": len(shared),
            "shared_deps_with_known_vulns": sum(
                1 for item in shared_details if item["vulnerable_repository_count"] > 0
            ),
        },
    }

    if not quiet:
        summary = report["analysis_summary"]
        print("")
        print(f"Found {summary['total_repos']} repositories with {summary['unique_deps']} unique dependencies.")
        print(f"Found {summary['shared_deps']} shared dependencies.")
        print(
            f"Found {summary['shared_deps_with_known_vulns']} shared dependencies "
            f"with known vulnerabilities from Snyk results."
        )

    return report, 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="FortressCI Cross-Repo Analyzer")
    parser.add_argument(
        "--dir",
        default="./results",
        help="Base directory containing repository result directories",
    )
    parser.add_argument(
        "--sbom-name",
        default="sbom-source.cdx.json",
        help="SBOM filename to search for recursively",
    )
    parser.add_argument(
        "--output",
        default="",
        help="Output file path. Defaults to <dir>/cross-repo-analysis.json",
    )
    parser.add_argument(
        "--top",
        type=int,
        default=20,
        help="Number of high-priority shared dependencies to include in top_shared_risk_hotspots",
    )
    parser.add_argument(
        "--quiet",
        action="store_true",
        help="Suppress progress logging",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    base_dir = Path(args.dir).resolve()
    output_path = Path(args.output).resolve() if args.output else base_dir / "cross-repo-analysis.json"
    top_n = max(args.top, 1)

    report, exit_code = analyze_repos(base_dir, args.sbom_name, top_n, args.quiet)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2)

    if exit_code == 0:
        print(f"Cross-repo analysis complete: {output_path}")
    else:
        print(report.get("error", "Cross-repo analysis failed."))
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
