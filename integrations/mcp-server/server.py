#!/usr/bin/env python3
# FortressCI MCP Server
# Provides tools for AI assistants to interact with FortressCI security data.

import json
import logging
import os

from mcp.server.fastmcp import FastMCP

logging.basicConfig(
    level=os.getenv("FORTRESSCI_MCP_LOG_LEVEL", "INFO"),
    format="%(asctime)s %(levelname)s fortressci-mcp: %(message)s",
)
log = logging.getLogger("fortressci-mcp")

mcp = FastMCP("fortressci")

RESULTS_DIR = os.getenv("FORTRESSCI_RESULTS_DIR", "./results")
WAIVERS_PATH = os.getenv("FORTRESSCI_WAIVERS_PATH", ".security/waivers.yml")


def _read_text(path: str) -> str:
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def _read_json(path: str) -> str:
    """Read a JSON artifact and re-serialize it pretty-printed.

    Returns a human-readable error string instead of raising so the
    MCP tool call always produces output the assistant can reason about.
    """
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except FileNotFoundError:
        return f"File not found: {path}"
    except PermissionError:
        log.warning("permission denied reading %s", path)
        return f"Permission denied reading {path}."
    except json.JSONDecodeError as e:
        log.warning("malformed json in %s: %s", path, e)
        return f"Malformed JSON in {path}: {e}"
    except OSError as e:
        log.warning("os error reading %s: %s", path, e)
        return f"Could not read {path}: {e}"
    return json.dumps(data, indent=2)


@mcp.tool()
async def get_latest_scan_summary() -> str:
    """Get the latest security scan summary including severity counts."""
    return _read_json(os.path.join(RESULTS_DIR, "summary.json"))


@mcp.tool()
async def get_compliance_status() -> str:
    """Get the current compliance status (SOC2, NIST, etc.)."""
    return _read_json(os.path.join(RESULTS_DIR, "compliance-report.json"))


@mcp.tool()
async def list_active_waivers() -> str:
    """List all currently active security waivers (raw YAML)."""
    if not os.path.exists(WAIVERS_PATH):
        return f"No waivers file found at {WAIVERS_PATH}."
    try:
        return _read_text(WAIVERS_PATH)
    except OSError as e:
        log.warning("could not read waivers file %s: %s", WAIVERS_PATH, e)
        return f"Could not read {WAIVERS_PATH}: {e}"


@mcp.tool()
async def get_ai_triage_explanations() -> str:
    """Get AI-generated explanations for the latest security findings."""
    path = os.path.join(RESULTS_DIR, "ai-triage.json")
    if not os.path.exists(path):
        return "No AI triage data found."
    try:
        return _read_text(path)
    except OSError as e:
        log.warning("could not read triage file %s: %s", path, e)
        return f"Could not read {path}: {e}"


@mcp.tool()
async def get_devsecops_adoption_roadmap() -> str:
    """Get the latest prioritized DevSecOps adoption roadmap and feasibility scoring."""
    return _read_json(os.path.join(RESULTS_DIR, "adoption-roadmap.json"))


if __name__ == "__main__":
    mcp.run()
