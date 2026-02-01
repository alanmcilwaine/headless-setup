#!/bin/bash
set -euo pipefail

echo "Uninstalling OpenClaw Docker setup..."

# Stop the openclaw service if running
if systemctl is-active --quiet openclaw 2>/dev/null; then
    echo "Stopping openclaw service..."
    systemctl stop openclaw
fi

# Disable the openclaw service if enabled
if systemctl is-enabled --quiet openclaw 2>/dev/null; then
    echo "Disabling openclaw service..."
    systemctl disable openclaw
fi

# Remove the systemd service file
if [ -f /etc/systemd/system/openclaw.service ]; then
    echo "Removing systemd service file..."
    rm -f /etc/systemd/system/openclaw.service
    systemctl daemon-reload
fi

# Stop and remove the Docker container
if docker ps -a --format '{{.Names}}' | grep -q '^openclaw$'; then
    echo "Stopping and removing Docker container 'openclaw'..."
    docker stop openclaw 2>/dev/null || true
    docker rm openclaw 2>/dev/null || true
fi

# Ask about removing data directories
read -p "Do you want to remove data directories at /home/openclaw/data/? (yes/no): " remove_data
if [[ "$remove_data" =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Removing data directories..."
    rm -rf /home/openclaw/data
    rm -rf /home/openclaw/.openclaw
else
    echo "Data preserved at /home/openclaw/data/"
fi

# Ask about removing installation directory
read -p "Do you want to remove /opt/openclaw installation directory? (yes/no): " remove_opt
if [[ "$remove_opt" =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Removing /opt/openclaw..."
    rm -rf /opt/openclaw
fi

echo ""
echo "OpenClaw uninstallation complete!"
echo "Note: Docker and firewall configurations were not removed."
