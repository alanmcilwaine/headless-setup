#!/bin/bash
set -euo pipefail
# Layer 3: Runtime - Docker and Openclaw

log() { echo "[RUNTIME] $*"; }

install_node() {
    log "Installing Node.js..."
    if ! command -v node &>/dev/null; then
        rpm-ostree install -y nodejs --idempotent --allow-inactive
    fi
}

install_openclaw() {
    log "Installing Openclaw..."
    mkdir -p /var/lib/openclaw
    chown openclaw:openclaw /var/lib/openclaw
    
    cd /var/lib/openclaw
    npm install -g openclaw@latest 2>/dev/null || true
    chown -R openclaw:openclaw /var/lib/openclaw
}

configure_openclaw() {
    log "Configuring Openclaw..."
    
    mkdir -p /var/lib/openclaw/.openclaw
    chown openclaw:openclaw /var/lib/openclaw/.openclaw
    
    TOKEN=$(openssl rand -base64 32 2>/dev/null || head -c 32 /dev/urandom | base64)
    
    cat > /var/lib/openclaw/.openclaw/openclaw.json << EOF
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

    chown openclaw:openclaw /var/lib/openclaw/.openclaw/openclaw.json
    chmod 600 /var/lib/openclaw/.openclaw/openclaw.json
    
    echo "$TOKEN" > /var/lib/openclaw/.openclaw/gateway-token.txt
    chown openclaw:openclaw /var/lib/openclaw/.openclaw/gateway-token.txt
    chmod 600 /var/lib/openclaw/.openclaw/gateway-token.txt
}

create_service() {
    log "Creating systemd service..."
    
    cat > /etc/systemd/system/openclaw.service << 'EOF'
[Unit]
Description=Openclaw Personal AI Assistant
After=network-online.target docker.service

[Service]
Type=simple
User=openclaw
Group=openclaw
WorkingDirectory=/var/lib/openclaw
ExecStart=/usr/bin/openclaw gateway --port 18789
Restart=always
RestartSec=10
Environment=NODE_ENV=production

PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=/var/lib/openclaw
NoNewPrivileges=yes

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable openclaw
}

configure_docker_network() {
    log "Creating Docker network..."
    docker network create minipc-network 2>/dev/null || true
}

install_node
configure_docker_network
install_openclaw
configure_openclaw

log "Runtime setup complete."
log "Add Discord token to /var/lib/openclaw/.openclaw/openclaw.json"
log "Run: sudo systemctl start openclaw"
