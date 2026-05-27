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

set_repo() {
    tlmgr option repository "$1"
}

echo "Setting TeX Live repository to: $PRIMARY_MIRROR"
if ! set_repo "$PRIMARY_MIRROR"; then
    echo "GeoDNS mirror failed, falling back to: $FALLBACK_MIRROR" >&2
    set_repo "$FALLBACK_MIRROR" || { echo "ERROR: could not set any repository" >&2; exit 1; }
fi

echo "Verifying repository consistency..."
if ! tlmgr update --list >/dev/null 2>&1; then
    echo "Repository appears broken, trying fallback..." >&2
    set_repo "$FALLBACK_MIRROR" || { echo "ERROR: fallback also failed" >&2; exit 1; }
    tlmgr update --list >/dev/null 2>&1 || { echo "ERROR: both mirrors unusable" >&2; exit 1; }
fi
echo "Repository successfully configured."

install_pkg() {
    local pkg="$1"
    local mirror="$2"
    local tmplog
    tmplog=$(mktemp)
    # Set mirror for this attempt
    tlmgr option repository "$mirror" >/dev/null 2>&1
    # Capture both stdout and stderr; check for checksum errors
    if tlmgr install "$pkg" >"$tmplog" 2>&1; then
        if grep -q "checksums differ\|check_file_and_remove failed" "$tmplog"; then
            rm -f "$tmplog"
            return 1  # checksum failure despite exit 0
        fi
        rm -f "$tmplog"
        return 0
    else
        rm -f "$tmplog"
        return 1
    fi
}

total=${#PACKAGES[@]}
echo "Installing $total package(s)..."
failed=()

for i in "${!PACKAGES[@]}"; do
    pkg="${PACKAGES[$i]}"
    echo "[$(( i + 1 ))/$total] $pkg"

    if install_pkg "$pkg" "$PRIMARY_MIRROR"; then
        continue
    fi

    echo "  Primary mirror failed for '$pkg', retrying on fallback..." >&2
    if install_pkg "$pkg" "$FALLBACK_MIRROR"; then
        echo "  Installed '$pkg' via fallback mirror."
        # Restore primary for next package
        tlmgr option repository "$PRIMARY_MIRROR" >/dev/null 2>&1 || true
        continue
    fi

    echo "  WARNING: failed to install '$pkg' on both mirrors" >&2
    failed+=("$pkg")
    # Restore primary for next package
    tlmgr option repository "$PRIMARY_MIRROR" >/dev/null 2>&1 || true
done

# Restore primary mirror as default
set_repo "$PRIMARY_MIRROR" >/dev/null 2>&1 || true

if [ ${#failed[@]} -gt 0 ]; then
    echo ""
    echo "WARNING: The following packages could not be installed:" >&2
    printf '  %s\n' "${failed[@]}" >&2
    echo "These may be deprecated stubs or already satisfied by collections." >&2
fi
echo "Done."