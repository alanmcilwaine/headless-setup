#!/bin/bash
set -euo pipefail
# MiniPC Infrastructure - Fedora Silverblue Bootstrap
# Layers: Base → Hardening → DevTools → Runtime → Recovery

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAYER="${1:-all}"
STATE_DIR="/var/lib/minipc-state"

mkdir -p "$STATE_DIR"

log() {
    echo "[$(date +%H:%M:%S)] [$LAYER] $*"
    echo "[$(date +%Y-%m-%dT%H:%M:%S)] [$LAYER] $*" >> "$STATE_DIR/install.log"
}

run_layer() {
    local layer="$1"
    local script="$SCRIPT_DIR/layers/$layer.sh"
    local stamp="$STATE_DIR/${layer}.complete"
    
    if [[ -f "$stamp" ]]; then
        log "Skipping $layer (already done)"
        return 0
    fi
    
    if [[ -f "$script" ]]; then
        log "Running $layer..."
        if bash "$script" 2>&1 | tee -a "$STATE_DIR/install.log"; then
            touch "$stamp"
            log "✓ $layer complete"
        else
            log "✗ $layer failed"
            return 1
        fi
    else
        log "Layer not found: $script"
        return 1
    fi
}

if [[ $EUID -ne 0 ]]; then
    echo "Run with: sudo $0 [layer]"
    echo "Layers: base hardening devtools runtime recovery verify all"
    echo ""
    echo "Usage:"
    echo "  sudo $0 all          # Run all layers"
    echo "  sudo $0 base         # Layer 1: Base system"
    echo "  sudo $0 hardening    # Layer 2: Security"
    echo "  sudo $0 devtools     # Layer 2.5: Development tools"
    echo "  sudo $0 runtime      # Layer 3: Moltbot"
    echo "  sudo $0 recovery     # Layer 4: Snapshots"
    echo "  sudo $0 verify       # Verify installation"
    exit 1
fi

case "$LAYER" in
    base)        run_layer "10-base" ;;
    hardening)   run_layer "20-hardening" ;;
    devtools)    run_layer "25-devtools" ;;
    runtime)     run_layer "30-runtime" ;;
    recovery)    run_layer "40-recovery" ;;
    verify)      bash "$SCRIPT_DIR/layers/verify.sh" ;;
    all)         run_layer "10-base" && run_layer "20-hardening" && run_layer "25-devtools" && run_layer "30-runtime" && run_layer "40-recovery" ;;
    *)           echo "Unknown layer: $LAYER"; exit 1 ;;
esac

log "Done."
echo ""
echo "IMPORTANT: After running layers, apply changes with:"
echo "  rpm-ostree apply-live"
echo "  # or"
echo "  sudo reboot"
echo ""
echo "Then verify: sudo ./layers/verify.sh"
