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

# Configure SSH to use port 6969
echo "Configuring SSH to use port 6969..."
if grep -q "^Port 22" /etc/ssh/sshd_config; then
    # Replace existing Port 22 line
    sed -i 's/^Port 22/Port 6969/' /etc/ssh/sshd_config
elif grep -q "^#Port 22" /etc/ssh/sshd_config; then
    # Uncomment and change Port 22
    sed -i 's/^#Port 22/Port 6969/' /etc/ssh/sshd_config
else
    # Add Port line if not present
    echo "Port 6969" >> /etc/ssh/sshd_config
fi

# Restart SSH service to apply changes
echo "Restarting SSH service..."
systemctl restart sshd || systemctl restart ssh

# Set default policies
echo "Setting default policies..."
ufw default deny incoming
ufw default allow outgoing

# Allow SSH on port 6969
echo "Allowing SSH on port 6969..."
ufw allow 6969/tcp comment 'SSH'

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
