#!/usr/bin/env bash
# 03-verify.sh - Compliance and verification checks
set -euo pipefail

STATE_DIR="/var/lib/minipc-state"
LOG_FILE="${STATE_DIR}/setup.log"
PASS=0
FAIL=0
WARN=0

log() {
    echo "[VERIFY] $(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOG_FILE"
}

check_pass() {
    echo "✓ PASS: $*"
    ((PASS++))
}

check_fail() {
    echo "✗ FAIL: $*"
    ((FAIL++))
}

check_warn() {
    echo "⚠ WARN: $*"
    ((WARN++))
}

check_status() {
    local name="$1"
    local command="$2"

    if eval "$command" &>/dev/null; then
        check_pass "$name"
    else
        check_fail "$name"
    fi
}

verify_os() {
    log "=== Verifying OS ==="

    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        if [[ "$ID" == "debian" && "$VERSION_ID" == "12" ]]; then
            check_pass "OS is Debian 12"
        else
            check_fail "OS is not Debian 12 (detected: $ID $VERSION_ID)"
        fi
    else
        check_fail "Cannot determine OS version"
    fi
}

verify_users() {
    log "=== Verifying Users ==="

    if id "alan" &>/dev/null; then
        check_pass "User alan exists"
    else
        check_fail "User alan does not exist"
    fi

    if id "moltbot" &>/dev/null; then
        check_pass "User moltbot exists"
    else
        check_fail "User moltbot does not exist"
    fi
}

verify_sudo_moltbot() {
    log "=== Verifying MoltBot Sudo Permissions ==="

    if [[ -f /etc/sudoers.d/moltbot ]]; then
        check_pass "MoltBot sudoers file exists"
        if grep -q "moltbot ALL=(ALL) NOPASSWD" /etc/sudoers.d/moltbot; then
            check_pass "MoltBot has NOPASSWD sudo"
        else
            check_fail "MoltBot NOPASSWD sudo not configured"
        fi
    else
        check_fail "MoltBot sudoers file missing"
    fi
}

verify_ssh() {
    log "=== Verifying SSH Configuration ==="

    if systemctl is-active --quiet sshd; then
        check_pass "SSH daemon is running"
    else
        check_fail "SSH daemon is not running"
    fi

    if grep -q "^Port 2222" /etc/ssh/sshd_config.d/minipc.conf 2>/dev/null; then
        check_pass "SSH port is 2222"
    else
        check_fail "SSH port is not 2222"
    fi

    if grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config.d/minipc.conf 2>/dev/null; then
        check_pass "SSH password auth disabled"
    else
        check_fail "SSH password auth not disabled"
    fi
}

verify_firewall() {
    log "=== Verifying Firewall ==="

    if ufw status | grep -q "Status: active"; then
        check_pass "UFW is active"
    else
        check_fail "UFW is not active"
    fi

    if ufw status | grep -q "2222/tcp"; then
        check_pass "SSH port 2222 allowed in firewall"
    else
        check_fail "SSH port 2222 not allowed in firewall"
    fi
}

verify_fail2ban() {
    log "=== Verifying Fail2Ban ==="

    if systemctl is-active --quiet fail2ban; then
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
    log "=== Verifying Audit ==="

    if systemctl is-active --quiet auditd; then
        check_pass "Auditd is running"
    else
        check_fail "Auditd is not running"
    fi
}

verify_apparmor() {
    log "=== Verifying AppArmor ==="

    if systemctl is-active --quiet apparmor; then
        check_pass "AppArmor is running"
    else
        check_warn "AppArmor is not running"
    fi

    if apparmor_status 2>/dev/null | grep -q "moltbot"; then
        check_pass "MoltBot AppArmor profile loaded"
    else
        check_warn "MoltBot AppArmor profile not loaded"
    fi
}

verify_moltbot() {
    log "=== Verifying MoltBot Service ==="

    if systemctl is-enabled --quiet moltbot; then
        check_pass "MoltBot service is enabled"
    else
        check_fail "MoltBot service is not enabled"
    fi

    if systemctl is-active --quiet moltbot; then
        check_pass "MoltBot service is active"
    else
        check_warn "MoltBot service is not active"
    fi

    if [[ -d /var/lib/moltbot/venv ]]; then
        check_pass "MoltBot venv exists"
    else
        check_fail "MoltBot venv missing"
    fi

    if [[ -f /var/lib/moltbot/.moltbot/moltbot.json ]]; then
        check_pass "MoltBot config exists"
    else
        check_fail "MoltBot config missing"
    fi
}

verify_anki() {
    log "=== Verifying Anki Service ==="

    if systemctl is-enabled --quiet anki; then
        check_pass "Anki service is enabled"
    else
        check_warn "Anki service is not enabled"
    fi

    if [[ -d /opt/minipc/data/anki/venv ]]; then
        check_pass "Anki venv exists"
    else
        check_fail "Anki venv missing"
    fi
}

verify_obsidian() {
    log "=== Verifying Obsidian ==="

    if [[ -f /opt/minipc/data/obsidian/obsidian.AppImage ]]; then
        check_pass "Obsidian AppImage exists"
    else
        check_fail "Obsidian AppImage missing"
    fi

    if systemctl is-enabled --quiet obsidian; then
        check_pass "Obsidian service is enabled"
    else
        check_warn "Obsidian service is not enabled"
    fi

    if [[ -f /etc/firejail/obsidian.profile ]]; then
        check_pass "Obsidian Firejail profile exists"
    else
        check_fail "Obsidian Firejail profile missing"
    fi
}

verify_btrfs_snapper() {
    log "=== Verifying Btrfs/Snapper ==="

    if mountpoint -q / && [[ "$(stat -f -c %T /)" == "btrfs" ]]; then
        check_pass "Root is Btrfs"

        if command -v snapper &>/dev/null; then
            check_pass "Snapper is installed"

            if snapper list | grep -q "Root"; then
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

verify_security_hardening() {
    log "=== Verifying Security Hardening ==="

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

verify_directories() {
    log "=== Verifying Directories ==="

    local dirs=(
        "/opt/minipc"
        "/opt/minipc/scripts"
        "/opt/minipc/config"
        "/opt/minipc/data"
        "/var/lib/minipc-state"
        "/var/lib/moltbot"
        "/var/lib/moltbot/.moltbot"
        "/var/lib/moltbot/vault"
        "/var/log/moltbot"
        "/opt/minipc/data/anki"
        "/opt/minipc/data/obsidian"
    )

    for dir in "${dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            check_pass "Directory exists: $dir"
        else
            check_fail "Directory missing: $dir"
        fi
    done
}

verify_network() {
    log "=== Verifying Network Configuration ==="

    if ufw status | grep -q "8080/tcp"; then
        check_pass "MoltBot HTTP port 8080 allowed"
    else
        check_warn "MoltBot HTTP port 8080 not allowed"
    fi

    if ufw status | grep -q "8765/tcp"; then
        check_pass "MoltBot API port 8765 allowed"
    else
        check_warn "MoltBot API port 8765 not allowed"
    fi
}

print_summary() {
    echo ""
    echo "========================================"
    echo "           VERIFICATION SUMMARY"
    echo "========================================"
    echo "  ✓ Passed:  $PASS"
    echo "  ✗ Failed:  $FAIL"
    echo "  ⚠ Warnings: $WARN"
    echo "========================================"

    if [[ $FAIL -gt 0 ]]; then
        echo ""
        echo "ERROR: $FAIL critical checks failed!"
        echo "Please review the failures above."
        exit 1
    fi

    if [[ $WARN -gt 0 ]]; then
        echo ""
        echo "WARNING: $WARN non-critical checks have warnings."
        echo "Review and address as needed."
    fi

    echo ""
    echo "SUCCESS: All critical checks passed!"
}

main() {
    log "=== Starting 03-verify.sh ==="

    verify_os
    verify_users
    verify_sudo_moltbot
    verify_ssh
    verify_firewall
    verify_fail2ban
    verify_audit
    verify_apparmor
    verify_moltbot
    verify_anki
    verify_obsidian
    verify_btrfs_snapper
    verify_security_hardening
    verify_directories
    verify_network

    print_summary

    log "=== 03-verify.sh complete ==="
}

main
