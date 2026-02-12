#!/bin/bash
# FortressCI SBOM Generator
# Generates Software Bill of Materials (SBOM) for source code and containers.

set -euo pipefail

WORKSPACE=${1:-.}
OUTPUT_DIR=${2:-./results}
mkdir -p "$OUTPUT_DIR"

echo "🛡️ Generating SBOM for $WORKSPACE..."

# Generate source SBOM (SPDX)
syft dir:"$WORKSPACE" -o spdx-json > "$OUTPUT_DIR/sbom-source.spdx.json"
echo "✅ Generated $OUTPUT_DIR/sbom-source.spdx.json"

# Generate source SBOM (CycloneDX)
syft dir:"$WORKSPACE" -o cyclonedx-json > "$OUTPUT_DIR/sbom-source.cdx.json"
echo "✅ Generated $OUTPUT_DIR/sbom-source.cdx.json"

# If a Dockerfile exists, we might want to generate one for the image too, 
# but that usually happens after the build in the CI pipeline.
if [ -f "$WORKSPACE/Dockerfile" ]; then
    echo "💡 Dockerfile detected. Container SBOMs are typically generated after image build in CI."
fi
