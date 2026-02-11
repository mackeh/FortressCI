#!/bin/bash

# FortressCI Init Script
# Sets up FortressCI in a new project by generating tailored configurations.

echo "🏰 FortressCI Setup Wizard"
echo ""

# Detect project type
LANG="unknown"
if [ -f "package.json" ]; then echo "✓ Detected: Node.js"; LANG="node"; fi
if [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then echo "✓ Detected: Python"; LANG="python"; fi
if [ -f "go.mod" ]; then echo "✓ Detected: Go"; LANG="go"; fi
if [ -f "pom.xml" ] || [ -f "build.gradle" ]; then echo "✓ Detected: Java"; LANG="java"; fi

# Detect CI platform
CI="unknown"
if [ -d ".github/workflows" ]; then CI="github-actions"; fi
if [ -f ".gitlab-ci.yml" ]; then CI="gitlab-ci"; fi

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
    read -p "Select CI platform (github-actions/gitlab-ci): " CI_INPUT
    if [[ "$CI_INPUT" == "github-actions" || "$CI_INPUT" == "gitlab-ci" ]]; then
        CI="$CI_INPUT"
    else
        echo "Invalid selection. Defaulting to github-actions."
        CI="github-actions"
    fi
fi

# Generate files
echo "Generating configuration files..."

if [ "$CI" == "github-actions" ]; then
    mkdir -p .github/workflows
    cp "$TEMPLATES_DIR/github-actions/devsecops.yml" .github/workflows/devsecops.yml
    echo "✅ Generated .github/workflows/devsecops.yml"
elif [ "$CI" == "gitlab-ci" ]; then
    cp "$TEMPLATES_DIR/gitlab-ci/devsecops.yml" .gitlab-ci.yml
    echo "✅ Generated .gitlab-ci.yml"
fi

cp "$TEMPLATES_DIR/pre-commit-config.yaml" .pre-commit-config.yaml
echo "✅ Generated .pre-commit-config.yaml"

mkdir -p .security
cp "$TEMPLATES_DIR/waivers.yml" .security/waivers.yml
echo "✅ Generated .security/waivers.yml"

echo ""
echo "🎉 FortressCI setup complete!"
echo "Next steps:"
echo "1. Review the generated configuration files."
echo "2. Install pre-commit hooks: 'pre-commit install'"
echo "3. Add necessary secrets (SNYK_TOKEN, etc.) to your CI platform."
