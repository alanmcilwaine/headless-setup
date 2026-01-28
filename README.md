# Headless MiniPC Setup

Headless Debian 12 setup for MoltBot, Anki, Obsidian.

## Quick Start

```bash
scp -r /path/to/headless-setup/ alan@minipc-ip:/tmp/
ssh -p 2222 alan@minipc-ip
sudo /tmp/headless-setup/bootstrap.sh all
```

## After Install

```bash
# Add SSH key from laptop
ssh-copy-id -p 2222 alan@minipc-ip

# Set MoltBot Discord token
sudo nano /var/lib/moltbot/.moltbot/moltbot.json

# Start everything
sudo /opt/minipc/scripts/servicectl.sh start all

# Verify
sudo ./scripts/03-verify.sh
```

## Scripts (scripts/)

| Script | What it does |
|--------|--------------|
| `01-system.sh` | OS, users, SSH port 2222, UFW, fail2ban, Snapper |
| `02-services.sh` | MoltBot (venv + systemd), Anki (venv), Obsidian (AppImage + Firejail) |
| `03-verify.sh` | Check everything is running |

## Services

```bash
# Manage services
sudo /opt/minipc/scripts/servicectl.sh start|stop|restart moltbot|anki|obsidian|all

# Check logs
sudo journalctl -u moltbot -f

# Snapshots
snapper list
```

## Structure

```
/opt/minipc/
├── scripts/       # servicectl.sh, snapshot scripts
├── config/        # app configs
└── data/
    ├── anki/
    └── obsidian/

/var/lib/minipc-state/   # state tracking
/var/lib/moltbot/        # MoltBot home
/var/log/moltbot/        # MoltBot logs
```

## MoltBot Sudo

MoltBot can run specific commands without password:

- `apt update`, `apt upgrade`, `apt install`
- `systemctl start|stop|restart|status`
- Read vault files

Everything else needs password or is denied.

## Adding Stuff

```bash
# System packages
sudo apt install <package>
# Snapper auto-snapshots on apt ops

# New service
# Add to scripts/02-services.sh or run manually
```

## Repository Structure

```
headless-setup/
├── bootstrap.sh          # Main entrypoint
├── README.md             # This file
└── scripts/
    ├── 01-system.sh      # OS + security
    ├── 02-services.sh    # Apps
    └── 03-verify.sh      # Checks
```
