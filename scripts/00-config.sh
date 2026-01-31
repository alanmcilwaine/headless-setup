#!/usr/bin/env bash
# 00-config.sh - Configuration validation
set -euo pipefail

SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "${SCRIPT_DIR}/lib/common.sh"

load_config

log_info "Validating configuration..."

if [[ -z "${MINIPC_ADMIN_USER:-}" ]]; then
    log_error "MINIPC_ADMIN_USER not set in config"
    exit 1
fi

if [[ -z "${MINIPC_SERVICE_USER:-}" ]]; then
    log_error "MINIPC_SERVICE_USER not set in config"
    exit 1
fi

if [[ -z "${ENABLED_APPS:-}" ]]; then
    log_error "ENABLED_APPS not set in config"
    exit 1
fi

log_success "Configuration validated"
log_info "Admin user: $MINIPC_ADMIN_USER"
log_info "Service user: $MINIPC_SERVICE_USER"
log_info "Enabled apps: $ENABLED_APPS"
