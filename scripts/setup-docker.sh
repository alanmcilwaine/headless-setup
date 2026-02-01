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

# 7. Add openclaw user to docker group if user exists
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
