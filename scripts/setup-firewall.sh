#!/bin/bash
set -euo pipefail

# OpenClaw Firewall Setup Script
# Configures UFW (Uncomplicated Firewall) for Debian 12

echo "=== OpenClaw Firewall Setup ==="

# Check if ufw is installed, install if not
if ! command -v ufw &> /dev/null; then
    echo "Installing UFW..."
    apt-get update
    apt-get install -y ufw
fi

# Set default policies
echo "Setting default policies..."
ufw default deny incoming
ufw default allow outgoing

# Allow SSH on port 2222
echo "Allowing SSH on port 2222..."
ufw allow 2222/tcp comment 'SSH'

# Allow loopback connections
echo "Allowing loopback connections..."
ufw allow in on lo
ufw allow out on lo

echo ""
echo "=== Firewall Configuration Complete ==="
echo ""
echo "Note: Docker containers use their own networking layer."
echo "Additional restrictions may be needed for container-specific ports."
echo ""
echo "To enable the firewall, run:"
echo "  sudo ufw enable"
echo ""
echo "Review the rules before enabling with:"
echo "  sudo ufw status verbose"
