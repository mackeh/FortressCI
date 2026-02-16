#!/usr/bin/env python3
# FortressCI MCP Server
# Provides tools for AI assistants to interact with FortressCI security data.

import os
import json
import asyncio
from typing import Any, Dict, List, Optional
from mcp.server.fastmcp import FastMCP

# Initialize FastMCP
mcp = FastMCP("fortressci")

RESULTS_DIR = os.getenv("FORTRESSCI_RESULTS_DIR", "./results")

@mcp.tool()
async def get_latest_scan_summary() -> str:
    """Get the latest security scan summary including severity counts."""
    summary_path = os.path.join(RESULTS_DIR, "summary.json")
    if not os.path.exists(summary_path):
        return "No scan results found."
    
    with open(summary_path, "r") as f:
        summary = json.load(f)
    
    return json.dumps(summary, indent=2)

@mcp.tool()
async def get_compliance_status() -> str:
    """Get the current compliance status (SOC2, NIST, etc.)."""
    report_path = os.path.join(RESULTS_DIR, "compliance-report.json")
    if not os.path.exists(report_path):
        return "No compliance report found."
    
    with open(report_path, "r") as f:
        report = json.load(f)
    
    return json.dumps(report, indent=2)

@mcp.tool()
async def list_active_waivers() -> str:
    """List all currently active security waivers."""
    # We could parse .security/waivers.yml here
    waiver_path = ".security/waivers.yml"
    if not os.path.exists(waiver_path):
        return "No waivers file found."
    
    # Simple read for now
    with open(waiver_path, "r") as f:
        return f.read()

@mcp.tool()
async def get_ai_triage_explanations() -> str:
    """Get AI-generated explanations for the latest security findings."""
    triage_path = os.path.join(RESULTS_DIR, "ai-triage.json")
    if not os.path.exists(triage_path):
        return "No AI triage data found."
    
    with open(triage_path, "r") as f:
        return f.read()


@mcp.tool()
async def get_devsecops_adoption_roadmap() -> str:
    """Get the latest prioritized DevSecOps adoption roadmap and feasibility scoring."""
    roadmap_path = os.path.join(RESULTS_DIR, "adoption-roadmap.json")
    if not os.path.exists(roadmap_path):
        return "No adoption roadmap found."

    with open(roadmap_path, "r") as f:
        roadmap = json.load(f)

    return json.dumps(roadmap, indent=2)

if __name__ == "__main__":
    mcp.run()
