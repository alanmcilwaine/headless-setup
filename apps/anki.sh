#!/usr/bin/env bash
# Anki - Flashcard server (anki-sync-server or a2cserver)

app_info() {
    echo "Anki flashcard server for remote access"
    echo "Uses anki-sync-server for headless operation"
}

app_dependencies() {
    echo "python3 python3-pip git"
}

app_ports() {
    echo "27701"
}

app_install() {
    local service_user="${MINIPC_SERVICE_USER:-openclaw}"
    local service_home="/var/lib/${service_user}"
    local anki_home="${service_home}/anki"
    local venv="${anki_home}/.venv"

    log_info "Installing anki-sync-server..."
    mkdir -p "${anki_home}"
    chown -R "${service_user}:${service_user}" "${anki_home}"

    python3 -m venv "${venv}"
    chown -R "${service_user}:${service_user}" "${venv}"

    sudo -u "${service_user}" "${venv}/bin/pip" install anki-sync-server

    log_info "Creating Anki data directories..."
    mkdir -p "${anki_home}"/{collection.backups,data}
    chown -R "${service_user}:${service_user}" "${anki_home}"

    log_info "Creating Anki systemd service..."
    cat > /etc/systemd/system/anki.service << EOF
[Unit]
Description=Anki Sync Server
After=network.target

[Service]
Type=simple
User=${service_user}
Group=${service_user}
WorkingDirectory=${anki_home}
Environment="PATH=${venv}/bin"
Environment="ANKI_SYNC_SERVER_HOME=${anki_home}"
ExecStart=${venv}/bin/anki-sync-server
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable anki

    log_success "Anki sync server installed"
}

app_configure() {
    log_info "Anki sync server running on port 27701"
    log_info "Configure Anki desktop to sync with: http://minipc-ip:27701"
}
