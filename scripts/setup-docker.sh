#!/bin/bash

set -euo pipefail

# Docker Installation Script for Debian 12
# Run as root

echo "Installing Docker on Debian 12..."

# 1. Update package index
echo "Updating package index..."
apt-get update

# 2. Install prerequisites
echo "Installing prerequisites..."
apt-get install -y ca-certificates curl gnupg lsb-release

# 3. Add Docker's official GPG key
echo "Adding Docker GPG key..."
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# 4. Set up the repository
echo "Setting up Docker repository..."
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# 5. Install Docker Engine
echo "Installing Docker Engine..."
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# 6. Start and enable Docker service
echo "Starting and enabling Docker service..."
systemctl start docker
systemctl enable docker

# 7. Install fail2ban for brute force protection
echo "Installing fail2ban for brute force protection..."
apt-get install -y fail2ban

# Configure fail2ban for SSH on port 6969
# Using systemd backend since Debian 12 uses journald for SSH logs
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
backend = systemd

[sshd]
enabled = true
port = 6969
filter = sshd
backend = systemd
maxretry = 3
EOF

# Start and enable fail2ban
systemctl start fail2ban
systemctl enable fail2ban

echo "Fail2ban installed and configured for SSH on port 6969"

# 8. Add openclaw user to docker group if user exists
if id "openclaw" &>/dev/null; then
    echo "Adding openclaw user to docker group..."
    usermod -aG docker openclaw
else
    echo "Warning: openclaw user does not exist, skipping group assignment"
fi

echo ""
echo "========================================"
echo "Docker installation completed successfully!"
echo "========================================"
echo ""
echo "Docker version:"
docker --version
echo ""
echo "Docker Compose version:"
docker compose version
