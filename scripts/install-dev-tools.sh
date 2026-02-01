#!/bin/bash
set -euo pipefail

echo "=== Installing Development Tools on Debian 12 ==="
echo ""

echo "Updating package index..."
apt-get update

echo "Installing core development packages..."
apt-get install -y \
    zsh \
    git \
    curl \
    wget \
    build-essential \
    cmake \
    pkg-config \
    neovim \
    tmux \
    fzf \
    ripgrep \
    fd-find \
    bat \
    jq \
    zoxide \
    nodejs \
    npm \
    golang-go \
    python3 \
    python3-pip \
    python3-venv

echo "Installing uv (Python package manager)..."
curl -LsSf https://astral.sh/uv/install.sh | sh

echo "Installing Rust via rustup..."
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

echo "Installing cargo packages..."
# Source cargo env for current session
source "$HOME/.cargo/env" || true
cargo install cargo-binstall
cargo binstall -y starship atuin eza

echo "Installing Go tools..."
go install golang.org/x/tools/gopls@latest
go install github.com/go-delve/delve/cmd/dlv@latest

echo ""
echo "=== Installation Complete! ==="
echo "Development tools have been installed successfully."
echo "You may need to restart your shell or run 'source ~/.bashrc' to use some tools."
