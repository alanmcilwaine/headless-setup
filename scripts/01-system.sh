#!/usr/bin/env bash
# 01-system.sh - OS setup and security hardening for Debian 12
set -euo pipefail

SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# Source libraries
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=../lib/security.sh
source "${SCRIPT_DIR}/lib/security.sh"

# Load configuration
load_config

update_system() {
    log_info "Updating apt packages..."
    apt-get update
    apt-get upgrade -y
}

install_base_packages() {
    log_info "Installing base packages..."
    apt-get install -y \
        curl wget git htop btrfs-progs \
        ufw fail2ban auditd \
        python3 python3-venv python3-pip \
        sudo apparmor apparmor-utils \
        firejail \
        network-manager cloud-init \
        zram-tools
}

create_users() {
    log_info "Creating system users..."

    local admin_user="${MINIPC_ADMIN_USER}"
    local service_user="${MINIPC_SERVICE_USER}"

    # Create admin user
    if ! user_exists "$admin_user"; then
        log_info "Creating $admin_user user..."
        useradd -m -s /bin/bash -u 1000 "$admin_user"
        usermod -aG sudo,adm,systemd-journal "$admin_user"
        log_success "Created admin user: $admin_user"
    else
        log_info "User $admin_user already exists"
    fi

    # Create service user
    if ! user_exists "$service_user"; then
        log_info "Creating $service_user user..."
        useradd -r -s /usr/sbin/nologin -d "/var/lib/${service_user}" -m "$service_user"
        log_success "Created service user: $service_user"
    else
        log_info "User $service_user already exists"
    fi
}

configure_ssh() {
    local ssh_port="${SSH_PORT}"
    local allowed_users="${SSH_ALLOWED_USERS}"

    log_info "Configuring SSH on port $ssh_port..."
    mkdir -p /etc/ssh/sshd_config.d

    cat > /etc/ssh/sshd_config.d/minipc.conf << EOF
Port ${ssh_port}
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
X11Forwarding no
AllowTcpForwarding no
AllowUsers ${allowed_users}
ClientAliveInterval 300
ClientAliveCountMax 2
LogLevel INFO
EOF

    systemctl restart sshd
    log_success "SSH configured on port $ssh_port"
}

configure_firewall() {
    local tcp_ports="${FIREWALL_ALLOW_TCP}"

    log_info "Configuring UFW firewall..."

    # Reset UFW to defaults
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing

    # Allow configured TCP ports
    for port in $tcp_ports; do
        ufw allow "${port}/tcp" comment "Configured port"
        log_info "Allowed port: ${port}/tcp"
    done

    ufw --force enable
    systemctl enable ufw

    log_success "Firewall configured"
}

configure_sysctl() {
    log_info "Configuring kernel hardening..."
    cat > /etc/sysctl.d/99-minipc.conf << 'EOF'
# Network security
kernel.randomize_va_space = 2
net.ipv4.conf.all.rp_filter = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0

# Core dumps
fs.suid_dumpable = 0

# Magic SysRq
kernel.sysrq = 0
EOF
    sysctl --system
    log_success "Kernel hardening applied"
}

configure_fail2ban() {
    local ssh_port="${SSH_PORT}"

    log_info "Configuring fail2ban..."
    cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
backend = systemd

[sshd]
enabled = true
port = ${ssh_port}
filter = sshd[mode=normal]
EOF

    systemctl enable fail2ban
    systemctl restart fail2ban || systemctl start fail2ban
    log_success "Fail2ban configured"
}

configure_audit() {
    local service_user="${MINIPC_SERVICE_USER}"

    log_info "Configuring auditd..."
    cat > /etc/audit/rules.d/minipc.rules << EOF
# Monitor user logins
-w /var/log/lastlog -p wa -k logins
-w /var/run/faillock/ -p wa -k logins

# Monitor sudo usage
-w /etc/sudoers.d/ -p wa -k sudoers
-w /usr/bin/sudo -p x -k exec

# Monitor service user operations
-w /var/lib/${service_user}/ -p wa -k ${service_user}

# Monitor system configuration changes
-w /etc/sysctl.conf -p wa -k sysctl
-w /etc/ufw/ -p wa -k ufw
EOF

    systemctl enable auditd
    systemctl start auditd
    log_success "Auditd configured"
}

configure_btrfs_snapper() {
    if [[ "${ENABLE_BTRFS_SNAPSHOTS:-false}" != "true" ]]; then
        log_info "Btrfs snapshots disabled in config"
        return 0
    fi

    log_info "Setting up Btrfs and Snapper..."
    apt-get install -y snapper btrfs-progs

    # Check if root is Btrfs
    if mountpoint -q / && [[ "$(stat -f -c %T /)" == "btrfs" ]]; then
        log_info "Root is Btrfs, configuring Snapper..."

        local admin_user="${MINIPC_ADMIN_USER}"
        local service_user="${MINIPC_SERVICE_USER}"

        snapper create-config / 2>/dev/null || true
        snapper set-config ALLOW_USERS="${admin_user} ${service_user}" SYNC_ACL="yes"

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

        log_success "Snapper configured for Btrfs snapshots"
    else
        log_warn "Root is not Btrfs, Snapper snapshots disabled"
    fi
}

create_directories() {
    local admin_user="${MINIPC_ADMIN_USER}"
    local service_user="${MINIPC_SERVICE_USER}"

    log_info "Creating application directories..."

    # Core directories
    mkdir -p /opt/minipc/{scripts,config,data}
    mkdir -p "${STATE_DIR}"

    # Service user directories
    mkdir -p "/var/lib/${service_user}"/{.openclaw,vault,logs}
    mkdir -p "/var/log/${service_user}"

    # App data directories
    mkdir -p /opt/minipc/data/{obsidian,anki}

    # Privilege escalation directories
    mkdir -p "/var/lib/${service_user}"/{requests,approved}

    # Set ownership
    chown -R "${service_user}:${service_user}" "/var/lib/${service_user}"
    chown -R "${service_user}:${service_user}" "/var/log/${service_user}"
    chown -R "${admin_user}:${admin_user}" /opt/minipc/data

    log_success "Directories created"
}

configure_monitoring() {
    local service_user="${MINIPC_SERVICE_USER}"

    log_info "Configuring logrotate for application logs..."
    cat > /etc/logrotate.d/minipc << EOF
/var/log/${service_user}/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
}
EOF
    log_success "Logrotate configured"
}

configure_hostname() {
    local hostname="${MINIPC_HOSTNAME}"

    log_info "Setting hostname to $hostname..."
    hostnamectl set-hostname "$hostname"

    # Update /etc/hosts if needed
    if ! grep -q "$hostname" /etc/hosts; then
        echo "127.0.1.1 $hostname" >> /etc/hosts
    fi

    log_success "Hostname set to $hostname"
}

install_tailscale() {
    if [[ "${ENABLE_TAILSCALE:-false}" != "true" ]]; then
        log_info "Tailscale disabled in config"
        return 0
    fi

    log_info "Installing Tailscale..."

    if command_exists tailscale; then
        log_info "Tailscale already installed"
        return 0
    fi

    # Fix hostname resolution for sudo
    if ! grep -q "127.0.1.1.*$(hostname)" /etc/hosts; then
        echo "127.0.1.1 $(hostname)" >> /etc/hosts
    fi

    # Install Tailscale using official install script
    curl -fsSL https://tailscale.com/install.sh | sh

    systemctl enable tailscaled
    systemctl start tailscaled

    log_success "Tailscale installed. Run 'sudo tailscale up' to connect"
}

main() {
    require_debian12

    log_info "=== Starting 01-system.sh ==="

    update_system
    install_base_packages
    create_users
    configure_hostname
    configure_ssh
    configure_firewall
    configure_sysctl
    configure_fail2ban
    configure_audit
    configure_btrfs_snapper
    create_directories
    configure_monitoring
    install_tailscale

    log_success "=== 01-system.sh complete ==="
}

main
