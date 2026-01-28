#!/bin/bash
set -euo pipefail
# Layer 1: Base - System preparation and user setup

log() { echo "[BASE] $*"; }

detect_os() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        echo "$ID"
    else
        echo "unknown"
    fi
}

OS=$(detect_os)
log "Detected: $OS"

case "$OS" in
    fedora)
        dnf install -y curl wget git htop btrfs-progs python3 docker
        systemctl enable --now docker
        ;;
    debian|ubuntu)
        apt-get update
        apt-get install -y curl wget git htop btrfs-progs python3 docker.io
        systemctl enable --now docker
        ;;
    *)
        log "Unsupported OS: $OS"
        exit 1
        ;;
esac

if ! id "deploy" &>/dev/null; then
    log "Creating deploy user..."
    useradd -m -s /bin/bash -u 1000 deploy
    usermod -aG sudo,docker deploy
fi

if ! id "moltbot" &>/dev/null; then
    log "Creating moltbot user..."
    useradd -r -s /usr/sbin/nologin -d /var/lib/moltbot -m moltbot
    usermod -aG docker moltbot
fi

mkdir -p /etc/systemd/system/docker.service.d
log "Base setup complete."
