#!/bin/bash
set -euo pipefail
# Layer 2.5: DevTools - Development environment
# Runs BEFORE runtime (layer 3)

log() { echo "[DEVTOOLS] $*"; }

install_dnf_packages() {
    log "Installing DNF packages..."
    
    rpm-ostree install -A \
        zsh zsh-autosuggestions zsh-syntax-highlighting \
        bat direnv fastfetch fzf jq ripgrep tmux xz yq zoxide duf \
        gcc gcc-c++ make cmake \
        libicu libsixel lua luajit \
        npm uv go zig \
        openssl-devel pkg-config postgresql-devel sqlite-devel sqlite \
        git stow \
        --idempotent --allow-inactive
}

install_copr_packages() {
    log "Installing COPR packages..."
    
    # Enable COPR repos and install packages
    if command -v copr &>/dev/null; then
        # Enable lazygit COPR
        rpm-ostree install -A \
            https://copr.fedorainfracloud.org/coprs/atim/lazygit/repo/fedora/atim-lazygit-fedora-$(rpm -E %fedora).repo \
            --idempotent --allow-inactive 2>/dev/null || true
        
        dnf copr enable -y atim/lazygit 2>/dev/null || true
        rpm-ostree install -A lazygit --idempotent --allow-inactive
    fi
}

install_rust() {
    log "Installing Rust toolchain..."
    
    if ! command -v rustc &>/dev/null; then
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain nightly
        source "$HOME/.cargo/env" 2>/dev/null || true
    fi
    
    rustup target add wasm32-unknown-unknown 2>/dev/null || true
    rustup component add rust-analyzer clippy rustfmt 2>/dev/null || true
}

install_cargo_binstall() {
    if ! command -v cargo-binstall &>/dev/null; then
        log "Installing cargo-binstall..."
        curl -L --proto '=https' --tlsv1.2 -sSf \
            https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh | bash
    fi
}

install_cargo_packages() {
    log "Installing Cargo packages..."
    
    install_rust
    install_cargo_binstall
    
    local packages=(
        atuin eza starship
        sccache cargo-watch cargo-make
        cargo-audit cargo-outdated cargo-udeps
        cargo-edit cargo-information
        trunk wasm-bindgen-cli
        sqlx-cli
    )
    
    for pkg in "${packages[@]}"; do
        if ! command -v "$pkg" &>/dev/null && ! cargo install --list | grep -q "^$pkg "; then
            log "Installing: $pkg"
            cargo binstall -y "$pkg" 2>/dev/null || cargo install "$pkg" 2>/dev/null || true
        fi
    done
}

install_go_packages() {
    log "Installing Go packages..."
    
    if ! command -v go &>/dev/null; then
        return
    fi
    
    export GOPATH="${GOPATH:-$HOME/go}"
    export PATH="$GOPATH/bin:$PATH"
    
    local packages=(
        "github.com/joshmedeski/sesh/v2@v2.13.0"
        "golang.org/x/tools/gopls@latest"
        "github.com/go-delve/delve/cmd/dlv@latest"
        "golang.org/x/tools/cmd/goimports@latest"
        "github.com/golangci/golangci-lint/cmd/golangci-lint@latest"
    )
    
    for pkg in "${packages[@]}"; do
        binary_name=$(echo "$pkg" | sed 's/@.*//' | rev | cut -d'/' -f1 | rev)
        if ! command -v "$binary_name" &>/dev/null; then
            go install "$pkg" 2>/dev/null || true
        fi
    done
}

install_npm_packages() {
    log "Installing NPM packages..."
    
    if ! command -v npm &>/dev/null; then
        return
    fi
    
    npm config set prefix "$HOME/.local" 2>/dev/null || true
    
    local packages=("@anthropic-ai/claude-code" "opencode-ai")
    
    for pkg in "${packages[@]}"; do
        if ! npm list -g "$pkg" &>/dev/null; then
            npm install -g --force "$pkg" 2>/dev/null || true
        fi
    done
}

main() {
    log "Installing development tools..."
    
    install_dnf_packages
    install_copr_packages
    install_rust
    install_cargo_packages
    install_go_packages
    install_npm_packages
    
    log ""
    log "DevTools complete."
    log "IMPORTANT: Run 'rpm-ostree apply-live' or reboot to apply changes"
}

main
