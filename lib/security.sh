#!/usr/bin/env bash
# Security library functions

configure_audit_rules() {
    local service_user="${MINIPC_SERVICE_USER}"
    local admin_user="${MINIPC_ADMIN_USER}"

    cat > /etc/audit/rules.d/minipc.rules << EOF
-w /var/log/lastlog -p wa -k logins
-w /var/run/faillock/ -p wa -k logins
-w /etc/sudoers.d/ -p wa -k sudoers
-w /usr/bin/sudo -p x -k exec
-w /var/lib/${service_user}/ -p wa -k ${service_user}
-w /etc/sysctl.conf -p wa -k sysctl
-w /etc/ufw/ -p wa -k ufw
EOF
}

configure_firewall_rules() {
    local tcp_ports="${FIREWALL_ALLOW_TCP}"
    for port in $tcp_ports; do
        ufw allow "${port}/tcp" comment "Configured port"
    done
}
