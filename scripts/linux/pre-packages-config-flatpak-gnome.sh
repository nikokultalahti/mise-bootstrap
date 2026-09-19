#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# HOOK: PRE-PACKAGES
# Runs immediately BEFORE bootstrap.packages.
# Configures Flathub, migrates any Fedora Flatpaks, and disables Fedora remote.
# ==============================================================================

# 1. Configures Flathub, migrates any Fedora Flatpaks, and disables Fedora remote.
if [[ "$(uname -s)" == "Linux" ]] && command -v flatpak &>/dev/null; then
    echo "[-] Ensuring Flathub is added and prioritized [-]"
    
    # 1. Add full Flathub remote if missing
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

    # 2. Set Flathub priority high (10) so all app searches and installs default to Flathub
    flatpak remote-modify --prio=10 flathub
    flatpak remote-modify --prio=1 fedora 2>/dev/null || true

    echo "[✓] Flathub is now the primary Flatpak repository"
fi

# 2. Enable GNOME Software background updates on Linux
if [[ "$(uname -s)" == "Linux" ]]; then
    if command -v gsettings &>/dev/null; then
        gsettings set org.gnome.software download-updates true
        gsettings set org.gnome.software download-updates-notify true
        echo "[✓] Automatic GNOME Software updates turned on"
    fi
fi
