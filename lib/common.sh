#!/usr/bin/env bash
# Common library functions

# Set default STATE_DIR if not already set
STATE_DIR="${STATE_DIR:-/var/lib/minipc-state}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[OK]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }

require_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

command_exists() {
    command -v "$1" &>/dev/null
}

user_exists() {
    id "$1" &>/dev/null
}

is_installed() {
    [[ -f "${STATE_DIR}/.${1}-installed" ]]
}

mark_installed() {
    touch "${STATE_DIR}/.${1}-installed"
}

ensure_state_dir() {
    mkdir -p "${STATE_DIR}"
}

load_config() {
    if [[ -f "${SCRIPT_DIR}/config/config.env" ]]; then
        source "${SCRIPT_DIR}/config/config.env"
    fi
    if [[ -f "${SCRIPT_DIR}/config/secrets.env" ]]; then
        source "${SCRIPT_DIR}/config/secrets.env" 2>/dev/null || true
    fi
}

is_debian12() {
    if [[ ! -f /etc/os-release ]]; then
        return 1
    fi
    source /etc/os-release
    [[ "$VERSION_ID" == "12" ]]
}

require_debian12() {
    if [[ ! -f /etc/os-release ]]; then
        log_error "Not a Debian system"
        exit 1
    fi
    source /etc/os-release
    if [[ "$VERSION_ID" != "12" ]]; then
        log_error "This setup requires Debian 12, found: $VERSION_ID"
        exit 1
    fi
}

service_is_active() {
    systemctl is-active --quiet "$1" 2>/dev/null
}

service_is_enabled() {
    systemctl is-enabled --quiet "$1" 2>/dev/null
}
