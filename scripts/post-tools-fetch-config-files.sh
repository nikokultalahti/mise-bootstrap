#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# HOOK: POST-TOOLS
# Places config files sourced directly from Bitwarden secure notes (via fnox
# environment variables, falling back to the Bitwarden CLI) — replaces the
# earlier age-encrypted-files-in-git approach, since Bitwarden was already a
# hard bootstrap dependency and age only added a second key to protect.
# 1. SSH Config (~/.ssh/config) - all machines
# 2. System NextDNS Config - Linux AND personal only
# ==============================================================================

MACHINE_TYPE="${1:-personal}"

fetch_note_via_bw() {
    local note_name="$1"

    if ! command -v bw &>/dev/null; then
        echo "[!] Bitwarden CLI not available, cannot fetch $note_name" >&2
        echo "    Please install Bitwarden CLI via mise first" >&2
        return 1
    fi

    # Only configure server if not already set to the correct URL
    local CURRENT_SERVER
    CURRENT_SERVER=$(bw config server 2>/dev/null || true)
    if [[ "$CURRENT_SERVER" != "https://vault.bitwarden.eu" ]]; then
        bw config server https://vault.bitwarden.eu >&2
    fi

    # Only login if NOT already authenticated
    if ! bw login --check >/dev/null 2>&1; then
        bw login >&2
    fi

    # Unlock vault for this session
    local BW_SESSION
    BW_SESSION=$(bw unlock --raw)

    bw get notes "$note_name" --session "$BW_SESSION"
}

# ------------------------------------------------------------------------------
# 1. SSH Config (~/.ssh/config)
# ------------------------------------------------------------------------------
echo "[-] Writing ~/.ssh/config [-]"
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
if [[ -n "${SSH_CONFIG:-}" ]]; then
    echo "$SSH_CONFIG" > "$HOME/.ssh/config"
else
    fetch_note_via_bw "mise-ssh-config" > "$HOME/.ssh/config"
fi
chmod 600 "$HOME/.ssh/config"
echo "[✓] ~/.ssh/config written"

# ------------------------------------------------------------------------------
# 2. System NextDNS Config (Linux + personal only: /etc/systemd/resolved.conf.d/)
# ------------------------------------------------------------------------------
NEXTDNS_TARGET="/etc/systemd/resolved.conf.d/nextdns.conf"

if [[ "$(uname -s)" == "Linux" && "$MACHINE_TYPE" == "personal" ]]; then
    echo "[-] Configuring NextDNS in systemd-resolved [-]"
    if [[ -n "${NEXTDNS_CONFIG:-}" ]]; then
        echo "$NEXTDNS_CONFIG" | sudo tee "$NEXTDNS_TARGET" > /dev/null
    else
        fetch_note_via_bw "mise-nextdns-conf" | sudo tee "$NEXTDNS_TARGET" > /dev/null
    fi
    sudo chmod 644 "$NEXTDNS_TARGET"

    # Restart systemd-resolved to apply the new DNS immediately
    sudo systemctl restart systemd-resolved
    echo "[✓] NextDNS configured and systemd-resolved restarted"
fi
