#!/bin/bash
# scripts/generate_keys.sh
# Helper to generate Cosign keys for FortressCI

if ! command -v cosign &> /dev/null; then
    echo "Error: cosign is not installed."
    echo "Please install it: https://docs.sigstore.dev/cosign/installation/"
    exit 1
fi

echo "Generating Cosign key pair..."
cosign generate-key-pair

echo ""
echo "✅ Keys generated: cosign.key (private) and cosign.pub (public)"
echo ""
echo "👉 ACTION REQUIRED:"
echo "1. Upload the content of 'cosign.key' to GitHub Secrets as 'COSIGN_PRIVATE_KEY'."
echo "2. Upload the content of 'cosign.pub' to GitHub Secrets as 'COSIGN_PUBLIC_KEY' (optional, for verification)."
echo "3. Commit 'cosign.pub' to the repo if you want public verification."
