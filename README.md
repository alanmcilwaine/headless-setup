# Headless MiniPC Setup

Headless Debian 12 setup for my minipc. It's a pretty bare starting point, with standard security and apps.

## Quick Start

```bash
scp -r /path/to/headless-setup/ alan@minipc-ip:/tmp/
ssh -p 2222 alan@minipc-ip
sudo /tmp/headless-setup/bootstrap.sh all
```

## After Install

```bash
ssh-copy-id -p 2222 alan@minipc-ip

# set the discord token here
sudo nvim /var/lib/openclaw/.openclaw/openclaw.json

sudo /opt/minipc/scripts/servicectl.sh start all
sudo ./scripts/03-verify.sh
```

## Services

```bash
# Manage services
sudo /opt/minipc/scripts/servicectl.sh start|stop|restart openclaw|anki|obsidian|all

# Check logs
sudo journalctl -u openclaw -f

# Snapshots
snapper list
```

## Openclaw Sudo

Openclaw can run specific commands without password:

- `apt update`, `apt upgrade`, `apt install`
- `systemctl start|stop|restart|status`
- Read vault files

Everything else needs password or is denied.

## Adding a New App

To allow Openclaw to manage a new app (e.g., calendar), edit `/etc/sudoers.d/openclaw` on the MiniPC:

```bash
sudo visudo
```

Add lines like:

```
openclaw ALL=(ALL) NOPASSWD: /usr/bin/systemctl start calendar
openclaw ALL=(ALL) NOPASSWD: /usr/bin/systemctl stop calendar
```

Run `sudo visudo -c` to validate before exiting.

## Adding Stuff

```bash
# System packages
sudo apt install <package>
# Snapper auto-snapshots on apt ops

# New service
# Add to scripts/02-services.sh or run manually
```