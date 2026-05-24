#!/usr/bin/env bash
# Remove TeX Live bin from PATH when the conda env is deactivated.
set +e

if [ -n "${TEXLIVE_ADDED_PATHS:-}" ]; then
    new_path="$(echo "$PATH" | tr ':' '\n' \
        | awk -v r="$TEXLIVE_ADDED_PATHS" '$0 != r' \
        | tr '\n' ':' \
        | sed 's/:$//')"
    export PATH="$new_path"
    unset TEXLIVE_ADDED_PATHS
fi

return 0 2>/dev/null || exit 0