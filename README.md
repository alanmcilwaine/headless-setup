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

# set the discord token here (environment file, not JSON)
sudo mkdir -p /var/lib/openclaw/.openclaw
sudo chmod 700 /var/lib/openclaw/.openclaw
sudo tee /var/lib/openclaw/.openclaw/openclaw.env << 'EOF'
OPENCLAW_DISCORD_TOKEN=your_token_here
EOF
sudo chmod 600 /var/lib/openclaw/.openclaw/openclaw.env
sudo chown openclaw:openclaw /var/lib/openclaw/.openclaw/openclaw.env

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

- `apt *` - Full package management (install, remove, update, upgrade, etc.)
- `systemctl *` - Full systemd control (start, stop, restart, enable, etc.)
- **File operations:** `mkdir`, `rm`, `mv`, `cp`, `touch`, `cat`, `ls`, `find`, `grep`, `head`, `tail`, `sed`, `awk`, `tee`, `chmod`, `chown`, `ln`, etc.
- **Text processing:** `cut`, `sort`, `uniq`, `wc`, `tr`, `xargs`
- **Git:** Full git operations (clone, commit, push, pull, etc.)
- **Python:** `python3`, `pip3`, `pip` - Run scripts and install packages
- **Node.js:** `node`, `npm`, `npx` - Run Node apps and install packages
- **Docker:** `docker`, `docker-compose` - Container management
- **Network:** `curl`, `wget`, `ping`, `netstat`, `ss`, `dig`, `nslookup`, `host`, `whois`
- **Process management:** `kill`, `pkill`, `killall`, `ps`, `top`, `htop`, `pgrep`, `pidof`, `nohup`, `screen`, `tmux`
- **Editors:** `nano`, `vim`, `vi`
- **Archives:** `tar`, `gzip`, `gunzip`, `unzip`, `zip`, `bzip2`, `xz`, `7z`
- **System info:** `df`, `du`, `free`, `uptime`, `uname`, `hostname`, `date`
- **Shell utilities:** `env`, `echo`, `printf`, `test`, `sleep`, `timeout`, `time`
- Read vault files

This gives openclaw full flexibility to manage the system, files, and run any development tools through Discord.

## Security Note

Openclaw has broad sudo privileges for convenience. The service runs as a dedicated user and has access to:
- Install/update packages
- Manage all systemd services
- Read vault files

SSH access is key-only on port 2222 with fail2ban protection.

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
