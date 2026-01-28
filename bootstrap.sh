#!/usr/bin/env bash
# Headless MiniPC Setup - Main Entrypoint (Debian 12)
# Usage: sudo ./bootstrap.sh [system|services|verify|all]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="/var/lib/minipc-state"
LOG_FILE="${STATE_DIR}/setup.log"
INSTALLED_MARKER="${STATE_DIR}/.installed"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

ensure_state_dir() {
    mkdir -p "$STATE_DIR"
    touch "$LOG_FILE"
}

is_installed() {
    [[ -f "${INSTALLED_MARKER}.$1" ]]
}

mark_installed() {
    touch "${INSTALLED_MARKER}.$1"
}

run_layer() {
    local layer="$1"
    local script="${SCRIPT_DIR}/scripts/${layer}.sh"

    if [[ ! -f "$script" ]]; then
        log "ERROR: Script not found: $script"
        exit 1
    fi

    if is_installed "$layer"; then
        log "Skipping $layer (already installed)"
        return 0
    fi

    log "=== Running $layer ==="
    chmod +x "$script"
    if bash "$script" 2>&1 | tee -a "$LOG_FILE"; then
        mark_installed "$layer"
        log "=== $layer completed ==="
    else
        log "ERROR: $layer failed"
        exit 1
    fi
}

usage() {
    cat << EOF
Usage: sudo $0 [system|services|verify|all]

Layers:
  system   - OS setup, security hardening, Btrfs/Snapper
  services - Install apps (MoltBot, Anki, Obsidian)
  verify   - Run compliance checks
  all      - Run all layers in order

State is tracked in $STATE_DIR
EOF
    exit 0
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "Error: This script must be run as root (use sudo)"
        exit 1
    fi
}

main() {
    check_root
    ensure_state_dir

    if [[ $# -eq 0 ]]; then
        usage
    fi

    case "$1" in
        system)
            run_layer "01-system"
            ;;
        services)
            run_layer "02-services"
            ;;
        verify)
            run_layer "03-verify"
            ;;
        all)
            run_layer "01-system"
            run_layer "02-services"
            run_layer "03-verify"
            log "=== ALL SETUP COMPLETE ==="
            ;;
        *)
            echo "Unknown argument: $1"
            usage
            ;;
    esac
}

main "$@"
