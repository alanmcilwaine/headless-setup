#!/usr/bin/env bash
# 01-system.sh - OS setup and security hardening for Debian 12
set -euo pipefail

STATE_DIR="/var/lib/minipc-state"
CONFIG_DIR="/opt/minipc/config"
LOG_FILE="${STATE_DIR}/setup.log"

log() {
    echo "[SYSTEM] $(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOG_FILE"
}

is_debian12() {
    source /etc/os-release
    [[ "$ID" == "debian" && "$VERSION_ID" == "12" ]]
}

require_debian12() {
    if ! is_debian12; then
        log "ERROR: This script requires Debian 12. Detected: $(source /etc/os-release && echo "$ID $VERSION_ID")"
        exit 1
    fi
}

update_system() {
    log "Updating apt packages..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get upgrade -y
}

install_base_packages() {
    log "Installing base packages..."
    apt-get install -y \
        curl wget git htop btrfs-progs \
        ufw fail2ban auditd \
        python3 python3-venv python3-pip \
        sudo apparmor apparmor-utils \
        firejail \
        NetworkManager cloud-init \
        systemd-swap
}

create_users() {
    log "Creating system users..."

    if ! id "alan" &>/dev/null; then
        log "Creating alan user..."
        useradd -m -s /bin/bash -u 1000 alan
        usermod -aG sudo,adm,systemd-journal alan
    fi

    if ! id "moltbot" &>/dev/null; then
        log "Creating moltbot user..."
        useradd -r -s /usr/sbin/nologin -d /var/lib/moltbot -m moltbot
    fi
}

configure_sudo_moltbot() {
    log "Configuring limited sudo for moltbot..."
    cat > /etc/sudoers.d/moltbot << 'EOF'
# Moltbot limited sudo permissions
Cmnd_Alias MINIPC_CMDS = /usr/bin/apt update, /usr/bin/apt upgrade, /usr/bin/apt install *, \
                          /usr/bin/systemctl start *, /usr/bin/systemctl stop *, \
                          /usr/bin/systemctl restart *, /usr/bin/systemctl status *, \
                          /bin/cat /var/lib/moltbot/vault/*, \
                          /usr/bin/chown moltbot:moltbot /var/lib/moltbot/vault/*, \
                          /usr/bin/chmod 600 /var/lib/moltbot/vault/*

moltbot ALL=(ALL) NOPASSWD: SETENV: MINIPC_CMDS
Defaults!EXEMPT sudoers
EOF
    chmod 440 /etc/sudoers.d/moltbot
    visudo -c
}

configure_ssh() {
    log "Configuring SSH on port 2222..."
    mkdir -p /etc/ssh/sshd_config.d

    cat > /etc/ssh/sshd_config.d/minipc.conf << 'EOF'
Port 2222
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
X11Forwarding no
AllowTcpForwarding no
AllowUsers alan moltbot
ClientAliveInterval 300
ClientAliveCountMax 2
LogLevel INFO
EOF

    systemctl restart sshd
}

configure_firewall() {
    log "Configuring UFW firewall..."
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow 2222/tcp comment 'SSH'
    ufw allow 8080/tcp comment 'MoltBot HTTP'
    ufw allow 8765/tcp comment 'MoltBot API'
    ufw --force enable
    systemctl enable ufw
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
net.ipv4.tcp_syncookies = 1
fs.suid_dumpable = 0
kernel.sysrq = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
EOF
    sysctl --system
}

configure_fail2ban() {
    log "Configuring fail2ban..."
    cat > /etc/fail2ban/jail.local << 'EOF'
[sshd]
enabled = true
port = 2222
maxretry = 3
bantime = 3600
findtime = 600
filter = sshd[mode=normal]
logpath = /var/log/auth.log

[minipc-http]
enabled = true
port = 8080
maxretry = 5
bantime = 3600
findtime = 600
filter = apache-auth
logpath = /var/log/apache2/error.log
EOF

    systemctl enable fail2ban
    systemctl start fail2ban
}

configure_audit() {
    log "Configuring auditd..."
    cat > /etc/audit/rules.d/minipc.rules << 'EOF'
# Monitor user logins
-w /var/log/lastlog -p wa -k logins
-w /var/run/faillock/ -p wa -k logins

# Monitor sudo usage
-w /etc/sudoers.d/ -p wa -k sudoers
-w /usr/bin/sudo -p x -k exec

# Monitor moltbot operations
-w /var/lib/moltbot/ -p wa -k moltbot

# Monitor system configuration changes
-w /etc/sysctl.conf -p wa -k sysctl
-w /etc/ufw/ -p wa -k ufw
EOF

    systemctl enable auditd
    systemctl start auditd
}

configure_btrfs_snapper() {
    log "Setting up Btrfs and Snapper..."
    apt-get install -y snapper btrfs-progs

    # Check if root is Btrfs
    if mountpoint -q / && [[ "$(stat -f -c %T /)" == "btrfs" ]]; then
        log "Root is Btrfs, configuring Snapper..."
        snapper create-config /
        snapper set-config ALLOW_USERS="alan moltbot" SYNC_ACL="yes"

        # Create pre/post apt snapshot helpers
        mkdir -p /opt/minipc/scripts

        cat > /opt/minipc/scripts/snapshot-apt-pre.sh << 'SCRIPT'
#!/bin/bash
snapper create -d "Pre-apt-update-$(date +%Y%m%d-%H%M%S)" --description "Before apt operations"
SCRIPT

        cat > /opt/minipc/scripts/snapshot-apt-post.sh << 'SCRIPT'
#!/bin/bash
LATEST_PRE=$(snapper list | grep "Pre-apt-update" | tail -1 | awk '{print $1}')
if [[ -n "$LATEST_PRE" ]]; then
    snapper create -d "Post-apt-update-$(date +%Y%m%d-%H%M%S)" --description "After apt operations" --pre-number "$LATEST_PRE"
fi
SCRIPT

        chmod +x /opt/minipc/scripts/snapshot-apt-*.sh

        # Configure apt hooks
        mkdir -p /etc/apt/apt.conf.d
        cat > /etc/apt/apt.conf.d/99minipc-snapper << 'EOF'
DPkg::Pre-Invoke {"/opt/minipc/scripts/snapshot-apt-pre.sh"};
DPkg::Post-Invoke {"/opt/minipc/scripts/snapshot-apt-post.sh"};
EOF
    else
        log "Warning: Root is not Btrfs, Snapper snapshots disabled"
    fi
}

create_directories() {
    log "Creating application directories..."
    mkdir -p /opt/minipc/{scripts,config,data}
    mkdir -p /var/lib/moltbot/{.moltbot,vault,logs}
    mkdir -p /var/lib/anki/data
    mkdir -p /opt/minipc/data/{obsidian,anki}

    chown -R moltbot:moltbot /var/lib/moltbot
    chown -R alan:alan /opt/minipc/data
}

configure_monitoring() {
    log "Configuring logrotate for application logs..."
    cat > /etc/logrotate.d/minipc << 'EOF'
/var/log/moltbot/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
}
EOF
}

main() {
    require_debian12

    log "=== Starting 01-system.sh ==="

    update_system
    install_base_packages
    create_users
    configure_sudo_moltbot
    configure_ssh
    configure_firewall
    configure_sysctl
    configure_fail2ban
    configure_audit
    configure_btrfs_snapper
    create_directories
    configure_monitoring

    log "=== 01-system.sh complete ==="
}

main
