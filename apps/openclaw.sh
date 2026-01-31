#!/usr/bin/env bash
# Openclaw - Discord claw machine bot

app_info() {
    echo "Openclaw Discord bot for claw machine control"
    echo "Repository: https://github.com/openclaw/openclaw"
}

app_dependencies() {
    echo "python3 python3-venv python3-pip git"
}

app_ports() {
    echo ""
}

app_install() {
    local service_user="${MINIPC_SERVICE_USER:-openclaw}"
    local service_home="/var/lib/${service_user}"
    local venv="${service_home}/.venv"

    log_info "Creating Python virtual environment..."
    python3 -m venv "${venv}"
    chown -R "${service_user}:${service_user}" "${venv}"

    log_info "Installing Openclaw..."
    sudo -u "${service_user}" "${venv}/bin/pip" install --upgrade pip
    sudo -u "${service_user}" "${venv}/bin/pip" install openclaw

    log_info "Creating Openclaw data directory..."
    mkdir -p "${service_home}"/{.openclaw,vault,logs}
    chown -R "${service_user}:${service_user}" "${service_home}"

    log_info "Creating Openclaw systemd service..."
    cat > /etc/systemd/system/openclaw.service << EOF
[Unit]
Description=Openclaw Discord Claw Machine Bot
After=network.target

[Service]
Type=simple
User=${service_user}
Group=${service_user}
WorkingDirectory=${service_home}
Environment="HOME=${service_home}"
ExecStart=${venv}/bin/python -m openclaw
Restart=always
RestartSec=10
StandardOutput=append:/var/log/openclaw/openclaw.log
StandardError=append:/var/log/openclaw/openclaw.log

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable openclaw

    log_success "Openclaw installed"
}

app_configure() {
    local service_user="${MINIPC_SERVICE_USER:-openclaw}"
    local config_file="${service_home}/.openclaw/openclaw.json"

    if [[ ! -f "${config_file}" ]]; then
        log_warn "Openclaw config not found at ${config_file}"
        log_info "Create it with your Discord token, then run:"
        log_info "  sudo systemctl start openclaw"
    fi
}
