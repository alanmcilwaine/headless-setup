#!/usr/bin/env bash
# 02-services.sh - Install and configure applications
set -euo pipefail

STATE_DIR="/var/lib/minipc-state"
CONFIG_DIR="/opt/minipc/config"
DATA_DIR="/opt/minipc/data"
LOG_FILE="${STATE_DIR}/setup.log"

log() {
    echo "[SERVICES] $(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOG_FILE"
}

install_moltbot() {
    log "Installing MoltBot..."

    local MOLTBOT_DIR="/var/lib/moltbot"
    local MOLTBOT_VENV="${MOLTBOT_DIR}/venv"
    local MOLTBOT_USER="moltbot"

    if [[ -d "${MOLTBOT_VENV}" ]]; then
        log "MoltBot venv already exists, skipping"
        return 0
    fi

    python3 -m venv "${MOLTBOT_VENV}"
    chown -R "${MOLTBOT_USER}:${MOLTBOT_USER}" "${MOLTBOT_VENV}"

    sudo -u "${MOLTBOT_USER}" bash << "MOLTBOT_INSTALL"
set -e
source /var/lib/moltbot/venv/bin/activate
pip install --upgrade pip
pip install moltbot
MOLTBOT_INSTALL

    create_moltbot_config
    create_moltbot_systemd
    create_moltbot_apparmor

    log "MoltBot installed successfully"
}

create_moltbot_config() {
    log "Creating MoltBot configuration..."
    mkdir -p "/var/lib/moltbot/.moltbot"

    cat > "/var/lib/moltbot/.moltbot/moltbot.json" << 'EOF'
{
    "discord": {
        "token": "${DISCORD_TOKEN}",
        "dm_pairing_code": "SECURE-PAIR-CODE"
    },
    "storage": {
        "type": "file",
        "path": "/var/lib/moltbot/.moltbot/storage.json"
    },
    "vault": {
        "path": "/var/lib/moltbot/vault",
        "permissions": "600"
    },
    "logging": {
        "level": "INFO",
        "file": "/var/log/moltbot/moltbot.log"
    },
    "http": {
        "host": "127.0.0.1",
        "port": 18789
    },
    "allowed_users": ["alan"],
    "system_commands": {
        "enabled": true,
        "sudo_commands": ["apt update", "apt upgrade", "systemctl restart", "cat /var/lib/moltbot/vault/*"]
    }
}
EOF

    chown moltbot:moltbot "/var/lib/moltbot/.moltbot/moltbot.json"
    chmod 600 "/var/lib/moltbot/.moltbot/moltbot.json"
}

create_moltbot_systemd() {
    log "Creating MoltBot systemd service..."
    cat > /etc/systemd/system/moltbot.service << 'EOF'
[Unit]
Description=MoltBot - Personal AI Assistant
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=simple
User=moltbot
Group=moltbot
Environment="PATH=/var/lib/moltbot/venv/bin"
Environment="DISCORD_TOKEN=YOUR_TOKEN_HERE"
ExecStart=/var/lib/moltbot/venv/bin/moltbot
WorkingDirectory=/var/lib/moltbot
Restart=always
RestartSec=10
StandardOutput=append:/var/log/moltbot/moltbot.log
StandardError=append:/var/log/moltbot/moltbot.log

# Security hardening
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/lib/moltbot /var/log/moltbot
PrivateTmp=true

# AppArmor
AppArmorProfile=moltbot

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable moltbot.service
}

create_moltbot_apparmor() {
    log "Creating MoltBot AppArmor profile..."
    cat > /etc/apparmor.d/usr.bin.moltbot << 'EOF'
#include <tunables/global>

profile moltbot flags=(attach_disconnected) {
    #include <abstractions/base>
    #include <abstractions/bash>
    #include <abstractions/nameservice>
    #include <abstractions/python3>
    #include <abstractions/ubuntu-console-browsers>

    capability net_bind_service,
    capability setuid,
    capability setgid,
    capability dac_override,
    capability fowner,
    capability chown,
    capability fsetid,

    network inet stream,
    network inet6 stream,

    /var/lib/moltbot/** rwmix,
    /var/log/moltbot/** rw,
    /var/lib/moltbot/venv/** rix,
    /usr/bin/python3.* rix,
    /etc/passwd r,
    /etc/group r,

    # Allow reading but not writing to system config
    /etc/sudoers.d/moltbot r,
    /etc/sudoers.d/ r,

    # Allow moltbot to execute specific sudo commands
    /usr/bin/sudo ix,

    # Deny sensitive paths
    deny /etc/shadow r,
    deny /etc/ssh/** w,
    deny /root/** rw,
    deny /home/*/.ssh/** rw,

    # Home directory access for vault
    /home/alan/ r,
    /home/alan/** rw,

    # Deny execution of sensitive binaries
    deny /usr/bin/chsh m,
    deny /usr/bin/gpasswd m,
    deny /usr/bin/passwd m,
    deny /usr/sbin/useradd m,
    deny /usr/sbin/userdel m,
    deny /usr/sbin/usermod m,
}
EOF

    apparmor_parser -r /etc/apparmor.d/usr.bin.moltbot 2>/dev/null || true
    systemctl restart apparmor.service 2>/dev/null || true
}

install_anki() {
    log "Installing Anki (headless)..."

    local ANKI_DIR="/opt/minipc/data/anki"
    local ANKI_VENV="${ANKI_DIR}/venv"
    local ANKI_USER="alan"

    if [[ -d "${ANKI_VENV}" ]]; then
        log "Anki venv already exists, skipping"
        return 0
    fi

    apt-get install -y libxcb-xinerama0 libxcb-cursor0 libnss3 libasound2 libatk-bridge2.0-0 libgtk-3-0 libxss1

    python3 -m venv "${ANKI_VENV}"
    chown -R "${ANKI_USER}:${ANKI_USER}" "${ANKI_VENV}"

    sudo -u "${ANKI_USER}" bash << "ANKI_INSTALL"
set -e
source /opt/minipc/data/anki/venv/bin/activate
pip install --upgrade pip
pip install anki
ANKI_INSTALL

    create_anki_systemd

    log "Anki installed successfully"
}

create_anki_systemd() {
    log "Creating Anki systemd service..."
    cat > /etc/systemd/system/anki.service << 'EOF'
[Unit]
Description=Anki - Flashcard Study (Headless)
After=network.target

[Service]
Type=simple
User=alan
Group=alan
Environment="PATH=/opt/minipc/data/anki/venv/bin"
ExecStart=/opt/minipc/data/anki/venv/bin/python3 -m anki
WorkingDirectory=/opt/minipc/data/anki
Restart=always
RestartSec=30

# Security hardening
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/opt/minipc/data/anki
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable anki.service
}

install_obsidian() {
    log "Installing Obsidian (AppImage + Firejail)..."

    local OBSIDIAN_DIR="/opt/minipc/data/obsidian"
    local OBSIDIAN_USER="alan"

    mkdir -p "${OBSIDIAN_DIR}"

    if [[ -f "${OBSIDIAN_DIR}/obsidian.AppImage" ]]; then
        log "Obsidian AppImage already exists, skipping download"
    else
        local OBSIDIAN_URL="https://github.com/obsidianmd/obsidian-releases/releases/download/v1.6.7/Obsidian-1.6.7.AppImage"

        log "Downloading Obsidian AppImage..."
        curl -L "${OBSIDIAN_URL}" -o "${OBSIDIAN_DIR}/obsidian.AppImage"
        chmod +x "${OBSIDIAN_DIR}/obsidian.AppImage"
    fi

    create_obsidian_firejail
    create_obsidian_systemd

    log "Obsidian installed successfully"
}

create_obsidian_firejail() {
    log "Creating Obsidian Firejail profile..."
    mkdir -p /etc/firejail

    cat > /etc/firejail/obsidian.profile << 'EOF'
# Obsidian sandbox profile
include disable-common.inc
include disable-devel.inc
include disable-interpreters.inc
include disable-programs.inc

# Allow specific access
whitelist /opt/minipc/data/obsidian
whitelist /home/alan/.config/obsidian
whitelist /home/alan/Documents

# Private home directory
private home

# Private tmp
private-tmp

# Disable networking for extra safety
net none

# Disable sound
nosound

# Disable video
novideo

# Restrict capabilities
caps.drop all

# Memory restrictions
memory-deny-write-execute
EOF

    chown root:root /etc/firejail/obsidian.profile
    chmod 644 /etc/firejail/obsidian.profile
}

create_obsidian_systemd() {
    log "Creating Obsidian systemd service..."
    cat > /etc/systemd/system/obsidian.service << 'EOF'
[Unit]
Description=Obsidian - Notes App (Headless with Firejail)
After=network.target

[Service]
Type=simple
User=alan
Group=alan
ExecStart=/usr/bin/firejail --profile=/etc/firejail/obsidian.profile /opt/minipc/data/obsidian/obsidian.AppImage --no-sandbox --headless
WorkingDirectory=/opt/minipc/data/obsidian
Restart=always
RestartSec=30

# Security hardening
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/opt/minipc/data/obsidian /home/alan/.config/obsidian
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable obsidian.service
}

install_tailscale() {
    log "Installing Tailscale (optional)..."

    if command -v tailscale &>/dev/null; then
        log "Tailscale already installed"
        return 0
    fi

    curl -fsSL https://pkgs.tailscale.com/stable/debian/tailscale.gpg -o /usr/share/keyrings/tailscale-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/tailscale-archive-keyring.gpg] https://pkgs.tailscale.com/stable/debian bookworm main" > /etc/apt/sources.list.d/tailscale.list
    apt-get update
    apt-get install -y tailscale

    systemctl enable tailscaled
    systemctl start tailscaled

    log "Tailscale installed. Run 'sudo tailscale up' to connect"
}

create_service_scripts() {
    log "Creating service management scripts..."

    cat > /opt/minipc/scripts/servicectl.sh << 'SCRIPT'
#!/bin/bash
# Service management helper
# Usage: ./servicectl.sh [start|stop|restart|status] [service]

ACTION="${1:-status}"
SERVICE="${2:-all}"

case "$SERVICE" in
    moltbot)
        sudo systemctl $ACTION moltbot
        ;;
    anki)
        sudo systemctl $ACTION anki
        ;;
    obsidian)
        sudo systemctl $ACTION obsidian
        ;;
    all)
        sudo systemctl $ACTION moltbot
        sudo systemctl $ACTION anki
        sudo systemctl $ACTION obsidian
        ;;
    *)
        echo "Unknown service: $SERVICE"
        echo "Available: moltbot, anki, obsidian, all"
        exit 1
        ;;
esac
SCRIPT

    chmod +x /opt/minipc/scripts/servicectl.sh
}

main() {
    log "=== Starting 02-services.sh ==="

    install_moltbot
    install_anki
    install_obsidian
    create_service_scripts

    log "=== 02-services.sh complete ==="
}

main
