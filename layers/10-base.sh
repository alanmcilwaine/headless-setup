#!/bin/bash
set -euo pipefail
# Layer 1: Base - Fedora Silverblue system preparation

log() { echo "[BASE] $*"; }

check_silverblue() {
    if [[ ! -f /run/ostree-booted ]]; then
        log "ERROR: This script is for Fedora Silverblue/Kinoite only"
        log "Detected: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
        exit 1
    fi
    log "Detected: Fedora Silverblue/Kinoite"
}

install_base_packages() {
    log "Installing base packages (via rpm-ostree)..."
    
    rpm-ostree install \
        curl wget git htop btrfs-progs python3 \
        docker docker-compose \
        --idempotent --allow-inactive
    
    log "Packages staged. Apply with: rpm-ostree apply-live or reboot"
}

create_users() {
    log "Creating users..."
    
    if ! id "alan" &>/dev/null; then
        useradd -m -s /bin/bash -u 1000 alan
        usermod -aG sudo,wheel,docker alan
        log "Created alan user"
    fi
    
    if ! id "moltbot" &>/dev/null; then
        useradd -r -s /usr/sbin/nologin -d /var/lib/moltbot -m moltbot
        usermod -aG docker moltbot
        log "Created moltbot user"
    fi
    
    # Enable sudo for alan
    echo "alan ALL=(ALL) ALL" > /etc/sudoers.d/alan
    chmod 440 /etc/sudoers.d/alan
}

enable_services() {
    log "Enabling services..."
    
    systemctl enable docker
    systemctl start docker
}

configure_docker_socket() {
    # Allow alan user to use docker without sudo
    mkdir -p /etc/systemd/system/docker.socket.d
    cat > /etc/systemd/system/docker.socket.d/user.conf << 'EOF'
[Socket]
SocketUser=alan
SocketGroup=docker
EOF
    systemctl daemon-reload
    systemctl restart docker.socket
}

main() {
    check_silverblue
    install_base_packages
    create_users
    enable_services
    configure_docker_socket
    
    log ""
    log "Base setup complete."
    log "IMPORTANT: Run 'rpm-ostree apply-live' or reboot to apply changes"
}

main
