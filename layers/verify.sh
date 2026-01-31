#!/bin/bash
set -euo pipefail
# Verification script - checks all layers

log() { echo "[VERIFY] $*"; }

ERRORS=0
WARNINGS=0

pass() { echo "  ✓ $1"; }
fail() { echo "  ✗ $1"; ((ERRORS++)); }
warn() { echo "  ⚠ $1"; ((WARNINGS++)); }

echo ""
echo "=== MiniPC Verification ==="

echo ""
echo "Users:"
id deploy &>/dev/null && pass "deploy user" || fail "deploy user"
id openclaw &>/dev/null && pass "openclaw user" || fail "openclaw user"

echo ""
echo "SSH:"
grep -q "Port 2222" /etc/ssh/sshd_config.d/*.conf 2>/dev/null && pass "SSH on 2222" || fail "SSH not on 2222"
grep -q "PermitRootLogin no" /etc/ssh/sshd_config.d/*.conf 2>/dev/null && pass "Root login disabled" || fail "Root login enabled"
grep -q "PasswordAuthentication no" /etc/ssh/sshd_config.d/*.conf 2>/dev/null && pass "Password auth disabled" || warn "Password auth unknown"

echo ""
echo "Firewall:"
systemctl is-active ufw &>/dev/null && pass "UFW active" || \
    systemctl is-active firewalld &>/dev/null && pass "firewalld active" || warn "No firewall active"

echo ""
echo "Docker:"
systemctl is-active docker &>/dev/null && pass "Docker running" || fail "Docker not running"
docker network inspect minipc &>/dev/null && pass "minipc network exists" || warn "minipc network missing"

echo ""
echo "Openclaw:"
command -v openclaw &>/dev/null && pass "Openclaw installed" || fail "Openclaw not installed"
systemctl is-enabled openclaw &>/dev/null && pass "Openclaw enabled" || warn "Openclaw not enabled"
systemctl is-active openclaw &>/dev/null && pass "Openclaw running" || warn "Openclaw not running"
[[ -f /var/lib/openclaw/.openclaw/openclaw.json ]] && pass "Config exists" || fail "Config missing"

if [[ -f /var/lib/openclaw/.openclaw/openclaw.json ]]; then
    grep -q '"dmPolicy":\s*"pairing"' /var/lib/openclaw/.openclaw/openclaw.json && pass "DM pairing" || warn "DM pairing off"
    grep -q '"bind":\s*"loopback"' /var/lib/openclaw/.openclaw/openclaw.json && pass "Loopback bind" || warn "Loopback bind off"
fi

echo ""
echo "Recovery:"
command -v snapper &>/dev/null && pass "Snapper installed" || warn "Snapper not installed"
systemctl is-active snapper-timeline.timer &>/dev/null && pass "Snapper timer" || warn "Snapper timer off"
[[ -d /backup ]] && pass "Backup dir exists" || warn "Backup dir missing"

echo ""
echo "=== Summary ==="
echo "Errors: $ERRORS, Warnings: $WARNINGS"

if [[ $ERRORS -eq 0 ]]; then
    echo "✓ System looks good"
    exit 0
else
    echo "✗ Fix errors above"
    exit 1
fi
