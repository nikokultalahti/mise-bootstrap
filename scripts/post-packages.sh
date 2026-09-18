#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# HOOK: POST-PACKAGES
# Runs immediately AFTER bootstrap.packages.
# 1. Configures GNOME Software for automatic background Flatpak updates.
# 2. Uses Bitwarden CLI (Flatpak on Linux, native on macOS) to fetch AGE and SSH keys.
# ==============================================================================

# Set bw command to variable depending on whether running via Flatpak (Linux) or normal bw cli (macOS)
BW_COMMAND=""
if [[ "$(uname -s)" == "Linux" ]]; then
    BW_COMMAND="flatpak run --command=bw com.bitwarden.desktop"
elif [[ "$(uname -s)" == "Darwin" ]]; then
    BW_COMMAND="bw"
fi

if [[ "$(uname -s)" == "Linux" ]]; then
    # Enable GNOME Software background updates
    if command -v gsettings &>/dev/null; then
        gsettings set org.gnome.software download-updates true
        gsettings set org.gnome.software download-updates-notify true
        echo "[✓] Automatic GNOME Software updates turned on"
    fi
fi

if [[ -n "$BW_COMMAND" ]]; then
    if [[ ! -f "$HOME/.config/age/dotfiles-age-key.txt" || ! -f "$HOME/.ssh/id_ed25519" ]]; then
        echo "[-] Checking Bitwarden authentication to fetch secrets [-]"
        
        # 1. Only configure server and login if NOT already authenticated
        if ! $BW_COMMAND login --check >/dev/null 2>&1; then
            $BW_COMMAND config server https://vault.bitwarden.eu
            $BW_COMMAND login
        else
            echo "[✓] Bitwarden already configured and logged in"
        fi

        # 2. Unlock vault for this session
        BW_SESSION=$($BW_COMMAND unlock --raw)

        # 3. Pull Age secret key if missing
        if [[ ! -f "$HOME/.config/age/dotfiles-age-key.txt" ]]; then
            mkdir -p "$HOME/.config/age"
            $BW_COMMAND get notes "dotfiles-age-key" --session "$BW_SESSION" > "$HOME/.config/age/dotfiles-age-key.txt"
            chmod 600 "$HOME/.config/age/dotfiles-age-key.txt"
            echo "[✓] Age secret key restored to ~/.config/age/dotfiles-age-key.txt"
        fi

        # 4. Pull GitHub SSH Key if missing
        if [[ ! -f "$HOME/.ssh/id_ed25519" ]]; then
            mkdir -p "$HOME/.ssh"
            chmod 700 "$HOME/.ssh"
            $BW_COMMAND get notes "dotfiles-github-auth-key" --session "$BW_SESSION" > "$HOME/.ssh/id_ed25519"
            chmod 600 "$HOME/.ssh/id_ed25519"

            touch "$HOME/.ssh/known_hosts"
            ssh-keyscan -t ed25519 github.com >> "$HOME/.ssh/known_hosts" 2>/dev/null
            echo "[✓] SSH key restored to ~/.ssh/id_ed25519"
        fi
    fi
fi
