#!/bin/bash
set -euo pipefail
# Layer 2: Hardening - Security configuration

log() { echo "[HARDENING] $*"; }

OS=$(source /etc/os-release && echo "$ID")

configure_ssh() {
    log "Configuring SSH..."
    mkdir -p /etc/ssh/sshd_config.d
    cat > /etc/ssh/sshd_config.d/minipc.conf << 'EOF'
Port 2222
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AllowUsers deploy moltbot
EOF
    systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null
}

configure_firewall() {
    log "Configuring firewall..."
    
    case "$OS" in
        fedora)
            firewall-cmd --set-default-zone=drop
            firewall-cmd --permanent --zone=drop --add-service=ssh
            firewall-cmd --reload
            systemctl enable firewalld
            ;;
        debian|ubuntu)
            apt-get install -y ufw
            ufw default deny incoming
            ufw default allow outgoing
            ufw allow 2222/tcp
            ufw --force enable
            systemctl enable ufw
            ;;
    esac
}

configure_sysctl() {
    log "Configuring kernel hardening..."
    cat > /etc/sysctl.d/99-minipc.conf << 'EOF'
kernel.randomize_va_space = 2
net.ipv4.conf.all.rp_filter = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
fs.suid_dumpable = 0
EOF
    sysctl --system 2>/dev/null || true
}

configure_fail2ban() {
    log "Configuring fail2ban..."
    apt-get install -y fail2ban 2>/dev/null || dnf install -y fail2ban 2>/dev/null || true
    
    cat > /etc/fail2ban/jail.local << 'EOF'
[sshd]
enabled = true
port = 2222
maxretry = 3
bantime = 3600
EOF
    systemctl enable fail2ban 2>/dev/null || true
}

configure_monitoring() {
    log "Configuring monitoring..."
    case "$OS" in
        fedora)
            dnf install -y audit
            systemctl enable auditd
            ;;
        debian|ubuntu)
            apt-get install -y auditd
            systemctl enable auditd
            ;;
    esac
}

configure_updates() {
    log "Configuring automatic updates..."
    case "$OS" in
        fedora)
            dnf install -y dnf-automatic
            systemctl enable dnf-automatic.timer
            systemctl start dnf-automatic.timer
            ;;
        debian|ubuntu)
            apt-get install -y unattended-upgrades
            cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
};
EOF
            systemctl enable unattended-upgrades
            ;;
    esac
}

configure_ssh
configure_firewall
configure_sysctl
configure_fail2ban
configure_monitoring
configure_updates

log "Hardening complete."
