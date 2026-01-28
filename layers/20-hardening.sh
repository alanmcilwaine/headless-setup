#!/bin/bash
set -euo pipefail
# Layer 2: Hardening - Security configuration for Silverblue

log() { echo "[HARDENING] $*"; }

configure_ssh() {
    log "Configuring SSH..."
    mkdir -p /etc/ssh/sshd_config.d
    
    cat > /etc/ssh/sshd_config.d/minipc.conf << 'EOF'
Port 2222
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AllowUsers alan moltbot
Protocol 2
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ed25519_key
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com
MACs hmac-sha2-512-etm@openssh.com
KexAlgorithms curve25519-sha256
EOF

    # SSH is in the base layer, restart after apply-live/reboot
    log "SSH configured (port 2222, key-only auth)"
}

configure_firewall() {
    log "Configuring firewall..."
    
    firewall-cmd --set-default-zone=drop
    firewall-cmd --permanent --zone=drop --add-service=ssh
    firewall-cmd --permanent --zone=drop --add-service=cockpit
    firewall-cmd --reload
    
    systemctl enable firewalld
    systemctl start firewalld
}

configure_sysctl() {
    log "Configuring kernel hardening..."
    
    # Silverblue uses /usr as readonly, sysctl in /etc works
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

configure_selinux() {
    log "Configuring SELinux..."
    
    # SELinux is enforcing by default on Silverblue
    # Ensure it's in enforcing mode
    setenforce enforcing 2>/dev/null || true
    
    # Install selinux tools
    rpm-ostree install -A setroubleshoot selinux-policy-devel --idempotent --allow-inactive
}

configure_fail2ban() {
    log "Configuring fail2ban..."
    
    rpm-ostree install -A fail2ban --idempotent --allow-inactive
    
    cat > /etc/fail2ban/jail.local << 'EOF'
[sshd]
enabled = true
port = 2222
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
findtime = 600
EOF
    
    systemctl enable fail2ban
    systemctl start fail2ban
}

configure_audit() {
    log "Configuring audit..."
    
    rpm-ostree install -A audit --idempotent --allow-inactive
    
    cat > /etc/audit/rules.d/99-minipc.rules << 'EOF'
-w /etc/passwd -p wa -k identity
-w /etc/group -p wa -k identity
-w /var/lib/moltbot/ -p wa -k moltbot_data
EOF
    
    systemctl enable auditd
    systemctl start auditd
}

configure_updates() {
    log "Configuring automatic updates..."
    
    # Silverblue uses rpm-ostree-automatic
    rpm-ostree install -A rpm-ostree-automatic --idempotent --allow-inactive
    
    systemctl enable rpm-ostree-automatic.timer
    systemctl start rpm-ostree-automatic.timer
}

main() {
    configure_ssh
    configure_firewall
    configure_sysctl
    configure_selinux
    configure_fail2ban
    configure_audit
    configure_updates
    
    log ""
    log "Hardening complete."
    log "IMPORTANT: Run 'rpm-ostree apply-live' or reboot to apply changes"
}

main
