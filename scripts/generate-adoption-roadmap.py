#!/usr/bin/env python3
"""Generate a practical DevSecOps adoption roadmap from FortressCI artifacts."""

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List

SEVERITY_LEVELS = ("critical", "high", "medium", "low")
KNOWN_SCANNERS = ("secrets", "sast", "sca", "iac", "container", "dast")
TOOL_TO_SCANNER = {
    "trufflehog": "secrets",
    "semgrep": "sast",
    "snyk": "sca",
    "checkov": "iac",
    "bicep": "iac",
    "trivy": "container",
    "zap": "dast",
}


def clamp(value: float, minimum: int = 0, maximum: int = 100) -> int:
    return int(max(minimum, min(maximum, round(value))))


def load_json(path: Path) -> Dict[str, Any]:
    try:
        with path.open("r", encoding="utf-8") as handle:
            data = json.load(handle)
        return data if isinstance(data, dict) else {}
    except (FileNotFoundError, json.JSONDecodeError):
        return {}


def parse_scalar(raw_value: str) -> Any:
    value = raw_value.strip()
    if value.lower() in {"true", "yes", "on"}:
        return True
    if value.lower() in {"false", "no", "off"}:
        return False
    if value.lower() in {"null", "none"}:
        return None
    if value.startswith(("'", '"')) and value.endswith(("'", '"')) and len(value) >= 2:
        return value[1:-1]
    try:
        if "." in value:
            return float(value)
        return int(value)
    except ValueError:
        return value


def parse_simple_yaml(content: str) -> Dict[str, Any]:
    """Parse a small YAML subset used by FortressCI config templates."""
    root: Dict[str, Any] = {}
    stack: List[tuple[int, Dict[str, Any]]] = [(-1, root)]

    for raw_line in content.splitlines():
        no_comment = raw_line.split("#", 1)[0].rstrip()
        if not no_comment.strip():
            continue

        indent = len(raw_line) - len(raw_line.lstrip(" "))
        stripped = no_comment.strip()
        if ":" not in stripped:
            continue

        key, raw_value = stripped.split(":", 1)
        key = key.strip()
        value = raw_value.strip()

        while stack and indent <= stack[-1][0]:
            stack.pop()
        parent = stack[-1][1] if stack else root

        if value == "":
            nested: Dict[str, Any] = {}
            parent[key] = nested
            stack.append((indent, nested))
            continue

        parent[key] = parse_scalar(value)

    return root


def load_yaml(path: Path) -> Dict[str, Any]:
    if not path.exists():
        return {}

    content = path.read_text(encoding="utf-8")
    try:
        import yaml  # type: ignore

        data = yaml.safe_load(content)
        return data if isinstance(data, dict) else {}
    except Exception:
        return parse_simple_yaml(content)


def detect_ci_platform(workspace: Path) -> str:
    ci_markers = {
        "github-actions": workspace / ".github" / "workflows",
        "gitlab-ci": workspace / ".gitlab-ci.yml",
        "circleci": workspace / ".circleci" / "config.yml",
        "bitbucket": workspace / "bitbucket-pipelines.yml",
        "azure": workspace / "azure-pipelines.yml",
        "jenkins": workspace / "Jenkinsfile",
    }
    for ci_name, marker in ci_markers.items():
        if marker.exists():
            return ci_name
    return "unknown"


def scanner_coverage(config: Dict[str, Any], summary: Dict[str, Any]) -> Dict[str, Any]:
    scanners = config.get("scanners", {})
    enabled: List[str] = []
    disabled: List[str] = []

    for scanner in KNOWN_SCANNERS:
        scanner_cfg = scanners.get(scanner, {})
        if isinstance(scanner_cfg, dict) and scanner_cfg.get("enabled") is True:
            enabled.append(scanner)
        else:
            disabled.append(scanner)

    # Fallback for repositories with minimal/no scanner config.
    if not enabled and summary.get("tools"):
        for tool_name in summary.get("tools", {}).keys():
            mapped = TOOL_TO_SCANNER.get(str(tool_name).lower())
            if mapped and mapped not in enabled:
                enabled.append(mapped)
                if mapped in disabled:
                    disabled.remove(mapped)

    score = clamp((len(enabled) / len(KNOWN_SCANNERS)) * 100)
    return {"enabled": sorted(enabled), "disabled": sorted(disabled), "score": score}


def normalized_totals(summary: Dict[str, Any]) -> Dict[str, int]:
    totals = summary.get("totals", {})
    return {level: int(totals.get(level, 0) or 0) for level in SEVERITY_LEVELS}


def build_dimensions(
    workspace: Path,
    results_dir: Path,
    config: Dict[str, Any],
    summary: Dict[str, Any],
    coverage: Dict[str, Any],
) -> Dict[str, int]:
    totals = normalized_totals(summary)
    risk_pressure = (
        totals["critical"] * 14
        + totals["high"] * 6
        + totals["medium"] * 2
        + totals["low"] * 0.5
    )

    policy_exists = (workspace / ".security" / "policy.yml").exists()
    waivers_exists = (workspace / ".security" / "waivers.yml").exists()
    precommit_exists = (workspace / ".pre-commit-config.yaml").exists()
    ci_known = detect_ci_platform(workspace) != "unknown"

    thresholds = config.get("thresholds", {})
    fail_on = str(thresholds.get("fail_on", "none")).lower()
    warn_on = str(thresholds.get("warn_on", "none")).lower()
    waiver_cfg = config.get("waivers", {})
    waiver_approval = waiver_cfg.get("require_approval") is True

    governance_score = clamp(
        15
        + (30 if policy_exists else 0)
        + (15 if waivers_exists else 0)
        + (20 if fail_on != "none" else 0)
        + (10 if warn_on != "none" else 0)
        + (10 if waiver_approval else 0)
    )
    automation_score = clamp(
        20
        + (45 if ci_known else 0)
        + (20 if precommit_exists else 0)
        + (15 if summary else 0)
    )
    ai_enabled = bool(config.get("ai", {}).get("enabled"))
    insight_score = clamp(
        10
        + (25 if (results_dir / "summary.json").exists() else 0)
        + (25 if (results_dir / "compliance-report.json").exists() else 0)
        + (20 if (results_dir / "badge.json").exists() else 0)
        + (20 if ai_enabled else 0)
    )
    hygiene_score = clamp(100 - risk_pressure)

    return {
        "coverage": coverage["score"],
        "governance": governance_score,
        "automation": automation_score,
        "insight": insight_score,
        "hygiene": hygiene_score,
    }


def score_overall(
    dimensions: Dict[str, int], totals: Dict[str, int], quick_wins: int, missing_foundations: int
) -> Dict[str, int]:
    maturity = clamp(
        dimensions["coverage"] * 0.26
        + dimensions["governance"] * 0.22
        + dimensions["automation"] * 0.2
        + dimensions["insight"] * 0.14
        + dimensions["hygiene"] * 0.18
    )
    backlog_pressure = totals["critical"] * 12 + totals["high"] * 5 + totals["medium"] * 1.5
    foundation_penalty = missing_foundations * 7
    quick_win_bonus = min(12, quick_wins * 2)
    feasibility = clamp(
        70
        - backlog_pressure
        - foundation_penalty
        + quick_win_bonus
        + ((dimensions["automation"] - 50) * 0.12)
        + ((dimensions["governance"] - 50) * 0.1),
        minimum=15,
        maximum=95,
    )
    return {"maturity": maturity, "feasibility": feasibility}


def add_action(
    actions: List[Dict[str, Any]],
    action_id: str,
    title: str,
    description: str,
    impact: int,
    feasibility: int,
    effort: str,
    urgency: int,
    commands: List[str],
    success_metric: str,
) -> None:
    priority = clamp(impact * 0.5 + feasibility * 0.3 + urgency * 0.2)
    if effort == "S":
        horizon = "days_0_7"
    elif effort == "M":
        horizon = "days_8_30"
    else:
        horizon = "days_31_90"

    actions.append(
        {
            "id": action_id,
            "title": title,
            "description": description,
            "impact": impact,
            "feasibility": feasibility,
            "effort": effort,
            "urgency": urgency,
            "priority": priority,
            "horizon": horizon,
            "commands": commands,
            "success_metric": success_metric,
        }
    )


def build_actions(
    workspace: Path, results_dir: Path, config: Dict[str, Any], totals: Dict[str, int], coverage: Dict[str, Any]
) -> List[Dict[str, Any]]:
    actions: List[Dict[str, Any]] = []
    fail_on = str(config.get("thresholds", {}).get("fail_on", "none")).lower()
    ai_enabled = bool(config.get("ai", {}).get("enabled"))

    if totals["critical"] > 0 or totals["high"] > 0:
        add_action(
            actions,
            "remediate-critical-findings",
            "Burn Down Critical + High Findings",
            "Reduce breach probability by fixing the highest-severity backlog first.",
            impact=96,
            feasibility=74,
            effort="M",
            urgency=95,
            commands=["./scripts/run-all.sh .", "./scripts/check-thresholds.sh results/ .fortressci.yml"],
            success_metric="Critical and high findings trend down week-over-week.",
        )

    if fail_on == "none":
        add_action(
            actions,
            "enforce-threshold-gates",
            "Turn On Blocking Security Gates",
            "Move from visibility-only to enforceable policy by failing builds above tolerance.",
            impact=90,
            feasibility=88,
            effort="S",
            urgency=90,
            commands=["./scripts/check-thresholds.sh results/ .fortressci.yml"],
            success_metric="CI fails when finding severity exceeds agreed threshold.",
        )

    if not (workspace / ".security" / "policy.yml").exists():
        add_action(
            actions,
            "policy-as-code-foundation",
            "Establish Policy-as-Code Baseline",
            "Create auditable and repeatable security requirements across all repos.",
            impact=87,
            feasibility=84,
            effort="S",
            urgency=80,
            commands=["./scripts/fortressci-init.sh", "./scripts/fortressci-policy-check.sh .security/policy.yml results/"],
            success_metric="Policy checks run and produce pass/fail outcomes in CI.",
        )

    if not (workspace / ".pre-commit-config.yaml").exists():
        add_action(
            actions,
            "left-shift-precommit",
            "Adopt Pre-Commit Guardrails",
            "Catch secrets and policy violations before they reach pull requests.",
            impact=80,
            feasibility=92,
            effort="S",
            urgency=78,
            commands=["pre-commit install", "pre-commit run --all-files"],
            success_metric="Engineers run local hooks with stable pass rates.",
        )

    if coverage["disabled"]:
        disabled = ", ".join(coverage["disabled"])
        add_action(
            actions,
            "close-scanner-coverage-gaps",
            "Close Scanner Coverage Gaps",
            f"Improve threat coverage by enabling: {disabled}.",
            impact=84,
            feasibility=72,
            effort="M",
            urgency=76,
            commands=["./scripts/fortressci-init.sh", "./scripts/run-all.sh ."],
            success_metric="All planned scanners run and report in summary.json.",
        )

    if not ai_enabled:
        add_action(
            actions,
            "enable-ai-triage",
            "Enable AI Triage for Faster Prioritization",
            "Speed up remediation by generating explanations for top-risk findings.",
            impact=70,
            feasibility=82,
            effort="S",
            urgency=60,
            commands=["python3 scripts/ai-triage.py --results-dir results/ --config .fortressci.yml"],
            success_metric="AI triage output is produced for critical/high findings.",
        )

    if not (results_dir / "compliance-report.json").exists():
        add_action(
            actions,
            "compliance-evidence-pack",
            "Generate Compliance Evidence Pack",
            "Translate security controls into SOC2/NIST evidence for audits and customer trust.",
            impact=68,
            feasibility=86,
            effort="S",
            urgency=55,
            commands=["python3 scripts/generate-compliance-report.py results/ .security/compliance-mappings.yml"],
            success_metric="Compliance report exists and maps findings to frameworks.",
        )

    if not (results_dir / "sbom-source.spdx.json").exists() and not (results_dir / "sbom-source.cdx.json").exists():
        add_action(
            actions,
            "sbom-baseline",
            "Establish SBOM Baseline",
            "Improve supply-chain visibility and vulnerability response times.",
            impact=66,
            feasibility=90,
            effort="S",
            urgency=52,
            commands=["./scripts/generate-sbom.sh . results/"],
            success_metric="SBOM is generated for each build and archived as artifact.",
        )

    if not actions:
        add_action(
            actions,
            "continuous-improvement-loop",
            "Run Weekly Security Improvement Loop",
            "Keep maturity improving by reviewing trends and retiring recurring root causes.",
            impact=62,
            feasibility=88,
            effort="S",
            urgency=40,
            commands=["./scripts/run-all.sh .", "python3 scripts/generate-adoption-roadmap.py --results-dir results/ --workspace ."],
            success_metric="Maturity score improves over a rolling 4-week period.",
        )

    actions.sort(key=lambda item: item["priority"], reverse=True)
    return actions


def build_roadmap(actions: List[Dict[str, Any]]) -> Dict[str, List[Dict[str, Any]]]:
    buckets = {"days_0_7": [], "days_8_30": [], "days_31_90": []}
    for action in actions:
        buckets[action["horizon"]].append(
            {"id": action["id"], "title": action["title"], "priority": action["priority"]}
        )
    return buckets


def risk_narrative(totals: Dict[str, int]) -> List[str]:
    notes: List[str] = []
    if totals["critical"] > 0:
        notes.append(
            f"{totals['critical']} critical finding(s) create immediate release risk."
        )
    if totals["high"] > 0:
        notes.append(f"{totals['high']} high finding(s) should be remediated in the next sprint.")
    if totals["critical"] == 0 and totals["high"] == 0:
        notes.append("No critical/high findings detected; focus can shift to structural hardening.")
    if totals["medium"] > 20:
        notes.append("Medium finding volume indicates recurring secure-coding debt.")
    return notes


def generate_markdown(report: Dict[str, Any]) -> str:
    scores = report["scores"]
    dims = scores["dimensions"]
    lines = [
        "# FortressCI DevSecOps Adoption Roadmap",
        "",
        f"Generated: {report['generated_at']}",
        f"Workspace: `{report['workspace']}`",
        "",
        "## Snapshot",
        "",
        f"- DevSecOps maturity score: **{scores['devsecops_maturity']} / 100**",
        f"- Adoption feasibility score: **{scores['adoption_feasibility']} / 100**",
        f"- CI platform detected: **{report['current_state']['ci_platform']}**",
        f"- Enabled scanners: **{', '.join(report['current_state']['scanner_coverage']['enabled']) or 'none'}**",
        "",
        "## Dimension Scores",
        "",
        "| Dimension | Score |",
        "|---|---:|",
        f"| Coverage | {dims['coverage']} |",
        f"| Governance | {dims['governance']} |",
        f"| Automation | {dims['automation']} |",
        f"| Insight | {dims['insight']} |",
        f"| Hygiene | {dims['hygiene']} |",
        "",
        "## Priority Actions",
        "",
        "| Priority | Action | Effort | Horizon |",
        "|---:|---|---|---|",
    ]

    for action in report["recommended_actions"][:10]:
        lines.append(
            f"| {action['priority']} | {action['title']} | {action['effort']} | {action['horizon']} |"
        )

    lines.extend(
        [
            "",
            "## 30/60/90 Plan",
            "",
            "### Days 0-7",
        ]
    )
    for item in report["roadmap_30_60_90"]["days_0_7"] or []:
        lines.append(f"- {item['title']} (`{item['id']}`)")

    lines.extend(["", "### Days 8-30"])
    for item in report["roadmap_30_60_90"]["days_8_30"] or []:
        lines.append(f"- {item['title']} (`{item['id']}`)")

    lines.extend(["", "### Days 31-90"])
    for item in report["roadmap_30_60_90"]["days_31_90"] or []:
        lines.append(f"- {item['title']} (`{item['id']}`)")

    lines.extend(["", "## Risk Narrative"])
    for note in report["risk_narrative"]:
        lines.append(f"- {note}")

    return "\n".join(lines) + "\n"


def build_report(results_dir: Path, workspace: Path, config_path: Path) -> Dict[str, Any]:
    summary = load_json(results_dir / "summary.json")
    totals = normalized_totals(summary)
    config = load_yaml(config_path)
    coverage = scanner_coverage(config, summary)
    actions = build_actions(workspace, results_dir, config, totals, coverage)
    quick_wins = len([action for action in actions if action["horizon"] == "days_0_7"])
    dimensions = build_dimensions(workspace, results_dir, config, summary, coverage)
    missing_foundations = 0
    if detect_ci_platform(workspace) == "unknown":
        missing_foundations += 1
    if not (workspace / ".pre-commit-config.yaml").exists():
        missing_foundations += 1
    if not (workspace / ".security" / "policy.yml").exists():
        missing_foundations += 1
    if not (workspace / ".security" / "waivers.yml").exists():
        missing_foundations += 1
    if str(config.get("thresholds", {}).get("fail_on", "none")).lower() == "none":
        missing_foundations += 1
    overall_scores = score_overall(dimensions, totals, quick_wins, missing_foundations)

    return {
        "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "workspace": str(workspace.resolve()),
        "results_dir": str(results_dir.resolve()),
        "scores": {
            "devsecops_maturity": overall_scores["maturity"],
            "adoption_feasibility": overall_scores["feasibility"],
            "dimensions": dimensions,
        },
        "current_state": {
            "ci_platform": detect_ci_platform(workspace),
            "scanner_coverage": coverage,
            "totals": totals,
            "total_findings": sum(totals.values()),
        },
        "risk_narrative": risk_narrative(totals),
        "recommended_actions": actions,
        "roadmap_30_60_90": build_roadmap(actions),
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate a DevSecOps adoption roadmap.")
    parser.add_argument(
        "--results-dir",
        default="results",
        help="Directory containing FortressCI scan artifacts.",
    )
    parser.add_argument(
        "--workspace",
        default=".",
        help="Workspace root where FortressCI config files live.",
    )
    parser.add_argument(
        "--config",
        default=".fortressci.yml",
        help="Path to FortressCI config file.",
    )
    parser.add_argument(
        "--output-json",
        default=None,
        help="Path to output roadmap JSON (default: <results-dir>/adoption-roadmap.json).",
    )
    parser.add_argument(
        "--output-md",
        default=None,
        help="Path to output roadmap Markdown (default: <results-dir>/adoption-roadmap.md).",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    results_dir = Path(args.results_dir)
    workspace = Path(args.workspace)
    config_path = Path(args.config)

    output_json = Path(args.output_json) if args.output_json else results_dir / "adoption-roadmap.json"
    output_md = Path(args.output_md) if args.output_md else results_dir / "adoption-roadmap.md"

    results_dir.mkdir(parents=True, exist_ok=True)
    report = build_report(results_dir, workspace, config_path)

    output_json.parent.mkdir(parents=True, exist_ok=True)
    output_json.write_text(json.dumps(report, indent=2), encoding="utf-8")

    markdown = generate_markdown(report)
    output_md.parent.mkdir(parents=True, exist_ok=True)
    output_md.write_text(markdown, encoding="utf-8")

    print(f"Generated roadmap JSON: {output_json}")
    print(f"Generated roadmap Markdown: {output_md}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
