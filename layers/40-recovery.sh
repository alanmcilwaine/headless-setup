#!/bin/bash
set -euo pipefail
# Layer 4: Recovery - Btrfs snapshots and backups

log() { echo "[RECOVERY] $*"; }

install_snapper() {
    log "Installing snapper..."
    case "$(source /etc/os-release && echo "$ID")" in
        fedora) dnf install -y snapper ;;
        debian|ubuntu) apt-get install -y snapper ;;
    esac
}

configure_snapper() {
    log "Configuring snapper..."
    
    if mount | grep -q " / " | grep -q btrfs; then
        if [[ ! -f /etc/snapper/configs/root ]]; then
            snapper -c root create-config /
        fi
        
        cat > /etc/snapper/configs/root << 'EOF'
SUBVOLUME="/"
TIMELINE_LIMIT_HOURLY="24"
TIMELINE_LIMIT_DAILY="7"
TIMELINE_LIMIT_WEEKLY="4"
NUMBER_CLEANUP="yes"
SPACE_CLEANUP="yes"
EOF
        
        systemctl enable snapper-timeline.timer
        systemctl enable snapper-cleanup.timer
        systemctl start snapper-timeline.timer
        systemctl start snapper-cleanup.timer
    else
        log "Root is not Btrfs. Snapper will not work."
    fi
}

create_scripts() {
    log "Creating recovery scripts..."
    
    mkdir -p /opt/minipc/scripts
    
    cat > /opt/minipc/scripts/snapshot.sh << 'EOF'
#!/bin/bash
DESC="${1:-manual}"
snapper -c root create -d "$DESC" --cleanup algorithm 2>/dev/null || \
    btrfs subvolume snapshot -r / "/@snapshots/snap_$(date +%Y%m%d_%H%M%S)_${DESC// /-}" 2>/dev/null
EOF
    chmod +x /opt/minipc/scripts/snapshot.sh
    
    cat > /opt/minipc/scripts/restore.sh << 'EOF'
#!/bin/bash
NUM="$1"
if [[ -z "$NUM" ]]; then
    snapper list
    echo "Usage: $0 <snapshot-number>"
    exit 1
fi
read -p "Rollback to #$NUM? (y/N): " confirm
[[ "$confirm" == "y" ]] && snapper -c root rollback "$NUM" && reboot
EOF
    chmod +x /opt/minipc/scripts/restore.sh
}

configure_backup_mount() {
    log "Setting up backup mount point..."
    mkdir -p /backup
    
    if ! mount | grep -q "/backup"; then
        log "Add to /etc/fstab: UUID=<backup-uuid> /backup btrfs defaults 0 0"
    fi
}

install_snapper
configure_snapper
create_scripts
configure_backup_mount

log "Recovery setup complete."
log "Create snapshot: sudo /opt/minipc/scripts/snapshot.sh 'Pre-update'"
log "Rollback: sudo /opt/minipc/scripts/restore.sh <number>"
