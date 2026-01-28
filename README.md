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
sudo rpm-ostree install <package-name>
sudo rpm-ostree apply-live
```
