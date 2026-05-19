#!/bin/bash
# scripts/generate_keys.sh
# Helper to generate Cosign keys for FortressCI

set -euo pipefail

usage() {
    cat <<'EOF'
Usage: generate_keys.sh [-h|--help]

Generates a Cosign key pair (cosign.key + cosign.pub) in the current
directory and prints the next-step instructions for storing them as
CI secrets.

Requires the cosign CLI to be installed. Refuses to overwrite an
existing cosign.key in the current directory.
EOF
}

case "${1:-}" in
    -h|--help) usage; exit 0 ;;
    "") ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
esac

if ! command -v cosign &> /dev/null; then
    echo "Error: cosign is not installed." >&2
    echo "Please install it: https://docs.sigstore.dev/cosign/installation/" >&2
    exit 1
fi

if [ -e "cosign.key" ]; then
    echo "Error: cosign.key already exists in the current directory." >&2
    echo "Refusing to overwrite. Move or remove it first." >&2
    exit 1
fi

echo "Generating Cosign key pair..."
cosign generate-key-pair

if [ ! -f "cosign.key" ] || [ ! -f "cosign.pub" ]; then
    echo "Error: cosign did not produce the expected key files." >&2
    exit 1
fi

echo ""
echo "✅ Keys generated: cosign.key (private) and cosign.pub (public)"
echo ""
echo "👉 ACTION REQUIRED:"
echo "1. Upload the content of 'cosign.key' to GitHub Secrets as 'COSIGN_PRIVATE_KEY'."
echo "2. Upload the content of 'cosign.pub' to GitHub Secrets as 'COSIGN_PUBLIC_KEY' (optional, for verification)."
echo "3. Commit 'cosign.pub' to the repo if you want public verification."
echo "4. Add 'cosign.key' to .gitignore — never commit the private key."
