# latex-env

A portable LaTeX environment using Conda and TeX Live. Designed to work in
two contexts: as a **submodule inside a devcontainer**, where installation is
fully automatic, and as a **standalone local install** on any Linux machine.

---

## Devcontainer usage

If you are opening a project that includes this repo as a submodule at
`.devcontainer/latex-env/`, nothing is required. The devcontainer's
`install.sh` handles everything automatically:

1. Installs Miniconda
2. Creates the `latex-env` conda environment
3. Installs TeX Live into the environment
4. Installs all tlmgr packages from `tlmgr-packages.txt`
5. Sets up activation/deactivation hooks

Just open the project in VS Code and click **Reopen in Container**.

---

## Local install

### 1. Create and activate the conda environment

```bash
conda env create -f latex-env.yml
conda activate latex-env
```

### 2. Install TeX Live

```bash
chmod +x bootstrap-texlive.sh
./bootstrap-texlive.sh
```

Installs a minimal TeX Live (`scheme-small` plus recommended collections)
into `$CONDA_PREFIX/texlive`.

### 3. Install activation hooks

```bash
mkdir -p "$CONDA_PREFIX/etc/conda/activate.d"
mkdir -p "$CONDA_PREFIX/etc/conda/deactivate.d"
cp texlive-activate.sh "$CONDA_PREFIX/etc/conda/activate.d/texlive.sh"
cp texlive-deactivate.sh "$CONDA_PREFIX/etc/conda/deactivate.d/texlive.sh"
```

### 4. Re-activate to refresh PATH

```bash
conda deactivate && conda activate latex-env
```

### 5. Install LaTeX packages

```bash
chmod +x install-tlmgr-packages.sh
./install-tlmgr-packages.sh
```

To add a package later: `tlmgr install <package>` and append the name to
`tlmgr-packages.txt`.

### 6. Verify your setup

```bash
# Check binaries
which latex && latex --version
which latexmk && latexmk --version
which biber && biber --version
which tlmgr && tlmgr --version

# Check key packages
kpsewhich article.cls
kpsewhich biblatex.sty
kpsewhich csquotes.sty

# Minimal compile test
echo "\documentclass{article}\begin{document}Hello, world!\end{document}" > /tmp/test.tex
latexmk -pdf -output-directory=/tmp /tmp/test.tex
ls -lh /tmp/test.pdf
```

### Uninstall

```bash
conda deactivate
conda remove --name latex-env --all
```

---

## Updating packages

### Adding packages to this environment

When you've installed new packages locally, regenerate the tracked files:

```bash
# Conda dependencies (explicit installs only, no transitive deps)
conda env export --from-history -n latex-env > latex-env.yml

# tlmgr packages: export only packages installed on top of scheme-small
# Define recursive collection expander
expand() {
    local pkg="$1"
    tlmgr info --list "$pkg" 2>/dev/null \
        | awk '/^depends:/{found=1; next} found && /^\t/{print $1} found && !/^\t/{found=0}' \
        | while read dep; do
            if [[ "$dep" == collection-* ]]; then
                expand "$dep"
            else
                echo "$dep"
            fi
        done
}

# Expand baseline scheme into a reference list
{
    expand scheme-small
    expand collection-fontsrecommended
    expand collection-pictures
} | sort -u > /tmp/scheme-baseline.txt

# Diff against full installed list, stripping platform packages and schemes
comm -23 \
    <(tlmgr list --only-installed | grep -oP '(?<=i )[^:\s]+' \
        | grep -v '\.x86_64-linux$' \
        | grep -v '^collection-' \
        | grep -v '^scheme-' \
        | sort) \
    /tmp/scheme-baseline.txt \
    > tlmgr-packages.txt

git add latex-env.yml tlmgr-packages.txt
git commit -m "add <package>"
git push
```

Note: if you ever install an additional collection (e.g. `tlmgr install collection-science`), add it to the `expand` block above so its contents are excluded from `tlmgr-packages.txt`.

Then rebuild the devcontainer in VSCode: right-click the remote indicator
(bottom-left) → **Rebuild Container**.

On other machines, pull and update the submodule:

```bash
# Inside the project repo (not inside the submodule)
git submodule update --remote --init --recursive .devcontainer/latex-env
git add .devcontainer/latex-env
git commit -m "bump latex-env"
git push
```

---

## Devcontainer integration

This repo is intended to be used as a git submodule inside a LaTeX project's
`.devcontainer/` folder. The expected project-side layout is:

```text
.devcontainer/
├── devcontainer.json
├── install.sh
└── latex-env/          ← this repo as a submodule
```

### Adding to a project

```bash
git submodule add https://github.com/mariusmayer/latex-env.git .devcontainer/latex-env
git submodule update --init --recursive
```

### Minimal devcontainer.json

```json
{
    "name": "latex-env",
    "image": "mcr.microsoft.com/devcontainers/base:ubuntu-24.04",
    "initializeCommand": "git submodule update --init --recursive",
    "postCreateCommand": "bash .devcontainer/install.sh 2>&1 | tee .devcontainer/install.log",
    "customizations": {
        "vscode": {
            "extensions": [
                "james-yu.latex-workshop",
                "ms-python.python",
                "ms-python.vscode-pylance"
            ]
        }
    },
    "remoteUser": "vscode"
}
```

### Minimal install.sh

The project-side `install.sh` is a thin orchestrator that delegates entirely
to the scripts inside this submodule:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_DIR="$SCRIPT_DIR/latex-env"

CONDA_DIR="/opt/conda"
if [ ! -f "$CONDA_DIR/bin/conda" ]; then
    ARCH=$(uname -m)
    TMP=$(mktemp --suffix=.sh)
    trap 'rm -f "$TMP"' EXIT
    curl -sSL "https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-${ARCH}.sh" -o "$TMP"
    sudo bash "$TMP" -b -p "$CONDA_DIR"
    sudo chown -R vscode:vscode "$CONDA_DIR"
fi

source "$CONDA_DIR/etc/profile.d/conda.sh"
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r
conda config --set always_yes true

if conda env list | grep -q "^latex-env "; then
    conda env update -n latex-env -f "$ENV_DIR/latex-env.yml" --prune
else
    conda env create -f "$ENV_DIR/latex-env.yml"
fi
conda activate latex-env

if ! find "$CONDA_PREFIX/texlive/bin" -name "latexmk" 2>/dev/null | grep -q .; then
    bash "$ENV_DIR/bootstrap-texlive.sh"
fi

mkdir -p "$CONDA_PREFIX/etc/conda/activate.d"
mkdir -p "$CONDA_PREFIX/etc/conda/deactivate.d"
cp "$ENV_DIR/texlive-activate.sh"   "$CONDA_PREFIX/etc/conda/activate.d/texlive.sh"
cp "$ENV_DIR/texlive-deactivate.sh" "$CONDA_PREFIX/etc/conda/deactivate.d/texlive.sh"

TL_BIN="$(find "$CONDA_PREFIX/texlive/bin" -mindepth 1 -type d | head -1)"
if [ -z "$TL_BIN" ]; then
    echo "Error: could not find TeX Live bin directory." >&2
    exit 1
fi
export PATH="$TL_BIN:$PATH"

bash "$ENV_DIR/install-tlmgr-packages.sh"
```

---

## Repository contents

| File | Purpose |
|---|---|
| `latex-env.yml` | Conda environment spec |
| `tlmgr-packages.txt` | TeX Live packages to install via tlmgr |
| `bootstrap-texlive.sh` | Downloads and installs TeX Live into the active conda env |
| `install-tlmgr-packages.sh` | Installs all packages listed in `tlmgr-packages.txt` |
| `texlive-activate.sh` | Conda hook: adds TeX Live to PATH on env activation |
| `texlive-deactivate.sh` | Conda hook: removes TeX Live from PATH on env deactivation |

---

## Troubleshooting

**`tlmgr` can't update / package not found**: your TeX Live year may no
longer be served by the default mirror. Check with `tlmgr --version`. For
older years, point to the historic mirror:

```bash
tlmgr option repository https://ftp.tu-chemnitz.de/pub/tug/historic/systems/texlive/YEAR/tlnet-final/
```

**PATH not updated after bootstrap**: re-activate the env:

```bash
conda deactivate && conda activate latex-env
```

**Fonts or engines missing**: install the relevant collection:

```bash
tlmgr install collection-fontsextra
tlmgr install collection-xetex
tlmgr install collection-luatex
```