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

## Security

- **Docker container**: OpenClaw is isolated. If compromised, attackers can see your data but can't escape to the host or access other devices.
- **Fail2ban**: Blocks brute force SSH attempts after 3 failures (1 hour ban).
- **SSH on port 6969**: :)

## Managing openclaw

```bash
sudo systemctl start|stop|restart openclaw
sudo journalctl -u openclaw -f
```

## Uninstall 

```bash
sudo ./scripts/uninstall.sh
```
