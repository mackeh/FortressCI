#!/bin/bash

# FortressCI Init Script
# Sets up FortressCI in a new project by generating tailored configurations.

set -euo pipefail

usage() {
    cat <<'EOF'
Usage: fortressci-init.sh [--ci <platform>] [-h|--help]

Detects project language and CI platform, then copies tailored FortressCI
templates into the current directory (workflow, pre-commit, waivers,
policy, compliance-mappings, falco-rules, .fortressci.yml).

Options:
  --ci <platform>   Skip detection and force one of:
                    github-actions | gitlab-ci | bitbucket | azure | jenkins | circleci
  -h, --help        Show this help message and exit.
EOF
}

# Parse arguments
CI_ARG=""
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --ci) CI_ARG="${2:-}"; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown parameter: $1" >&2; usage >&2; exit 1 ;;
    esac
    shift
done

echo "🏰 FortressCI Setup Wizard"
echo ""

# Detect project type
LANG="unknown"
if [ -f "package.json" ]; then echo "✓ Detected: Node.js"; LANG="node"; fi
if [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then echo "✓ Detected: Python"; LANG="python"; fi
if [ -f "go.mod" ]; then echo "✓ Detected: Go"; LANG="go"; fi
if [ -f "pom.xml" ] || [ -f "build.gradle" ]; then echo "✓ Detected: Java"; LANG="java"; fi
if find . -maxdepth 5 -type f -name "*.bicep" | grep -q "."; then echo "✓ Detected: Bicep"; LANG="bicep"; fi

# Detect CI platform
CI="unknown"
if [ -n "$CI_ARG" ]; then
    CI="$CI_ARG"
else
    if [ -d ".github/workflows" ]; then CI="github-actions"; fi
    if [ -f ".gitlab-ci.yml" ]; then CI="gitlab-ci"; fi
    if [ -f "bitbucket-pipelines.yml" ]; then CI="bitbucket"; fi
    if [ -f "azure-pipelines.yml" ]; then CI="azure"; fi
    if [ -f "Jenkinsfile" ]; then CI="jenkins"; fi
    if [ -d ".circleci" ]; then CI="circleci"; fi
fi

# Determine script directory to locate templates
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
TEMPLATES_DIR="$SCRIPT_DIR/../templates"

echo ""
echo "Detected CI: $CI"
echo "Detected Language: $LANG"
echo "Templates Directory: $TEMPLATES_DIR"
echo ""

# Prompt for CI platform if not detected
if [ "$CI" == "unknown" ]; then
    echo "Could not detect CI platform."
    echo "Available options:"
    echo "  1) github-actions"
    echo "  2) gitlab-ci"
    echo "  3) bitbucket"
    echo "  4) azure"
    echo "  5) jenkins"
    echo "  6) circleci"
    read -p "Select CI platform (enter name or number): " CI_INPUT
    
    case $CI_INPUT in
        1|github-actions) CI="github-actions" ;;
        2|gitlab-ci) CI="gitlab-ci" ;;
        3|bitbucket) CI="bitbucket" ;;
        4|azure) CI="azure" ;;
        5|jenkins) CI="jenkins" ;;
        6|circleci) CI="circleci" ;;
        *) 
            echo "Invalid selection. Defaulting to github-actions."
            CI="github-actions" 
            ;;
    esac
fi

# Generate files
echo "Generating configuration files..."

case $CI in
    github-actions)
        mkdir -p .github/workflows
        cp "$TEMPLATES_DIR/github-actions/devsecops.yml" .github/workflows/devsecops.yml
        echo "✅ Generated .github/workflows/devsecops.yml"
        ;;
    gitlab-ci)
        cp "$TEMPLATES_DIR/gitlab-ci/devsecops.yml" .gitlab-ci.yml
        echo "✅ Generated .gitlab-ci.yml"
        ;;
    bitbucket)
        cp "$TEMPLATES_DIR/bitbucket/bitbucket-pipelines.yml" bitbucket-pipelines.yml
        echo "✅ Generated bitbucket-pipelines.yml"
        ;;
    azure)
        cp "$TEMPLATES_DIR/azure/azure-pipelines.yml" azure-pipelines.yml
        echo "✅ Generated azure-pipelines.yml"
        ;;
    jenkins)
        cp "$TEMPLATES_DIR/jenkins/Jenkinsfile" Jenkinsfile
        echo "✅ Generated Jenkinsfile"
        ;;
    circleci)
        mkdir -p .circleci
        cp "$TEMPLATES_DIR/circleci/config.yml" .circleci/config.yml
        echo "✅ Generated .circleci/config.yml"
        ;;
esac

cp "$TEMPLATES_DIR/pre-commit-config.yaml" .pre-commit-config.yaml
echo "✅ Generated .pre-commit-config.yaml"

mkdir -p .security
cp "$TEMPLATES_DIR/waivers.yml" .security/waivers.yml
echo "✅ Generated .security/waivers.yml"

cp "$TEMPLATES_DIR/security/policy.yml" .security/policy.yml
echo "✅ Generated .security/policy.yml"

cp "$TEMPLATES_DIR/security/compliance-mappings.yml" .security/compliance-mappings.yml
echo "✅ Generated .security/compliance-mappings.yml"

cp "$TEMPLATES_DIR/security/falco-rules.yaml" .security/falco-rules.yaml
echo "✅ Generated .security/falco-rules.yaml"

if [ ! -f ".fortressci.yml" ]; then
    cp "$TEMPLATES_DIR/fortressci.yml" .fortressci.yml
    echo "✅ Generated .fortressci.yml (thresholds & scanner config)"
fi

echo ""
echo "🎉 FortressCI setup complete!"
echo "Next steps:"
echo "1. Review the generated configuration files."
echo "2. Install pre-commit hooks: 'pre-commit install'"
echo "3. Add necessary secrets (SNYK_TOKEN, etc.) to your CI platform."
echo "4. Adjust severity thresholds in .fortressci.yml"
echo "5. Manage waivers: scripts/fortressci-waiver.sh help"
echo "6. Run health checks: scripts/fortressci-doctor.sh --workspace ."
