#!/usr/bin/env bash
# 03-verify.sh - Compliance and verification checks
set -euo pipefail

SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# Source libraries
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

# Load configuration
load_config

# Counters
PASS=0
FAIL=0
WARN=0

check_pass() {
    echo -e "${GREEN}✓ PASS:${NC} $*"
    PASS=$((PASS + 1))
}

check_fail() {
    echo -e "${RED}✗ FAIL:${NC} $*"
    FAIL=$((FAIL + 1))
}

check_warn() {
    echo -e "${YELLOW}⚠ WARN:${NC} $*"
    WARN=$((WARN + 1))
}

verify_os() {
    log_info "=== Verifying OS ==="

    if is_debian12; then
        check_pass "OS is Debian 12"
    else
        check_fail "OS is not Debian 12"
    fi
}

verify_users() {
    log_info "=== Verifying Users ==="

    local admin_user="${MINIPC_ADMIN_USER}"
    local service_user="${MINIPC_SERVICE_USER}"

    if user_exists "$admin_user"; then
        check_pass "User $admin_user exists"
    else
        check_fail "User $admin_user does not exist"
    fi

    if user_exists "$service_user"; then
        check_pass "User $service_user exists"
    else
        check_fail "User $service_user does not exist"
    fi
}

verify_sudo_openclaw() {
    log_info "=== Verifying Service User Sudo Permissions ==="

    local service_user="${MINIPC_SERVICE_USER}"

    if [[ -f "/etc/sudoers.d/${service_user}" ]]; then
        check_pass "Sudoers file exists for $service_user"

        # Check for wildcards (security concern)
        if grep -q '\*' "/etc/sudoers.d/${service_user}"; then
            check_warn "Sudoers file contains wildcards (intentional for service user)"
        else
            check_pass "Sudoers file has no wildcards"
        fi

        # Verify syntax
        if visudo -c -f "/etc/sudoers.d/${service_user}" 2>/dev/null; then
            check_pass "Sudoers file syntax is valid"
        else
            check_fail "Sudoers file syntax is invalid"
        fi
    else
        check_warn "Sudoers file missing for $service_user"
    fi
}

verify_ssh() {
    log_info "=== Verifying SSH Configuration ==="

    local ssh_port="${SSH_PORT}"

    if service_is_active sshd; then
        check_pass "SSH daemon is running"
    else
        check_fail "SSH daemon is not running"
    fi

    if [[ -f /etc/ssh/sshd_config.d/minipc.conf ]]; then
        if grep -q "^Port ${ssh_port}" /etc/ssh/sshd_config.d/minipc.conf; then
            check_pass "SSH port is $ssh_port"
        else
            check_fail "SSH port is not $ssh_port"
        fi

        if grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config.d/minipc.conf; then
            check_pass "SSH password auth disabled"
        else
            check_fail "SSH password auth not disabled"
        fi

        if grep -q "^PermitRootLogin no" /etc/ssh/sshd_config.d/minipc.conf; then
            check_pass "SSH root login disabled"
        else
            check_fail "SSH root login not disabled"
        fi
    else
        check_fail "SSH config file /etc/ssh/sshd_config.d/minipc.conf missing"
    fi
}

verify_firewall() {
    log_info "=== Verifying Firewall ==="

    if ufw status | grep -q "Status: active"; then
        check_pass "UFW is active"
    else
        check_fail "UFW is not active"
    fi

    local ssh_port="${SSH_PORT}"
    if ufw status | grep -q "${ssh_port}/tcp"; then
        check_pass "SSH port $ssh_port allowed in firewall"
    else
        check_fail "SSH port $ssh_port not allowed in firewall"
    fi

    # Check configured ports
    for port in ${FIREWALL_ALLOW_TCP}; do
        if ufw status | grep -q "${port}/tcp"; then
            check_pass "Port $port/tcp allowed"
        else
            check_warn "Port $port/tcp not allowed"
        fi
    done
}

verify_fail2ban() {
    log_info "=== Verifying Fail2Ban ==="

    if service_is_active fail2ban; then
        check_pass "Fail2Ban is running"
    else
        check_fail "Fail2Ban is not running"
    fi

    if fail2ban-client status sshd &>/dev/null; then
        check_pass "Fail2Ban SSH jail configured"
    else
        check_warn "Fail2Ban SSH jail not configured"
    fi
}

verify_audit() {
    log_info "=== Verifying Audit ==="

    if service_is_active auditd; then
        check_pass "Auditd is running"
    else
        check_fail "Auditd is not running"
    fi
}

verify_apparmor() {
    log_info "=== Verifying AppArmor ==="

    if service_is_active apparmor; then
        check_pass "AppArmor is running"
    else
        check_warn "AppArmor is not running"
    fi
}

verify_security_hardening() {
    log_info "=== Verifying Security Hardening ==="

    if sysctl kernel.randomize_va_space 2>/dev/null | grep -q "= 2"; then
        check_pass "ASLR enabled"
    else
        check_fail "ASLR not enabled"
    fi

    if sysctl net.ipv4.tcp_syncookies 2>/dev/null | grep -q "= 1"; then
        check_pass "TCP SYN cookies enabled"
    else
        check_fail "TCP SYN cookies not enabled"
    fi

    if [[ -f /etc/sysctl.d/99-minipc.conf ]]; then
        check_pass "Custom sysctl config exists"
    else
        check_fail "Custom sysctl config missing"
    fi
}

verify_btrfs_snapper() {
    log_info "=== Verifying Btrfs/Snapper ==="

    if [[ "${ENABLE_BTRFS_SNAPSHOTS:-false}" != "true" ]]; then
        check_pass "Btrfs snapshots disabled in config (skipping)"
        return 0
    fi

    if mountpoint -q / && [[ "$(stat -f -c %T /)" == "btrfs" ]]; then
        check_pass "Root is Btrfs"

        if command_exists snapper; then
            check_pass "Snapper is installed"

            if snapper list &>/dev/null; then
                check_pass "Snapper config exists for root"
            else
                check_warn "Snapper config missing for root"
            fi
        else
            check_fail "Snapper not installed"
        fi
    else
        check_warn "Root is not Btrfs (snapshots disabled)"
    fi
}

verify_directories() {
    log_info "=== Verifying Directories ==="

    local service_user="${MINIPC_SERVICE_USER}"

    local dirs=(
        "/opt/minipc"
        "/opt/minipc/scripts"
        "/opt/minipc/config"
        "/opt/minipc/data"
        "${STATE_DIR}"
        "/var/lib/${service_user}"
        "/var/log/${service_user}"
    )

    for dir in "${dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            check_pass "Directory exists: $dir"
        else
            check_fail "Directory missing: $dir"
        fi
    done
}

verify_app() {
    local app_name="$1"
    local app_file="${APPS_DIR}/${app_name}.sh"

    log_info "=== Verifying App: $app_name ==="

    if [[ ! -f "$app_file" ]]; then
        check_fail "App file not found: $app_file"
        return 1
    fi

    # Source the app file
    # shellcheck source=/dev/null
    source "$app_file"

    # Run app's verify function
    if declare -f app_verify &>/dev/null; then
        if app_verify; then
            check_pass "$app_name verification passed"
        else
            check_fail "$app_name verification failed"
        fi
    else
        check_warn "$app_name has no verify function"
    fi

    # Check if service exists and is enabled
    if systemctl list-unit-files | grep -q "^${app_name}.service"; then
        if service_is_enabled "$app_name"; then
            check_pass "$app_name service is enabled"
        else
            check_warn "$app_name service is not enabled"
        fi
    fi

    # Check AppArmor profile if exists
    if [[ -f "/etc/apparmor.d/${app_name}" ]]; then
        if apparmor_status 2>/dev/null | grep -q "$app_name"; then
            check_pass "$app_name AppArmor profile loaded"
        else
            check_warn "$app_name AppArmor profile not loaded"
        fi
    fi
}

verify_enabled_apps() {
    log_info "=== Verifying Enabled Applications ==="

    for app in ${ENABLED_APPS}; do
        verify_app "$app"
    done
}

print_summary() {
    echo ""
    echo "========================================"
    echo "           VERIFICATION SUMMARY"
    echo "========================================"
    echo -e "  ${GREEN}✓ Passed:${NC}   $PASS"
    echo -e "  ${RED}✗ Failed:${NC}   $FAIL"
    echo -e "  ${YELLOW}⚠ Warnings:${NC} $WARN"
    echo "========================================"

    if [[ $FAIL -gt 0 ]]; then
        echo ""
        echo -e "${RED}ERROR: $FAIL critical checks failed!${NC}"
        echo "Please review the failures above."
        exit 1
    fi

    if [[ $WARN -gt 0 ]]; then
        echo ""
        echo -e "${YELLOW}WARNING: $WARN non-critical checks have warnings.${NC}"
        echo "Review and address as needed."
    fi

    echo ""
    echo -e "${GREEN}SUCCESS: All critical checks passed!${NC}"
}

main() {
    log_info "=== Starting 03-verify.sh ==="

    verify_os
    verify_users
    verify_sudo_openclaw
    verify_ssh
    verify_firewall
    verify_fail2ban
    verify_audit
    verify_apparmor
    verify_security_hardening
    verify_btrfs_snapper
    verify_directories
    verify_enabled_apps

    print_summary

    log_success "=== 03-verify.sh complete ==="
}

main
