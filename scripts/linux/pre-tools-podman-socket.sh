#!/usr/bin/env bash
# Enable and start the rootless Podman user socket for Dev Containers
# This ensures podman.socket is available for rootless container operations

set -euo pipefail

echo "Enabling rootless Podman user socket..."

# Enable and start the podman.socket user unit
if systemctl --user is-active --quiet podman.socket 2>/dev/null; then
    echo "Podman socket is already running"
else
    systemctl --user enable --now podman.socket
    echo "Podman socket enabled and started"
fi

# Verify it's running
if systemctl --user is-active --quiet podman.socket; then
    echo "✓ Podman socket is active and running"
else
    echo "✗ Failed to start podman.socket" >&2
    exit 1
fi
