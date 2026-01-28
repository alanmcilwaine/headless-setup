#!/bin/bash
set -euo pipefail
# Layer 3: Runtime - Docker and Moltbot

log() { echo "[RUNTIME] $*"; }

install_node() {
    log "Installing Node.js..."
    if ! command -v node &>/dev/null; then
        rpm-ostree install -y nodejs --idempotent --allow-inactive
    fi
}

install_moltbot() {
    log "Installing Moltbot..."
    mkdir -p /var/lib/moltbot
    chown moltbot:moltbot /var/lib/moltbot
    
    cd /var/lib/moltbot
    npm install -g moltbot@latest 2>/dev/null || true
    chown -R moltbot:moltbot /var/lib/moltbot
}

configure_moltbot() {
    log "Configuring Moltbot..."
    
    mkdir -p /var/lib/moltbot/.moltbot
    chown moltbot:moltbot /var/lib/moltbot/.moltbot
    
    TOKEN=$(openssl rand -base64 32 2>/dev/null || head -c 32 /dev/urandom | base64)
    
    cat > /var/lib/moltbot/.moltbot/moltbot.json << EOF
{
  "gateway": {
    "mode": "local",
    "bind": "loopback",
    "port": 18789,
    "auth": { "mode": "token", "token": "$TOKEN" }
  },
  "channels": {
    "discord": {
      "dmPolicy": "pairing",
      "token": "${DISCORD_TOKEN:-}"
    }
  },
  "agents": {
    "list": [{
      "id": "main",
      "sandbox": { "mode": "all", "scope": "agent" },
      "tools": {
        "allow": ["read", "write", "edit", "apply_patch", "exec", "process", "browser", "web_fetch", "web_search"],
        "deny": []
      }
    }]
  },
  "discovery": { "mdns": { "mode": "minimal" } }
}
EOF

    chown moltbot:moltbot /var/lib/moltbot/.moltbot/moltbot.json
    chmod 600 /var/lib/moltbot/.moltbot/moltbot.json
    
    echo "$TOKEN" > /var/lib/moltbot/.moltbot/gateway-token.txt
    chown moltbot:moltbot /var/lib/moltbot/.moltbot/gateway-token.txt
    chmod 600 /var/lib/moltbot/.moltbot/gateway-token.txt
}

create_service() {
    log "Creating systemd service..."
    
    cat > /etc/systemd/system/moltbot.service << 'EOF'
[Unit]
Description=Moltbot Personal AI Assistant
After=network-online.target docker.service

[Service]
Type=simple
User=moltbot
Group=moltbot
WorkingDirectory=/var/lib/moltbot
ExecStart=/usr/bin/moltbot gateway --port 18789
Restart=always
RestartSec=10
Environment=NODE_ENV=production

PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=/var/lib/moltbot
NoNewPrivileges=yes

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable moltbot
}

configure_docker_network() {
    log "Creating Docker network..."
    docker network create minipc-network 2>/dev/null || true
}

install_node
configure_docker_network
install_moltbot
configure_moltbot
create_service

log "Runtime setup complete."
log "Add Discord token to /var/lib/moltbot/.moltbot/moltbot.json"
log "Run: sudo systemctl start moltbot"
