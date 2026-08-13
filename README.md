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
| `install.sh`                | Unified one-command bootstrap (local + devcontainer)|
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

The `latex-env` submodule ships a single `install.sh` that bootstraps:

1. Miniconda (devcontainer only)
2. the Conda environment
3. TeX Live
4. activation hooks
5. all tracked `tlmgr` packages

The project-side `.devcontainer/install.sh` is a thin wrapper that delegates to
`latex-env/install.sh`. Once configured, opening the project in VS Code and
selecting **Reopen in Container** is sufficient.

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

The submodule ships a unified `install.sh`, so the project-side script is just a
thin wrapper that initializes the submodule if needed and delegates to it:

```bash
#!/usr/bin/env bash
# .devcontainer/install.sh — thin wrapper around the latex-env submodule.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_DIR="$SCRIPT_DIR/latex-env"

# Safety net for contexts where `initializeCommand` did not run (e.g. Codespaces).
if [ ! -f "$ENV_DIR/install.sh" ]; then
    echo "latex-env submodule missing — initializing…"
    REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
    if [ -n "$REPO_ROOT" ]; then
        git -C "$REPO_ROOT" submodule update --init --recursive .devcontainer/latex-env
    else
        git submodule update --init --recursive "$ENV_DIR"
    fi
fi

exec bash "$ENV_DIR/install.sh" "$@"
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

## One-command install

```bash
./install.sh
```

This single command:

1. creates or updates the `latex-env` Conda environment
2. bootstraps TeX Live into `$CONDA_PREFIX/texlive` (skipped if already present)
3. installs the activation hooks
4. installs all tracked `tlmgr` packages

It auto-detects a local conda/mamba installation (or a devcontainer, where it
installs Miniconda itself) and is safe to re-run.

## Manual steps (reference)

The commands below are the individual steps that `install.sh` runs. They are
kept here for reference and troubleshooting.

### 1. Create and activate the Conda environment

```bash
conda env create -f latex-env.yml
conda activate latex-env
```

---

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
conda deactivate
conda activate latex-env
```

---

### 5. Install tracked TeX Live packages

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
