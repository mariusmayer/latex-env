#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_FILE="$SCRIPT_DIR/tlmgr-packages.txt"
PRIMARY_MIRROR="https://mirror.ctan.org/systems/texlive/tlnet"
FALLBACK_MIRROR="https://ftp.tu-chemnitz.de/pub/tex/systems/texlive/tlnet"

if [ ! -f "$PACKAGES_FILE" ]; then
    echo "Error: $PACKAGES_FILE not found." >&2
    exit 1
fi

mapfile -t PACKAGES < <(grep -v '^\s*#' "$PACKAGES_FILE" | grep -v '^\s*$' | sed 's/:*$//')

if [ ${#PACKAGES[@]} -eq 0 ]; then
    echo "No packages listed in $PACKAGES_FILE."
    exit 0
fi

echo "Resolving CTAN mirror..."

set_repo() {
    tlmgr option repository "$1"
}

echo "Setting TeX Live repository to: $PRIMARY_MIRROR"

if ! set_repo "$PRIMARY_MIRROR"; then
    echo "GeoDNS mirror failed, falling back to: $FALLBACK_MIRROR" >&2

    if ! set_repo "$FALLBACK_MIRROR"; then
        echo "ERROR: could not set any TeX Live repository" >&2
        exit 1
    fi
fi

echo "Verifying repository consistency..."
if ! tlmgr update --list >/dev/null 2>&1; then
    echo "Repository appears broken or incompatible. Trying fallback..." >&2

    if ! tlmgr option repository "$FALLBACK_MIRROR"; then
        echo "ERROR: fallback repository also failed" >&2
        exit 1
    fi

    if ! tlmgr update --list >/dev/null 2>&1; then
        echo "ERROR: both CTAN and fallback mirrors are unusable" >&2
        exit 1
    fi
fi

echo "Repository successfully configured."

total=${#PACKAGES[@]}
echo "Installing $total package(s)..."
failed=()

for i in "${!PACKAGES[@]}"; do
    pkg="${PACKAGES[$i]}"
    echo "[$(( i + 1 ))/$total] $pkg"
    tlmgr install "$pkg" || {
        echo "  WARNING: failed to install '$pkg'" >&2
        failed+=("$pkg")
    }
done

if [ ${#failed[@]} -gt 0 ]; then
    echo ""
    echo "WARNING: The following packages could not be installed:" >&2
    printf '  %s\n' "${failed[@]}" >&2
    echo "These may be deprecated stubs or already satisfied by collections." >&2
fi

echo "Done."