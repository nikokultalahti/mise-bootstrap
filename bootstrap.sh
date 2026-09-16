#!/usr/bin/env bash

# Usage:
#   bash <(curl -fsSL https://raw.githubusercontent.com/nikokultalahti/dotfile-test/main/bootstrap.sh)

set -euo pipefail

# Configuration
REPO_URL="https://github.com/nikokultalahti/dotfile-test.git"

# Ensure Dev directory exists
mkdir -p "$HOME/Dev"

# Clone the repository
TARGET_DIR="$HOME/Dev/dotfile-test"
if [[ ! -d "$TARGET_DIR" ]]; then
    echo "[-] Cloning repository..."
    git clone "$REPO_URL" "$TARGET_DIR"
    echo "[✓] Repository cloned to $TARGET_DIR"
else
    echo "[!] Repository already exists at $TARGET_DIR"
fi

# Add mise to PATH for this session
export PATH="$HOME/.local/bin:$PATH"

# Install Mise if missing
if ! command -v mise >/dev/null 2>&1; then
    echo "[-] Installing Mise..."
    curl https://mise.run | sh
    echo 'eval "$(mise activate bash)"' >> ~/.bashrc

    echo "[✓] Mise installed"
else
    echo "[✓] Mise is already installed"
fi

# Run mise bootstrap from the repository
echo "[-] Starting mise bootstrap..."
cd "$TARGET_DIR"
mise bootstrap