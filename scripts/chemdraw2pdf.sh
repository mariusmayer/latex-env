#!/bin/bash
# .devcontainer/chemdraw2pdf.sh
# Converts a ChemDraw-exported EPS to PDF, fixing CP1252 font references.
# Path-independent: uses $CONDA_PREFIX resolved at runtime.

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: chemdraw2pdf <input.eps> [output.pdf]" >&2
  exit 1
fi

# Ensure conda env is active
if [ -z "${CONDA_PREFIX:-}" ]; then
  if [ -f "/opt/conda/etc/profile.d/conda.sh" ]; then
    source /opt/conda/etc/profile.d/conda.sh
  elif [ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]; then
    source "$HOME/miniconda3/etc/profile.d/conda.sh"
  else
    echo "Error: could not find conda installation." >&2
    exit 1
  fi
  conda activate latex-env
fi

input="$1"
base="${input%.eps}"
fixed="${base}_fixed.eps"
output="${2:-${base}.pdf}"

FONT_PATH="$CONDA_PREFIX/texlive/texmf-dist/fonts/type1/public/lm"

sed \
  's|/[^ ]*-1252 /[^ ]* reencode1252|/LMRoman10-Regular /LMRoman10-Regular findfont definefont pop|g
   s|/[^ ]*-1252 findfont|/LMRoman10-Regular findfont|g' \
  "$input" > "$fixed"

gs -dNOPAUSE -dBATCH -dEPSCrop \
   -sDEVICE=pdfwrite \
   -sFONTPATH="$FONT_PATH" \
   -dEmbedAllFonts=true \
   -sOutputFile="$output" \
   "$fixed"

rm "$fixed"
echo "Done: $output"
