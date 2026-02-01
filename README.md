# OpenClaw on MiniPC

Docker setup for running OpenClaw on my Intel N150 MiniPC (16GB RAM, 512GB storage).

## Quick Start

```bash
# Copy to MiniPC through ssh and run this command
sudo ./setup.sh

# Add the discord token
sudo cp .env.example /opt/openclaw/.env
sudo vi /opt/openclaw/.env

# Start it
sudo systemctl start openclaw
```

## What This Does

- Installs Docker
- Creates directories for my data:
  - `/home/openclaw/data/obsidian-vault`
  - `/home/openclaw/data/anki-data`
  - `/home/openclaw/data/workspace`
  - `/home/openclaw/data/calendar`
- Runs OpenClaw in a container with 4 CPU cores and 8GB RAM
- Auto-starts on boot

## Security:

OpenClaw runs in a Docker container. If someone compromises it, they can access the data but can't escape to the host or access other devices at home. In this case, all they'll really see are the obsidian notes and calendar stuff.

## Managing openclaw

```bash
sudo systemctl start|stop|restart openclaw
sudo journalctl -u openclaw -f
```

## Uninstall 

```bash
sudo ./scripts/uninstall.sh
```
