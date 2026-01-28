#!/bin/bash
set -euo pipefail
# Layer 4: Recovery - Btrfs snapshots and backups

log() { echo "[RECOVERY] $*"; }

check_btrfs() {
    if mount | grep -q " / " | grep -q btrfs; then
        log "Root filesystem is Btrfs"
        return 0
    else
        log "Warning: Root is not Btrfs, snapshots will not work"
        return 1
    fi
}

install_snapper() {
    log "Installing snapper..."
    
    rpm-ostree install -A snapper --idempotent --allow-inactive
}

configure_snapper() {
    log "Configuring snapper..."
    
    if mount | grep -q " / " | grep -q btrfs; then
        if [[ ! -f /etc/snapper/configs/root ]]; then
            snapper -c root create-config /
        fi
        
        cat > /etc/snapper/configs/root << 'EOF'
SUBVOLUME="/"
ALLOW_USERS="alan moltbot"
SYNC_ACL="yes"
TIMELINE_LIMIT_HOURLY="24"
TIMELINE_LIMIT_DAILY="7"
TIMELINE_LIMIT_WEEKLY="4"
TIMELINE_LIMIT_MONTHLY="12"
NUMBER_CLEANUP="yes"
SPACE_CLEANUP="yes"
EOF
        
        systemctl enable snapper-timeline.timer
        systemctl enable snapper-cleanup.timer
        systemctl start snapper-timeline.timer
        systemctl start snapper-cleanup.timer
        
        log "Snapper configured"
    fi
}

create_scripts() {
    log "Creating recovery scripts..."
    
    mkdir -p /opt/minipc/scripts
    
    cat > /opt/minipc/scripts/snapshot.sh << 'EOF'
#!/bin/bash
DESC="${1:-manual}"
snapper -c root create -d "$DESC" --cleanup algorithm
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
    
    log "Scripts created: /opt/minipc/scripts/{snapshot,restore}.sh"
}

setup_backup_partition() {
    log "Setting up backup mount point..."
    
    mkdir -p /backup
    
    log "Add to /etc/fstab for persistent mount:"
    log "  UUID=<backup-uuid> /backup btrfs defaults 0 0"
}

create_backup_script() {
    mkdir -p /opt/minipc/scripts
    
    cat > /opt/minipc/scripts/backup.sh << 'EOF'
#!/bin/bash
set -euo pipefail

BACKUP_MOUNT="${BACKUP_MOUNT:-/backup}"
DATE=$(date +%Y%m%d_%H%M%S)

if [[ ! -d "$BACKUP_MOUNT" ]]; then
    echo "Backup mount not available: $BACKUP_MOUNT"
    exit 1
fi

echo "Creating backup snapshot..."
btrfs subvolume snapshot -r / "@_backup_$DATE"
btrfs send "@_backup_$DATE" | btrfs receive "$BACKUP_MOUNT/"

echo "Backup complete: @_backup_$DATE"
EOF
    chmod +x /opt/minipc/scripts/backup.sh
    
    log "Backup script created: /opt/minipc/scripts/backup.sh"
}

main() {
    if check_btrfs; then
        install_snapper
        configure_snapper
    fi
    
    create_scripts
    setup_backup_partition
    create_backup_script
    
    log ""
    log "Recovery setup complete."
    log ""
    log "Commands:"
    log "  sudo /opt/minipc/scripts/snapshot.sh 'Pre-update'"
    log "  sudo /opt/minipc/scripts/restore.sh <number>"
    log "  sudo /opt/minipc/scripts/backup.sh"
    log "  snapper list"
}

main
