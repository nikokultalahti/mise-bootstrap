#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# FINAL HOOK (mise bootstrap final-hook)
# 1. Switch Git Origin from HTTPS to SSH
# 2. Persist Work Profile if applicable
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Fallback to current working directory or ~/Dev/mise-bootstrap if .git is not at REPO_DIR
if [[ ! -d "$REPO_DIR/.git" ]]; then
    if [[ -d "$PWD/.git" ]]; then
        REPO_DIR="$PWD"
    elif [[ -d "$HOME/Dev/mise-bootstrap/.git" ]]; then
        REPO_DIR="$HOME/Dev/mise-bootstrap"
    fi
fi

# ------------------------------------------------------------------------------
# 1. Switch Git Origin from HTTPS to SSH
# ------------------------------------------------------------------------------
if [[ -d "$REPO_DIR/.git" ]]; then
    CURRENT_ORIGIN=$(git -C "$REPO_DIR" remote get-url origin 2>/dev/null || true)
    if [[ "$CURRENT_ORIGIN" == https://github.com/* ]]; then
        echo "[-] Converting git origin from HTTPS to SSH in $REPO_DIR [-]"
        
        # Converts https://github.com/user/repo(.git) to git@github.com:user/repo.git
        SSH_ORIGIN="git@github.com:${CURRENT_ORIGIN#https://github.com/}"
        [[ "$SSH_ORIGIN" != *.git ]] && SSH_ORIGIN="${SSH_ORIGIN}.git"
        
        git -C "$REPO_DIR" remote set-url origin "$SSH_ORIGIN"
        echo "[✓] Git origin updated to: $SSH_ORIGIN"
    else
        echo "[✓] Git origin is already using SSH or custom remote"
    fi
fi

# ------------------------------------------------------------------------------
# 2. Persist Profile (personal or work), so subsequent bare `mise bootstrap`/`mise install`
#    calls don't need -E passed again.
# ------------------------------------------------------------------------------
MACHINE_TYPE="${1:-personal}"

echo "[-] Persisting '$MACHINE_TYPE' environment settings [-]"
mise settings set env "$MACHINE_TYPE"
echo "[✓] Machine permanently configured with '$MACHINE_TYPE' profile in config.local.toml"

echo ""
echo "=================================================================="
echo "🎉 Bootstrap complete!" 
echo "=================================================================="
