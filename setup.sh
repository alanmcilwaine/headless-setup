#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================"
echo "OpenClaw Docker Security Setup"
echo "========================================"
echo ""

if [[ $EUID -ne 0 ]]; then
    echo "Error: This script must be run as root (use sudo)"
    exit 1
fi

echo "[1/5] Setting up data directories..."
"${SCRIPT_DIR}/scripts/setup-directories.sh"

echo "[2/5] Installing Docker..."
"${SCRIPT_DIR}/scripts/setup-docker.sh"

echo "[3/5] Configuring firewall..."
"${SCRIPT_DIR}/scripts/setup-firewall.sh"

echo "[4/5] Installing systemd service..."
"${SCRIPT_DIR}/scripts/install-service.sh"

echo "[5/5] Checking configuration..."
if [[ ! -f /opt/openclaw/.env ]]; then
    echo "Warning: /opt/openclaw/.env not found. You need to create this file with your Discord token."
fi

echo ""
echo "========================================"
echo "Setup Complete!"
echo "========================================"
echo ""
echo "Next steps:"
echo "1. Add Discord token to /opt/openclaw/.env"
echo "2. Place Obsidian vault in /home/openclaw/data/obsidian-vault"
echo "3. Start OpenClaw: sudo systemctl start openclaw"
echo "4. Check status: sudo systemctl status openclaw"
echo "5. View logs: sudo journalctl -u openclaw -f"
echo ""
echo "Security features enabled:"
echo "  - Docker containerization"
echo "  - Non-root user"
echo "  - Resource limits"
echo "  - Systemd auto-start"
echo "  - Host firewall"
echo ""
echo "Data directories created:"
echo "  - /opt/openclaw (application files)"
echo "  - /home/openclaw/data (persistent data)"
echo "  - /var/log/openclaw (logs)"
