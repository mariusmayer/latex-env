#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detect platform
ARCH=$(uname -m)
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
echo "Detected platform: ${ARCH}-${OS}"

# Require active conda env
if [ -z "${CONDA_PREFIX:-}" ]; then
    echo "Error: no conda environment is active. Activate latex-env first." >&2
    exit 1
fi

# Define install root
TL_ROOT="$CONDA_PREFIX/texlive"
TL_CACHE="$CONDA_PREFIX/.cache/tl"
TL_PROFILE="$TL_CACHE/texlive.profile"
mkdir -p "$TL_CACHE"

# Write install profile
cat > "$TL_PROFILE" <<EOF
selected_scheme scheme-small
TEXDIR $TL_ROOT
TEXMFCONFIG $TL_ROOT/texmf-config
TEXMFVAR $TL_ROOT/texmf-var
TEXMFHOME $TL_ROOT/texmf-home
TEXMFLOCAL $TL_ROOT/texmf-local
TEXMFSYSCONFIG $TL_ROOT/texmf-sys-config
TEXMFSYSVAR $TL_ROOT/texmf-sys-var
binary_${ARCH}-${OS} 1
collection-basic 1
collection-latex 1
collection-latexrecommended 1
collection-fontsrecommended 1
instopt_adjustpath 0
instopt_letter 0
instopt_portable 0
instopt_write18_restricted 1
tlpdbopt_autobackup 0
EOF

echo "Installing TeX Live into: $TL_ROOT"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "Downloading installer..."
curl -sSL "https://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz" \
    | tar -xz -C "$TMPDIR"

INSTALLER_DIR=$(find "$TMPDIR" -maxdepth 1 -type d -name "install-tl-*")
cd "$INSTALLER_DIR"

echo "Running installer..."
./install-tl --profile="$TL_PROFILE"

echo "TeX Live installation complete."