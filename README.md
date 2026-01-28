# Headless Personal Service Setup

I have a mini-pc I want to load with tools like obsidian, minecraft, anki, moltbot etc... This will automate a lot of the distro setup that I'm not really interested in doing myself.

## Layers

```
There are five layers to this installation.

Base (stuff like the os, users and docker)

Hardening (stuff like the firewall, ssh config)

Tooling (go, rust, npm etc...)

Runtime (this is where moltbot will live, as well as anki, obsidian etc...)

Recovery (snapshots and backups in case something gets messed up)
```

## 1.

```bash
scp -r /path/to/headless-setup/ fedora@minipc-ip:/tmp/
ssh -p 22 fedora@minipc-ip
sudo /tmp/headless-setup/bootstrap.sh all
```

## 2. config
```bash
sudo rpm-ostree apply-live

# Add SSH key (from macbook)
ssh-copy-id -p 2222 alan@minipc-ip

# Configure Moltbot, and afterwards setup discord token
ssh -p 2222 alan@minipc-ip
sudo nano /var/lib/moltbot/.moltbot/moltbot.json

sudo systemctl start moltbot
sudo ./layers/verify.sh
```

## Commands to remember

```bash
# Snapshots
sudo /opt/minipc/scripts/snapshot.sh "Pre-update"
snapper list
sudo /opt/minipc/scripts/restore.sh <number>

# Backup
sudo /opt/minipc/scripts/backup.sh

# Service
sudo systemctl start|stop|restart moltbot
sudo journalctl -u moltbot -f

# Apply silverblue changes
sudo rpm-ostree apply-live

# Verify
sudo ./layers/verify.sh
```

## Architecture

```
This wasn't really covered in layers, as that was installation layers.

Macbook -> Tailscale -> MiniPC -> Firewall -> Docker Network (minipc-network) -> Moltbot Gateway (port 18789?)
```

**Applying changes:**
All layers use `rpm-ostree install -A` which stages changes. Apply with:
```bash
sudo rpm-ostree apply-live
```
**Checking deployments:**
```bash
rpm-ostree status  # See current deployment
rpm-ostree rollback  # Go back to previous deployment
```
**Adding more packages later:**
```bash
# System packages (persists across reboots)
sudo rpm-ostree install <package-name>
sudo rpm-ostree apply-live

# User-space tools (npm, go, cargo)
npm install -g <tool>
go install <package>
cargo install <tool>
```

## Package management guide

On Silverblue, there are different ways to install things:

| Method | Command | Persists? | Use For |
|--------|---------|-----------|---------|
| rpm-ostree | `rpm-ostree install <pkg>` | Yes | System packages (gcc, docker, etc.) |
| dnf | `dnf install <pkg>` | No | Temporary testing only |
| Docker | `docker run <image>` | Yes | Services (Minecraft, databases) |
| User-space | `npm install -g` | Yes | Dev tools (claude-code, etc.) |

## Adding Services (Minecraft, Obsidian, etc.)

For services use docker, it's cleaner and doesn't pollute the system:

```bash
# Minecraft server
docker run -d \
  --name minecraft \
  -p 25565:25565 \
  -v /opt/minecraft:/data \
  -e EULA=TRUE \
  itzg/minecraft-server

# Obsidian (headless, for sync)
docker run -d \
  --name obsidian \
  -v /opt/obsidian:/vault \
  obsidian/obsidian:latest
```

Services go in `docker-compose.yml` in the runtime layer.
