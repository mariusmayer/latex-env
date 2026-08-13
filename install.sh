#!/usr/bin/env bash
# =============================================================================
# install.sh — unified bootstrap for the latex-env Conda + TeX Live environment
#
# Works in two contexts:
#   • Local machine (uses an existing conda/mamba installation)
#   • VS Code devcontainer (installs Miniconda into /opt/conda if needed)
#
# Idempotent: safe to re-run; steps that are already complete are skipped.
#
# Usage:
#   ./install.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_NAME="latex-env"

# ---------------------------------------------------------------------------
# Detect runtime context
# ---------------------------------------------------------------------------
IN_DEVCONTAINER=false
if [ "${REMOTE_CONTAINERS:-}" = "true" ] || [ "${CODESPACES:-}" = "true" ] || [ -d /opt/conda ]; then
    IN_DEVCONTAINER=true
fi

if [ "$IN_DEVCONTAINER" = true ]; then
    CONDA_DIR="/opt/conda"
    echo "── [devcontainer] using conda at $CONDA_DIR ───────────────────────────"

    if [ ! -f "$CONDA_DIR/bin/conda" ]; then
        echo "── Installing Miniconda into $CONDA_DIR ─────────────────────────────"
        ARCH="$(uname -m)"
        TMP="$(mktemp --suffix=.sh)"
        trap 'rm -f "$TMP"' EXIT
        curl -sSL \
            "https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-${ARCH}.sh" \
            -o "$TMP"
        sudo bash "$TMP" -b -p "$CONDA_DIR"
        sudo chown -R "$(id -un):$(id -gn)" "$CONDA_DIR"
    fi
else
    if command -v conda >/dev/null 2>&1; then
        CONDA_DIR="$(conda info --base)"
    elif command -v mamba >/dev/null 2>&1; then
        CONDA_DIR="$(mamba info --base)"
    else
        echo "Error: conda not found on PATH. Install Miniforge/Miniconda first." >&2
        exit 1
    fi
    echo "── [local] using conda at $CONDA_DIR ─────────────────────────────────"
fi

# shellcheck source=/dev/null
source "$CONDA_DIR/etc/profile.d/conda.sh"

# Devcontainer-only conda configuration (kept out of local installs so we do
# not mutate a user's global conda config).
if [ "$IN_DEVCONTAINER" = true ]; then
    conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main
    conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r
    conda config --set always_yes true
    conda config --set channel_priority strict
fi

# ---------------------------------------------------------------------------
# 1. Conda environment
# ---------------------------------------------------------------------------
echo "── [1/4] Conda environment ($ENV_NAME) ────────────────────────────────"
if conda env list | grep -q "^${ENV_NAME} "; then
    conda env update -n "$ENV_NAME" -f "$SCRIPT_DIR/latex-env.yml" --prune
else
    conda env create -f "$SCRIPT_DIR/latex-env.yml" -y
fi

conda activate "$ENV_NAME"

# ---------------------------------------------------------------------------
# 2. TeX Live
# ---------------------------------------------------------------------------
echo "── [2/4] TeX Live ──────────────────────────────────────────────────────"
if find "$CONDA_PREFIX/texlive/bin" -name "latexmk" 2>/dev/null | grep -q .; then
    echo "    TeX Live already installed, skipping bootstrap."
else
    bash "$SCRIPT_DIR/bootstrap-texlive.sh"
fi

# ---------------------------------------------------------------------------
# 3. Activation hooks
# ---------------------------------------------------------------------------
echo "── [3/4] Activation hooks ──────────────────────────────────────────────"
mkdir -p "$CONDA_PREFIX/etc/conda/activate.d"
mkdir -p "$CONDA_PREFIX/etc/conda/deactivate.d"
cp "$SCRIPT_DIR/texlive-activate.sh"   "$CONDA_PREFIX/etc/conda/activate.d/texlive.sh"
cp "$SCRIPT_DIR/texlive-deactivate.sh" "$CONDA_PREFIX/etc/conda/deactivate.d/texlive.sh"

# ---------------------------------------------------------------------------
# 4. tlmgr packages
# ---------------------------------------------------------------------------
echo "── [4/4] tlmgr packages ────────────────────────────────────────────────"
# Put TeX Live on PATH for the remainder of this session so tlmgr resolves.
TL_BIN="$(find "$CONDA_PREFIX/texlive/bin" -mindepth 1 -type d | head -1)"
if [ -z "$TL_BIN" ]; then
    echo "Error: could not find TeX Live bin directory." >&2
    exit 1
fi
export PATH="$TL_BIN:$PATH"

bash "$SCRIPT_DIR/install-tlmgr-packages.sh"

echo ""
echo "latex-env bootstrap complete."
