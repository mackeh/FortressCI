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

echo "📦 [6/6] SBOM Generation (Syft)..."
if [ -f "/usr/local/bin/generate-sbom" ]; then
    bash /usr/local/bin/generate-sbom "$WORKSPACE" "$RESULTS_DIR"
else
    # Local run outside of docker context fallback
    if [ -f "scripts/generate-sbom.sh" ]; then
        bash scripts/generate-sbom.sh "$WORKSPACE" "$RESULTS_DIR"
    fi
fi

echo "🛡️ [7/7] OWASP ZAP (Baseline)..."
# ZAP is typically for running apps. We'll skip for static analysis or add a placeholder.
echo "Skipping ZAP for static analysis run."

echo ""
echo "✅ Scan complete. Results in $RESULTS_DIR/"

# Generate HTML Report
if [ -f "/usr/local/bin/generate-report.py" ]; then
    echo "📊 Generating HTML report..."
    python3 /usr/local/bin/generate-report.py $RESULTS_DIR || echo "Failed to generate report"
fi

# Generate unified summary (produces summary.json)
if [ -f "/usr/local/bin/summarize.py" ]; then
    python3 /usr/local/bin/summarize.py $RESULTS_DIR || true
else
    echo "Summary script not found."
fi

# Run threshold gating if config exists
if [ -f "$WORKSPACE/.fortressci.yml" ] && [ -f "/usr/local/bin/check-thresholds.sh" ]; then
    echo ""
    echo "🔒 Running threshold checks..."
    bash /usr/local/bin/check-thresholds.sh "$RESULTS_DIR" "$WORKSPACE/.fortressci.yml"
fi

# Run policy check if config exists
if [ -f "$WORKSPACE/.security/policy.yml" ] && [ -f "/usr/local/bin/fortressci-policy-check" ]; then
    echo ""
    echo "🛡️ Running policy checks..."
    bash /usr/local/bin/fortressci-policy-check "$WORKSPACE/.security/policy.yml" "$RESULTS_DIR"
elif [ -f "scripts/fortressci-policy-check.sh" ]; then
    echo ""
    echo "🛡️ Running policy checks (local)..."
    bash scripts/fortressci-policy-check.sh "$WORKSPACE/.security/policy.yml" "$RESULTS_DIR"
fi
