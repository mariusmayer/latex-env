#!/usr/bin/env bash
# Prepend TeX Live bin to PATH when the conda env is activated.
# Safe even if TeX Live is not yet installed.
set +e

TL_BIN="$(find "$CONDA_PREFIX/texlive" -type d -path '*/bin/*' -print -quit 2>/dev/null)"

if [ -n "$TL_BIN" ]; then
    export TEXLIVE_ADDED_PATHS="$TL_BIN"
    case ":$PATH:" in
        *":$TL_BIN:"*) ;;
        *) export PATH="$TL_BIN:$PATH" ;;
    esac
fi