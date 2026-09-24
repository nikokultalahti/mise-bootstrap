#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# HOOK: POST-PACKAGES
# Runs immediately AFTER bootstrap.packages.
# Fetches secrets via fnox environment variables (GITHUB_SSH_KEY) or falls
# back to Bitwarden CLI.
# ==============================================================================

fetch_secrets() {
    # Pull GitHub SSH Key if missing
    if [[ ! -f "$HOME/.ssh/id_ed25519" ]]; then
        if [[ -n "${GITHUB_SSH_KEY:-}" ]]; then
            # Use secret from fnox environment variable
            mkdir -p "$HOME/.ssh"
            chmod 700 "$HOME/.ssh"
            echo "$GITHUB_SSH_KEY" > "$HOME/.ssh/id_ed25519"
            chmod 600 "$HOME/.ssh/id_ed25519"

            touch "$HOME/.ssh/known_hosts"
            ssh-keyscan -t ed25519 github.com >> "$HOME/.ssh/known_hosts" 2>/dev/null
            echo "[✓] SSH key restored from fnox to ~/.ssh/id_ed25519"
        else
            # Fall back to Bitwarden CLI
            fetch_ssh_via_bw
        fi
    fi
}

fetch_ssh_via_bw() {
    # Check if bw CLI is available
    if ! command -v bw &>/dev/null; then
        echo "[!] Bitwarden CLI not available, cannot fetch SSH key"
        echo "    Please install Bitwarden CLI via mise first"
        return 1
    fi

    echo "[-] Checking Bitwarden authentication to fetch SSH key [-]"

    # Only configure server if not already set to the correct URL
    CURRENT_SERVER=$(bw config server 2>/dev/null || true)
    if [[ "$CURRENT_SERVER" != "https://vault.bitwarden.eu" ]]; then
        bw config server https://vault.bitwarden.eu
    fi

    # Only login if NOT already authenticated
    if ! bw login --check >/dev/null 2>&1; then
        bw login
    else
        echo "[✓] Bitwarden already configured and logged in"
    fi

    # Unlock vault for this session
    BW_SESSION=$(bw unlock --raw)

    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    bw get notes "mise-github-auth-key" --session "$BW_SESSION" > "$HOME/.ssh/id_ed25519"
    chmod 600 "$HOME/.ssh/id_ed25519"

    touch "$HOME/.ssh/known_hosts"
    ssh-keyscan -t ed25519 github.com >> "$HOME/.ssh/known_hosts" 2>/dev/null
    echo "[✓] SSH key restored from Bitwarden to ~/.ssh/id_ed25519"
}

# Only fetch secrets if missing
if [[ ! -f "$HOME/.ssh/id_ed25519" ]]; then
    echo "[-] Fetching secrets..."
    fetch_secrets
fi
