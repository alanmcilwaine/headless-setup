#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SERVICE_FILE="${PROJECT_DIR}/systemd/openclaw.service"
INSTALL_DIR="/opt/openclaw"

if [[ $EUID -ne 0 ]]; then
    echo "Error: This script must be run as root" >&2
    exit 1
fi

if [[ ! -f "$SERVICE_FILE" ]]; then
    echo "Error: Service file not found at $SERVICE_FILE" >&2
    exit 1
fi

mkdir -p "$INSTALL_DIR"

if [[ -f "${PROJECT_DIR}/docker-compose.yml" ]]; then
    cp "${PROJECT_DIR}/docker-compose.yml" "$INSTALL_DIR/"
    echo "Copied docker-compose.yml to $INSTALL_DIR"
fi

cp "$SERVICE_FILE" /etc/systemd/system/openclaw.service

echo "Service file installed to /etc/systemd/system/openclaw.service"

systemctl daemon-reload

echo "Reloaded systemd daemon"

systemctl enable openclaw.service

echo "Enabled openclaw.service"

echo ""
echo "=== Installation Complete ==="
echo ""
echo "Next steps:"
echo "1. Add your Discord token to: $INSTALL_DIR/.env"
echo "   Example: echo 'DISCORD_TOKEN=your_token_here' > $INSTALL_DIR/.env"
echo ""
echo "2. Run the data directory setup script:"
echo "   ./scripts/setup-directories.sh"
echo ""
echo "3. Start the service:"
echo "   systemctl start openclaw.service"
echo ""
echo "4. Check service status:"
echo "   systemctl status openclaw.service"
echo ""
echo "5. View logs:"
echo "   journalctl -u openclaw.service -f"
echo ""
