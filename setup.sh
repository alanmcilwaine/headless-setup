#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================"
echo "OpenClaw Docker Security Setup"
echo "========================================"
echo ""

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)"
   exit 1
fi

echo "[1/4] Setting up data directories..."
"${SCRIPT_DIR}/scripts/setup-directories.sh"

echo ""
echo "[2/4] Installing Docker..."
"${SCRIPT_DIR}/scripts/setup-docker.sh"

echo ""
echo "[3/4] Configuring firewall..."
"${SCRIPT_DIR}/scripts/setup-firewall.sh"

echo ""
echo "[4/4] Installing OpenClaw..."
"${SCRIPT_DIR}/scripts/setup-openclaw.sh"

echo ""
echo "========================================"
echo "Setup Complete!"
echo "========================================"
echo ""
echo "OpenClaw is running in Docker with:"
echo "  - Container isolation"
echo "  - Non-root execution"
echo "  - 4 CPU cores, 8GB RAM"
echo "  - Fail2ban brute-force protection"
echo "  - SSH on port 6969"
echo ""
echo "Next steps:"
echo "  1. Add Discord bot:"
echo "     cd /opt/openclaw-source"
echo "     docker compose run --rm openclaw-cli providers add --provider discord --token YOUR_TOKEN"
echo ""
echo "  2. Place your data:"
echo "     - Obsidian vault: /home/openclaw/data/obsidian-vault"
echo "     - Anki data: /home/openclaw/data/anki-data"
echo ""
echo "  3. Check status:"
echo "     cd /opt/openclaw-source"
echo "     docker compose ps"
echo "     docker compose logs -f openclaw-gateway"
echo ""
echo "  4. View logs:"
echo "     sudo journalctl -u openclaw -f"
echo ""
