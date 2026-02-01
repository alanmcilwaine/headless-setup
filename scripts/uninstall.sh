#!/bin/bash
set -euo pipefail

echo "Uninstalling OpenClaw..."
echo ""

# Stop and disable systemd service if it exists
if systemctl is-active --quiet openclaw 2>/dev/null; then
    echo "Stopping OpenClaw systemd service..."
    systemctl stop openclaw
fi

if systemctl is-enabled --quiet openclaw 2>/dev/null; then
    echo "Disabling OpenClaw systemd service..."
    systemctl disable openclaw
fi

if [ -f "/etc/systemd/system/openclaw.service" ]; then
    echo "Removing systemd service file..."
    rm -f /etc/systemd/system/openclaw.service
    systemctl daemon-reload
fi

# Stop OpenClaw containers if running
if [ -d "/opt/openclaw-source" ]; then
    echo "Stopping OpenClaw containers..."
    cd /opt/openclaw-source
    docker compose down 2>/dev/null || true
fi

# Ask about removing data
read -p "Remove data directories? This will delete /home/openclaw/data/ (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Removing data..."
    rm -rf /home/openclaw/data
    rm -rf /home/openclaw/.openclaw
    echo "Data removed."
else
    echo "Data preserved at /home/openclaw/data/"
fi

# Ask about removing OpenClaw source
read -p "Remove /opt/openclaw-source? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf /opt/openclaw-source
    echo "OpenClaw source removed."
fi

echo ""
echo "Uninstall complete."
echo "Docker, fail2ban, and firewall were not removed."
