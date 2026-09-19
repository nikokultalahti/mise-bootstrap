#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# HOOK: POST-PACKAGES
# Runs immediately AFTER bootstrap.packages.
# Fetches secrets via fnox environment variables (GITHUB_SSH_KEY, DOTFILES_AGE_KEY)
# or falls back to Bitwarden CLI (Flatpak on Linux, native on macOS).
# ==============================================================================

fetch_secrets() {
    # 1. Pull Age secret key if missing
    if [[ ! -f "$HOME/.config/age/dotfiles-age-key.txt" ]]; then
        if [[ -n "${DOTFILES_AGE_KEY:-}" ]]; then
            # Use secret from fnox environment variable
            mkdir -p "$HOME/.config/age"
            echo "$DOTFILES_AGE_KEY" > "$HOME/.config/age/dotfiles-age-key.txt"
            chmod 600 "$HOME/.config/age/dotfiles-age-key.txt"
            echo "[✓] Age secret key restored from fnox to ~/.config/age/dotfiles-age-key.txt"
        else
            # Fall back to Bitwarden CLI
            fetch_age_via_bw
        fi
    fi

    # 2. Pull GitHub SSH Key if missing
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

fetch_age_via_bw() {
    BW_COMMAND=""
    if [[ "$(uname -s)" == "Linux" ]]; then
        BW_COMMAND="flatpak run --command=bw com.bitwarden.desktop"
    elif [[ "$(uname -s)" == "Darwin" ]]; then
        BW_COMMAND="bw"
    fi

    if [[ -z "$BW_COMMAND" ]]; then
        echo "[!] Bitwarden CLI not available, cannot fetch age key"
        return 1
    fi

    echo "[-] Checking Bitwarden authentication to fetch age key [-]"

    # Only configure server and login if NOT already authenticated
    if ! $BW_COMMAND login --check >/dev/null 2>&1; then
        $BW_COMMAND config server https://vault.bitwarden.eu
        $BW_COMMAND login
    else
        echo "[✓] Bitwarden already configured and logged in"
    fi

    # Unlock vault for this session
    BW_SESSION=$($BW_COMMAND unlock --raw)

    mkdir -p "$HOME/.config/age"
    $BW_COMMAND get notes "dotfiles-age-key" --session "$BW_SESSION" > "$HOME/.config/age/dotfiles-age-key.txt"
    chmod 600 "$HOME/.config/age/dotfiles-age-key.txt"
    echo "[✓] Age secret key restored from Bitwarden to ~/.config/age/dotfiles-age-key.txt"
}

fetch_ssh_via_bw() {
    BW_COMMAND=""
    if [[ "$(uname -s)" == "Linux" ]]; then
        BW_COMMAND="flatpak run --command=bw com.bitwarden.desktop"
    elif [[ "$(uname -s)" == "Darwin" ]]; then
        BW_COMMAND="bw"
    fi

    if [[ -z "$BW_COMMAND" ]]; then
        echo "[!] Bitwarden CLI not available, cannot fetch SSH key"
        return 1
    fi

    echo "[-] Checking Bitwarden authentication to fetch SSH key [-]"

    # Only configure server and login if NOT already authenticated
    if ! $BW_COMMAND login --check >/dev/null 2>&1; then
        $BW_COMMAND config server https://vault.bitwarden.eu
        $BW_COMMAND login
    else
        echo "[✓] Bitwarden already configured and logged in"
    fi

    # Unlock vault for this session
    BW_SESSION=$($BW_COMMAND unlock --raw)

    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    $BW_COMMAND get notes "dotfiles-github-auth-key" --session "$BW_SESSION" > "$HOME/.ssh/id_ed25519"
    chmod 600 "$HOME/.ssh/id_ed25519"

    touch "$HOME/.ssh/known_hosts"
    ssh-keyscan -t ed25519 github.com >> "$HOME/.ssh/known_hosts" 2>/dev/null
    echo "[✓] SSH key restored from Bitwarden to ~/.ssh/id_ed25519"
}

# Only fetch secrets if at least one is missing
if [[ ! -f "$HOME/.config/age/dotfiles-age-key.txt" || ! -f "$HOME/.ssh/id_ed25519" ]]; then
    echo "[-] Fetching secrets..."
    fetch_secrets
fi
