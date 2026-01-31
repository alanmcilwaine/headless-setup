#!/usr/bin/env bash
# Headless MiniPC Setup - Main Entrypoint (Debian 12)
# Usage: sudo ./bootstrap.sh [config|system|services|verify|all]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SCRIPT_DIR

STATE_DIR="/var/lib/minipc-state"
LOG_FILE="${STATE_DIR}/setup.log"
INSTALLED_MARKER="${STATE_DIR}/.installed"

# Source common library
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

run_layer() {
    local layer="$1"
    local script="${SCRIPT_DIR}/scripts/${layer}.sh"
    local force="${2:-false}"

    if [[ ! -f "$script" ]]; then
        log_error "Script not found: $script"
        exit 1
    fi

    # Config layer always runs (no skip)
    if [[ "$layer" != "00-config" ]] && [[ "$force" != "force" ]]; then
        if is_installed "$layer"; then
            log_info "Skipping $layer (already installed). Use 'force' to re-run."
            return 0
        fi
    fi

    log_info "=== Running $layer ==="
    chmod +x "$script"
    if bash "$script" 2>&1 | tee -a "$LOG_FILE"; then
        if [[ "$layer" != "00-config" ]]; then
            mark_installed "$layer"
        fi
        log_success "=== $layer completed ==="
    else
        log_error "$layer failed"
        exit 1
    fi
}

run_config() {
    # Always run config validation first
    run_layer "00-config"
}

usage() {
    cat << EOF
Usage: sudo $0 [config|system|services|verify|all] [force]

Layers:
  config   - Validate configuration (always runs first)
  system   - OS setup, security hardening, Btrfs/Snapper
  services - Install apps from apps/ directory
  verify   - Run compliance checks
  all      - Run all layers in order

Options:
  force    - Re-run layer even if already installed

Configuration:
  Edit config/config.env for settings
  Copy config/secrets.env.example to config/secrets.env for secrets

State is tracked in $STATE_DIR
Logs are written to $LOG_FILE
EOF
    exit 0
}

main() {
    require_root
    ensure_state_dir

    if [[ $# -eq 0 ]]; then
        usage
    fi

    local force_flag=""
    if [[ "${2:-}" == "force" ]]; then
        force_flag="force"
    fi

    case "$1" in
        config)
            run_config
            ;;
        system)
            run_config
            run_layer "01-system" "$force_flag"
            ;;
        services)
            run_config
            run_layer "02-services" "$force_flag"
            ;;
        verify)
            run_config
            run_layer "03-verify" "$force_flag"
            ;;
        all)
            run_config
            run_layer "01-system" "$force_flag"
            run_layer "02-services" "$force_flag"
            run_layer "03-verify" "$force_flag"
            log_success "=== ALL SETUP COMPLETE ==="
            ;;
        -h|--help|help)
            usage
            ;;
        *)
            echo "Unknown argument: $1"
            usage
            ;;
    esac
}

main "$@"
