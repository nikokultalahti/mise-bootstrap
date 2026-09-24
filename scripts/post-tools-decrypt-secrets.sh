#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# HOOK: POST-TOOLS
# Decrypts secrets using age immediately after tools are installed.
# 1. Decrypts User SSH Config (~/.ssh/config) - all machines
# 2. Decrypts System NextDNS Config - Linux AND personal only
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

MACHINE_TYPE="${1:-personal}"

AGE_KEY="$HOME/.config/age/dotfiles-age-key.txt"

if [[ ! -f "$AGE_KEY" ]]; then
    echo "[!] Warning: Age key not found at $AGE_KEY; skipping decryption."
    exit 0
fi

# ------------------------------------------------------------------------------
# 1. Decrypt User SSH Config (~/.ssh/config)
# ------------------------------------------------------------------------------
ENCRYPTED_SSH="$REPO_DIR/dotfiles/.ssh/ssh_config_personal.age"
if [[ ! -f "$ENCRYPTED_SSH" ]]; then
    if [[ -f "$PWD/dotfiles/.ssh/ssh_config_personal.age" ]]; then
        ENCRYPTED_SSH="$PWD/dotfiles/.ssh/ssh_config_personal.age"
    elif [[ -f "$HOME/Dev/mise-bootstrap/dotfiles/.ssh/ssh_config_personal.age" ]]; then
        ENCRYPTED_SSH="$HOME/Dev/mise-bootstrap/dotfiles/.ssh/ssh_config_personal.age"
    fi
fi

DECRYPTED_SSH="$HOME/.ssh/config"

if [[ -f "$ENCRYPTED_SSH" ]]; then
    echo "[-] Decrypting ~/.ssh/config [-]"
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    mise exec -- age -d -i "$AGE_KEY" "$ENCRYPTED_SSH" > "$DECRYPTED_SSH"
    chmod 600 "$DECRYPTED_SSH"
    echo "[✓] ~/.ssh/config decrypted"
fi

# ------------------------------------------------------------------------------
# 2. Decrypt System NextDNS Config (Linux + personal only: /etc/systemd/resolved.conf.d/)
# ------------------------------------------------------------------------------
ENCRYPTED_DNS="$REPO_DIR/system_files/nextdns.age"
if [[ ! -f "$ENCRYPTED_DNS" ]]; then
    if [[ -f "$PWD/system_files/nextdns.age" ]]; then
        ENCRYPTED_DNS="$PWD/system_files/nextdns.age"
    elif [[ -f "$HOME/Dev/mise-bootstrap/system_files/nextdns.age" ]]; then
        ENCRYPTED_DNS="$HOME/Dev/mise-bootstrap/system_files/nextdns.age"
    fi
fi
DECRYPTED_DNS="/etc/systemd/resolved.conf.d/nextdns.conf"

if [[ "$(uname -s)" == "Linux" && "$MACHINE_TYPE" == "personal" && -f "$ENCRYPTED_DNS" ]]; then
    echo "[-] Configuring NextDNS in systemd-resolved [-]"

    # Stream decrypt directly into destination (no plaintext ever touches /tmp)
    mise exec -- age -d -i "$AGE_KEY" "$ENCRYPTED_DNS" | sudo tee "$DECRYPTED_DNS" > /dev/null
    sudo chmod 644 "$DECRYPTED_DNS"

    # Restart systemd-resolved to apply the new DNS immediately
    sudo systemctl restart systemd-resolved
    echo "[✓] NextDNS configured and systemd-resolved restarted"
fi
