# latex-env

A portable and reproducible LaTeX environment built around Conda and TeX Live.

This repository is designed to work in two modes:

1. **As a standalone local LaTeX environment** on Linux/WSL systems
2. **As a git submodule inside a VS Code devcontainer workflow**

The environment provides:

* isolated Conda-based tooling
* reproducible TeX Live installations
* automatic package management via `tlmgr`
* optional VS Code/devcontainer integration
* helper scripts for editor workflows

---

# Features

* Portable TeX Live installation inside a Conda environment
* Reproducible dependency management
* Devcontainer-friendly architecture
* Automatic TeX Live bootstrap
* Automatic `tlmgr` package installation
* Mirror fallback logic for improved reliability
* Conda activation/deactivation hooks
* Compatible with GitHub Codespaces, WSL, and local Linux systems

---

# Repository contents

| File / Folder               | Purpose                                             |
| --------------------------- | --------------------------------------------------- |
| `latex-env.yml`             | Conda environment specification                     |
| `tlmgr-packages.txt`        | Additional TeX Live packages managed via `tlmgr`    |
| `bootstrap-texlive.sh`      | Installs TeX Live into the active Conda environment |
| `install-tlmgr-packages.sh` | Installs packages listed in `tlmgr-packages.txt`    |
| `texlive-activate.sh`       | Conda activation hook for TeX Live PATH setup       |
| `texlive-deactivate.sh`     | Conda deactivation hook                             |
| `scripts/`                  | Optional helper scripts callable from editors/tasks |
| `README.md`                 | Documentation                                       |

---

# Devcontainer usage

This repository is commonly used as a git submodule inside a LaTeX project's `.devcontainer/` folder.

Example layout:

```text
.devcontainer/
├── devcontainer.json
├── install.sh
├── poststart.sh
└── latex-env/          ← this repository as a submodule
```

In this setup:

* the **project repository** owns editor configuration and orchestration
* `latex-env` provides the reusable runtime/tooling layer

The project-side `install.sh` bootstraps:

1. Miniconda
2. the Conda environment
3. TeX Live
4. all tracked `tlmgr` packages
5. activation hooks

Once configured, opening the project in VS Code and selecting **Reopen in Container** is sufficient.

---

# Adding latex-env to a project

```bash
git submodule add https://github.com/mariusmayer/latex-env.git .devcontainer/latex-env
git submodule update --init --recursive
```

Optional but recommended global Git configuration:

```bash
git config --global submodule.recurse true
```

This ensures submodules update automatically during pull operations.

---

# Example devcontainer.json

```json
{
  "name": "latex-env",
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu-24.04",
  "initializeCommand": "git submodule update --init --recursive",
  "postCreateCommand": "bash .devcontainer/install.sh 2>&1 | tee .devcontainer/install.log",
  "postStartCommand": "bash .devcontainer/poststart.sh",
  "remoteEnv": {
    "PATH": "/opt/conda/envs/latex-env/texlive/bin/x86_64-linux:/opt/conda/envs/latex-env/bin:${containerEnv:PATH}"
  },
  "customizations": {
    "vscode": {
      "extensions": [
        "james-yu.latex-workshop",
        "ms-python.python",
        "ms-python.vscode-pylance",
        "valentjn.vscode-ltex",
        "edonet.vscode-command-runner"
      ],
      "settings": {
        "python.defaultInterpreterPath": "/opt/conda/envs/latex-env/bin/python",
        "terminal.integrated.defaultProfile.linux": "latex-env",
        "terminal.integrated.profiles.linux": {
          "latex-env": {
            "path": "/bin/bash",
            "args": [
              "-c",
              "source /opt/conda/etc/profile.d/conda.sh && conda activate latex-env && exec bash"
            ]
          }
        }
      }
    }
  },
  "remoteUser": "vscode"
}
```

---

# Example install.sh

Example project-side bootstrap script:

```bash
#!/usr/bin/env bash
# .devcontainer/install.sh
# Devcontainer bootstrap orchestrator. Calls into the latex-env submodule.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_DIR="$SCRIPT_DIR/latex-env"

echo "════════════════════════════════════════════════════════"
echo " latex-env devcontainer bootstrap"
echo "════════════════════════════════════════════════════════"

# ── 1. Miniconda ─────────────────────────────────────────────
CONDA_DIR="/opt/conda"

if [ ! -f "$CONDA_DIR/bin/conda" ]; then
    echo "── [1/4] Installing Miniconda ──────────────────────────"

    ARCH=$(uname -m)
    TMP=$(mktemp --suffix=.sh)
    trap 'rm -f "$TMP"' EXIT

    curl -sSL \
        "https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-${ARCH}.sh" \
        -o "$TMP"

    sudo bash "$TMP" -b -p "$CONDA_DIR"
    sudo chown -R vscode:vscode "$CONDA_DIR"
else
    echo "── [1/4] Miniconda already present, skipping ───────────"
fi

source "$CONDA_DIR/etc/profile.d/conda.sh"

conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r

conda config --set always_yes true
conda config --set channel_priority strict

# ── 2. Conda environment ─────────────────────────────────────
echo "── [2/4] Conda environment ─────────────────────────────"

if conda env list | grep -q "^latex-env "; then
    conda env update -n latex-env -f "$ENV_DIR/latex-env.yml" --prune
else
    conda env create -f "$ENV_DIR/latex-env.yml"
fi

conda activate latex-env

# ── 3. TeX Live ──────────────────────────────────────────────
echo "── [3/4] TeX Live ──────────────────────────────────────"

if find "$CONDA_PREFIX/texlive/bin" -name "latexmk" 2>/dev/null | grep -q .; then
    echo "  Already installed, skipping bootstrap."
else
    bash "$ENV_DIR/bootstrap-texlive.sh"
fi

# ── 4. Activation hooks ──────────────────────────────────────
echo "── [4/4] Installing activation hooks ───────────────────"

mkdir -p "$CONDA_PREFIX/etc/conda/activate.d"
mkdir -p "$CONDA_PREFIX/etc/conda/deactivate.d"

cp "$ENV_DIR/texlive-activate.sh" \
   "$CONDA_PREFIX/etc/conda/activate.d/texlive.sh"

cp "$ENV_DIR/texlive-deactivate.sh" \
   "$CONDA_PREFIX/etc/conda/deactivate.d/texlive.sh"

TL_BIN="$(find "$CONDA_PREFIX/texlive/bin" -mindepth 1 -type d | head -1)"

if [ -z "$TL_BIN" ]; then
    echo "Error: could not find TeX Live bin directory." >&2
    exit 1
fi

export PATH="$TL_BIN:$PATH"

bash "$ENV_DIR/install-tlmgr-packages.sh"

echo "════════════════════════════════════════════════════════"
echo " Bootstrap complete."
echo "════════════════════════════════════════════════════════"
```

---

# Example poststart.sh

Optional project-side helper script:

```bash
#!/bin/bash
# .devcontainer/poststart.sh

# Activate conda env in interactive terminals
grep -qF 'conda activate latex-env' ~/.bashrc || \
  echo 'source /opt/conda/etc/profile.d/conda.sh && conda activate latex-env 2>/dev/null || true' >> ~/.bashrc

# Automatically recurse into submodules during git operations
git config submodule.recurse true
```

---

# Standalone local installation

## 1. Create and activate the Conda environment

```bash
conda env create -f latex-env.yml
conda activate latex-env
```

---

## 2. Install TeX Live

```bash
chmod +x bootstrap-texlive.sh
./bootstrap-texlive.sh
```

Installs a minimal TeX Live (`scheme-small` plus recommended collections)
into `$CONDA_PREFIX/texlive`.

## 3. Install activation hooks

```bash
mkdir -p "$CONDA_PREFIX/etc/conda/activate.d"
mkdir -p "$CONDA_PREFIX/etc/conda/deactivate.d"
cp texlive-activate.sh "$CONDA_PREFIX/etc/conda/activate.d/texlive.sh"
cp texlive-deactivate.sh "$CONDA_PREFIX/etc/conda/deactivate.d/texlive.sh"
```

## 4. Re-activate to refresh PATH

```bash
conda deactivate
conda activate latex-env
```

---

## 5. Install tracked TeX Live packages

```bash
chmod +x install-tlmgr-packages.sh
./install-tlmgr-packages.sh
```

The installer:

* uses the CTAN GeoDNS mirror by default
* automatically falls back to a secondary mirror if necessary
* retries failed package installs
* verifies repository consistency before installation

To install additional packages later:

```bash
tlmgr install <package>
```

Then append the package name to `tlmgr-packages.txt`.
```

---

## 6. Verify the installation

```bash
# Check binaries
which latex && latex --version
which latexmk && latexmk --version
which biber && biber --version
which tlmgr && tlmgr --version

# Check packages
kpsewhich article.cls
kpsewhich biblatex.sty
kpsewhich csquotes.sty

# Minimal compile test
echo "\documentclass{article}\begin{document}Hello, world!\end{document}" > /tmp/test.tex

latexmk -pdf -output-directory=/tmp /tmp/test.tex

ls -lh /tmp/test.pdf
```

---

# Updating dependencies

## Updating Conda dependencies

```bash
conda env export --from-history -n latex-env > latex-env.yml
```

---

## Updating tracked tlmgr packages

Generate the tracked package list:

```bash
# Recursive collection expander
expand() {
    local pkg="$1"

    tlmgr info --list "$pkg" 2>/dev/null \
        | awk '/^depends:/{found=1; next}
               found && /^\t/{print $1}
               found && !/^\t/{found=0}' \
        | while read dep; do
            if [[ "$dep" == collection-* ]]; then
                expand "$dep"
            else
                echo "$dep"
            fi
        done
}

# Baseline packages
{
    expand scheme-small
    expand collection-fontsrecommended
    expand collection-pictures
} | sort -u > /tmp/scheme-baseline.txt

# Diff against installed packages
comm -23 \
    <(tlmgr list --only-installed \
        | grep -oP '(?<=i )[^:\s]+' \
        | grep -v '\.x86_64-linux$' \
        | grep -v '^collection-' \
        | grep -v '^scheme-' \
        | sort) \
    /tmp/scheme-baseline.txt \
    > tlmgr-packages.txt
```

If additional collections are installed manually (for example `collection-science`), include them in the baseline expansion block above.

Commit and push updates:

```bash
git add latex-env.yml tlmgr-packages.txt
git commit -m "update dependencies"
git push
```

---

# Updating the submodule in projects

Inside the parent project repository:

```bash
git submodule update --remote --init --recursive .devcontainer/latex-env

git add .devcontainer/latex-env
git commit -m "bump latex-env"
git push
```

---

# Uninstall

```bash
conda deactivate
conda remove --name latex-env --all
```

---

# Troubleshooting

## Devcontainer image pull failures

Occasionally the base Ubuntu devcontainer image may fail to download due to transient network or registry issues.

Typical fix:

* rebuild/reopen the container
* retry the build operation

In most cases the issue resolves automatically on retry.

---

## tlmgr repository issues

If `tlmgr` cannot update packages or reports missing repositories:

```bash
tlmgr --version
```

Older TeX Live releases may require a historic mirror:

```bash
tlmgr option repository \
https://ftp.tu-chemnitz.de/pub/tug/historic/systems/texlive/YEAR/tlnet-final/
```

---

## PATH not updated after bootstrap

Re-activate the Conda environment:

```bash
conda deactivate
conda activate latex-env
```

---

## Missing fonts or engines

Install additional collections as needed:

```bash
tlmgr install collection-fontsextra
tlmgr install collection-xetex
tlmgr install collection-luatex
```
