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
EnvironmentFile=/var/lib/${service_user}/.openclaw/openclaw.env
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
    local service_home="/var/lib/${service_user}"
    local env_file="${service_home}/.openclaw/openclaw.env"

    if [[ ! -f "${env_file}" ]]; then
        log_warn "Openclaw environment file not found at ${env_file}"
        log_info "Create it with your Discord token:"
        log_info "  sudo mkdir -p ${service_home}/.openclaw"
        log_info "  sudo chmod 700 ${service_home}/.openclaw"
        log_info "  sudo tee ${env_file} << 'EOF'"
        log_info 'OPENCLAW_DISCORD_TOKEN=your_token_here'
        log_info 'EOF'
        log_info "  sudo chmod 600 ${env_file}"
        log_info "  sudo chown ${service_user}:${service_user} ${env_file}"
        log_info "Then run: sudo systemctl start openclaw"
    else
        log_info "Openclaw environment file exists at ${env_file}"
        log_info "Ensure it contains: OPENCLAW_DISCORD_TOKEN=your_token"
    fi
}
