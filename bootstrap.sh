#!/usr/bin/env bash
set -euo pipefail

# Reconnect stdin to controlling terminal if piped via: curl ... | bash
if [ ! -t 0 ] && [ -e /dev/tty ]; then
    exec < /dev/tty
fi

echo "=================================================================="
echo "🚀 Workstation Bootstrap (Mise + Bitwarden + Fnox)"
echo "=================================================================="
echo ""

# ------------------------------------------------------------------------------
# 1. Install & Activate Mise
# ------------------------------------------------------------------------------
if ! command -v mise &>/dev/null && [ ! -x "$HOME/.local/bin/mise" ]; then
    echo "[-] Installing Mise..."
    curl -fsSL https://mise.run | sh
    echo "[✓] Mise installed"
else
    echo "[✓] Mise is already installed"
fi

export PATH="$HOME/.local/bin:$PATH"
CURRENT_SHELL="$(basename "${SHELL:-bash}")"
eval "$("$HOME/.local/bin/mise" activate "$CURRENT_SHELL" 2>/dev/null || "$HOME/.local/bin/mise" activate bash)"

# ------------------------------------------------------------------------------
# 2. Install Bitwarden CLI and fnox
# ------------------------------------------------------------------------------
echo "[-] Ensuring bitwarden and fnox are installed globally via Mise..."
mise use -g bitwarden fnox
echo "[✓] Bitwarden CLI and fnox ready"

# ------------------------------------------------------------------------------
# 3. Configure and Authenticate Bitwarden
# ------------------------------------------------------------------------------
echo "[-] Configuring Bitwarden server (https://vault.bitwarden.eu)..."
bw config server https://vault.bitwarden.eu

if ! bw login --check &>/dev/null; then
    echo "[-] Logging in to Bitwarden..."
    bw login
else
    echo "[✓] Bitwarden already logged in"
fi

echo "[-] Unlocking Bitwarden vault..."
BW_SESSION="$(bw unlock --raw)"
export BW_SESSION
echo "[✓] Bitwarden vault unlocked"

# ------------------------------------------------------------------------------
# 4. Ensure Repository is Cloned & Enter Directory
# ------------------------------------------------------------------------------
TARGET_DIR="$HOME/Dev/mise-bootstrap"

# If current directory has mise.toml and .git, use current working directory
if [ -f "$PWD/mise.toml" ] && [ -d "$PWD/.git" ]; then
    TARGET_DIR="$PWD"
fi

if [ ! -d "$TARGET_DIR/.git" ]; then
    echo "[-] Cloning repository to $TARGET_DIR..."
    mkdir -p "$(dirname "$TARGET_DIR")"
    git clone https://github.com/nikokultalahti/mise-bootstrap.git "$TARGET_DIR"
    echo "[✓] Repository cloned"
fi

cd "$TARGET_DIR"

# ------------------------------------------------------------------------------
# 5. Select Machine Purpose (Personal vs Work)
# ------------------------------------------------------------------------------
echo ""
echo "Select the configuration profile for this machine:"
echo "  1) Personal (Fedora Silverblue Linux / macOS) [Default]"
echo "  2) Work (macOS)"
read -r -p "Enter choice [1/2, default: 1]: " CHOICE
CHOICE="${CHOICE:-1}"

BOOTSTRAP_ENV_FLAG=""
if [ "$CHOICE" = "2" ] || [ "$CHOICE" = "work" ]; then
    echo "[✓] Selected Work profile (-E work)"
    BOOTSTRAP_ENV_FLAG="-E work"
else
    echo "[✓] Selected Personal profile"
fi

# ------------------------------------------------------------------------------
# 6. Run Bootstrap via fnox
# ------------------------------------------------------------------------------
echo ""
echo "[-] Running bootstrap through fnox..."
if [ -n "$BOOTSTRAP_ENV_FLAG" ]; then
    fnox exec -- mise "$BOOTSTRAP_ENV_FLAG" bootstrap --force-dotfiles
else
    fnox exec -- mise bootstrap --force-dotfiles
fi

echo ""
echo "=================================================================="
echo "🎉 Bootstrap finished successfully!"
echo "=================================================================="
