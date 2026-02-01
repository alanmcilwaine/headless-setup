#!/bin/bash
set -euo pipefail

OPENCLAW_DIR="/opt/openclaw-source"

echo "========================================"
echo "OpenClaw Native Docker Setup"
echo "========================================"
echo ""

# Clone OpenClaw if not exists
if [ ! -d "$OPENCLAW_DIR/.git" ]; then
    echo "Cloning OpenClaw repository..."
    git clone https://github.com/openclaw/openclaw.git "$OPENCLAW_DIR"
fi

cd "$OPENCLAW_DIR"

# Fix .dockerignore as per the Medium article
if [ -f ".dockerignore" ]; then
    echo "Fixing .dockerignore file..."
    sed -i '/^apps\/$/d' .dockerignore 2>/dev/null || true
    sed -i '/^vendor\/$/d' .dockerignore 2>/dev/null || true
fi

# Set environment variables for our secure setup
export OPENCLAW_CONFIG_DIR=/home/openclaw/.openclaw
export OPENCLAW_WORKSPACE_DIR=/home/openclaw/data/workspace
export OPENCLAW_GATEWAY_PORT=18789
export OPENCLAW_GATEWAY_BIND=loopback
export OPENCLAW_HOME_VOLUME=openclaw-home
# Fix: OpenClaw hardcodes /home/openclaw path, so we need to mount it
export OPENCLAW_EXTRA_MOUNTS="/home/openclaw:/home/openclaw"

# Create data directories
echo "Creating data directories..."
mkdir -p /home/openclaw
mkdir -p "$OPENCLAW_CONFIG_DIR"
mkdir -p "$OPENCLAW_WORKSPACE_DIR"
mkdir -p /home/openclaw/data/obsidian-vault
mkdir -p /home/openclaw/data/anki-data
mkdir -p /home/openclaw/data/calendar

# Set ownership for container user (node = UID 1000)
echo "Setting permissions for container user..."
chown -R 1000:1000 /home/openclaw
chmod -R 755 /home/openclaw
chmod -R 700 /home/openclaw/.openclaw

echo ""
echo "Running OpenClaw docker-setup.sh..."
echo "Note: This will build the Docker image and run onboarding."
echo "When prompted:"
echo "  - Gateway bind: loopback (already set)"
echo "  - Gateway auth: token"
echo "  - Install Gateway daemon: No (we'll use systemd)"
echo ""
./docker-setup.sh

echo ""
echo "Setting up systemd service for auto-start..."
cat > /etc/systemd/system/openclaw.service << 'EOF'
[Unit]
Description=OpenClaw Docker Compose
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/openclaw-source
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable openclaw.service

echo ""
echo "========================================"
echo "OpenClaw Setup Complete!"
echo "========================================"
echo ""
echo "OpenClaw is now running via Docker Compose."
echo "It will auto-start on boot."
echo ""
echo "To manage:"
echo "  cd /opt/openclaw-source"
echo "  docker compose ps"
echo "  docker compose logs -f openclaw-gateway"
echo ""
echo "To add Discord:"
echo "  docker compose run --rm openclaw-cli providers add --provider discord --token YOUR_TOKEN"
echo ""
echo "Data locations:"
echo "  Config: /home/openclaw/.openclaw"
echo "  Workspace: /home/openclaw/data/workspace"
echo "  Obsidian: /home/openclaw/data/obsidian-vault"
echo "  Anki: /home/openclaw/data/anki-data"
echo ""
