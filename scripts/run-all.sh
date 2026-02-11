#!/bin/bash
set -e
WORKSPACE=${1:-.}
RESULTS_DIR="/results"
mkdir -p $RESULTS_DIR

echo "🏰 FortressCI Local Scan"
echo "========================"

echo "🔐 [1/6] Secret scanning (TruffleHog)..."
trufflehog filesystem $WORKSPACE --json > $RESULTS_DIR/secrets.json 2>&1 || true

echo "🔍 [2/6] SAST (Semgrep)..."
semgrep --config auto --sarif -o $RESULTS_DIR/sast.sarif $WORKSPACE || true

echo "📦 [3/6] SCA (Snyk)..."
# Snyk requires authentication, skip if token not present or handle gracefully
if [ -z "$SNYK_TOKEN" ]; then
    echo "⚠️ SNYK_TOKEN not found. Skipping Snyk scan."
else
    snyk test --json $WORKSPACE > $RESULTS_DIR/sca.json || true
fi

echo "🏗️ [4/6] IaC (Checkov)..."
checkov -d $WORKSPACE --output-file-path $RESULTS_DIR --output sarif || true

echo "🐳 [5/6] Container scan (Trivy)..."
if [ -f "$WORKSPACE/Dockerfile" ]; then
    trivy fs --scanners vuln --format sarif -o $RESULTS_DIR/container.sarif $WORKSPACE
else
    echo "No Dockerfile found. Skipping container scan."
fi

echo "🛡️ [6/6] OWASP ZAP (Baseline)..."
# ZAP is typically for running apps. We'll skip for static analysis or add a placeholder.
echo "Skipping ZAP for static analysis run."

echo ""
echo "✅ Scan complete. Results in $RESULTS_DIR/"

# Generate HTML Report
if [ -f "/usr/local/bin/generate-report.py" ]; then
    echo "📊 Generating HTML report..."
    python3 /usr/local/bin/generate-report.py $RESULTS_DIR || echo "Failed to generate report"
fi

# Generate unified summary
if [ -f "/usr/local/bin/summarize.py" ]; then
    python3 /usr/local/bin/summarize.py $RESULTS_DIR
else
    echo "Summary script not found."
fi
