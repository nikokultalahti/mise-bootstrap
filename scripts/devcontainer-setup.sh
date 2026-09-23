#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# DEVCONTAINER SETUP
# Run as VS Code's `dotfiles.installCommand` (see dotfiles.* keys in
# dotfiles/.config/vscode/settings.tera) after the Dev Containers extension
# clones this repo into every container it creates.
#
# Deliberately narrower than `mise bootstrap`: it only installs the plain CLI
# tools from [tools] and applies [dotfiles]. It never touches
# [bootstrap.packages] (Flatpaks), [bootstrap.files]/[bootstrap.services]
# (root/systemd), or the Bitwarden/fnox secret-fetching hooks, none of which
# apply - or are even possible - inside an ephemeral container.
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if ! command -v mise &>/dev/null && [ ! -x "$HOME/.local/bin/mise" ]; then
    echo "[-] Installing mise..."
    curl -fsSL https://mise.run | sh
    echo "[✓] mise installed"
fi

export PATH="$HOME/.local/bin:$PATH"

cd "$REPO_DIR"

echo "[-] Installing CLI tools ([tools] in mise.toml)..."
mise install
echo "[✓] CLI tools installed"

echo "[-] Applying dotfiles (.zshrc, .zprofile, .gitconfig, etc.)..."
mise bootstrap dotfiles apply
echo "[✓] Dotfiles applied"
