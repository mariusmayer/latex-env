#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_FILE="$SCRIPT_DIR/tlmgr-packages.txt"

if [ ! -f "$PACKAGES_FILE" ]; then
    echo "Error: $PACKAGES_FILE not found." >&2
    exit 1
fi

mapfile -t PACKAGES < <(grep -v '^\s*#' "$PACKAGES_FILE" | grep -v '^\s*$' | sed 's/:*$//')

if [ ${#PACKAGES[@]} -eq 0 ]; then
    echo "No packages listed in $PACKAGES_FILE."
    exit 0
fi

# Try to resolve a fresh mirror from mirror.ctan.org (GeoDNS), but fall back
# to a known-reliable mirror if resolution fails or returns a stale server.
FALLBACK_MIRROR="https://ftp.tu-chemnitz.de/pub/tex/systems/texlive/tlnet"
TMPLOG=$(mktemp)
trap 'rm -f "$TMPLOG"' EXIT

echo "Updating tlmgr (resolving mirror)..."
tlmgr --repository https://mirror.ctan.org/systems/texlive/tlnet \
    update --self 2>&1 | tee "$TMPLOG" || true

RESOLVED_REPO=$(grep -oE 'package repository https?://[^ ]+' "$TMPLOG" \
    | head -1 | grep -oE 'https?://[^ ]+')

if [ -n "$RESOLVED_REPO" ]; then
    echo "Locking to resolved mirror: $RESOLVED_REPO"
    MIRROR="$RESOLVED_REPO"
else
    echo "Could not resolve mirror, falling back to: $FALLBACK_MIRROR"
    MIRROR="$FALLBACK_MIRROR"
fi

tlmgr option repository "$MIRROR"

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