# OpenClaw on MiniPC

Docker setup for running OpenClaw on my Intel N150 MiniPC (16GB RAM, 512GB storage).

## Quick Start

```bash
# Copy to MiniPC and run
sudo ./setup.sh

# Add Discord bot token
cd /opt/openclaw-source
docker compose run --rm openclaw-cli providers add --provider discord --token YOUR_TOKEN
```

## What This Does

- Installs Docker and fail2ban
- Clones OpenClaw from GitHub
- Builds OpenClaw Docker image locally
- Creates directories:
  - `/home/openclaw/data/obsidian-vault`
  - `/home/openclaw/data/anki-data`
  - `/home/openclaw/data/workspace`
  - `/home/openclaw/data/calendar`
- Runs OpenClaw via Docker Compose
- SSH on port 6969 with brute-force protection

## Security

- **Docker isolation**: OpenClaw runs in container, can't escape to host
- **Loopback binding**: Gateway only accessible from localhost
- **Fail2ban**: Blocks brute force SSH attempts
- **SSH on port 6969**: Non-standard port

## Managing OpenClaw

```bash
cd /opt/openclaw-source

# View status
docker compose ps

# View logs
docker compose logs -f openclaw-gateway

# Restart
docker compose restart openclaw-gateway

# Stop
docker compose down

# Start
docker compose up -d
```

## Dev Tools (Optional)

```bash
sudo ./scripts/install-dev-tools.sh
```

Installs: zsh, git, neovim, tmux, fzf, ripgrep, fd, bat, Rust, Go, Node.js, uv

## Uninstall

```bash
sudo ./scripts/uninstall.sh
```
