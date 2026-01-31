#!/usr/bin/env bash
# Obsidian - Notes (accessed via sync, served via remotestorage)

app_info() {
    echo "Obsidian notes with remote sync access"
    echo "Note: Obsidian is primarily a desktop app, served via web for access"
}

app_dependencies() {
    echo "wget firejail"
}

app_ports() {
    echo ""
}

app_install() {
    local service_user="${MINIPC_SERVICE_USER:-openclaw}"
    local service_home="/var/lib/${service_user}"
    local obsidian_home="/opt/minipc/data/obsidian"

    log_info "Downloading Obsidian AppImage..."
    mkdir -p "${obsidian_home}"
    cd "${obsidian_home}"

    wget -q https://github.com/obsidianmd/obsidian-releases/releases/download/v1.6.7/Obsidian-1.6.7.AppImage -O obsidian.AppImage
    chmod +x obsidian.AppImage

    log_info "Creating Obsidian data directory..."
    mkdir -p "${service_home}/obsidian-vault"
    chown -R "${service_user}:${service_user}" "${service_home}/obsidian-vault"

    log_info "Obsidian installed (AppImage at ${obsidian_home}/obsidian.AppImage)"
    log_info "Note: Obsidian is designed for desktop use"
    log_info "For web access, consider using obsidian-livesync or similar"
}

app_configure() {
    local service_home="/var/lib/${service_user:-openclaw}"

    log_info "To use Obsidian:"
    log_info "1. Copy your vault to ${service_home}/obsidian-vault/"
    log_info "2. Or configure Obsidian to sync with a remote storage"
}
