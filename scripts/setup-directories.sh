#!/bin/bash
set -euo pipefail

BASE_DIR="/home/openclaw/data"
SERVICE_USER="openclaw"
SERVICE_GROUP="openclaw"

echo "Setting up OpenClaw directory structure..."

# Create service user if it doesn't exist
if ! id "$SERVICE_USER" &>/dev/null; then
    echo "Creating service user: $SERVICE_USER"
    useradd -r -s /bin/false -d /home/openclaw "$SERVICE_USER"
    echo "User $SERVICE_USER created successfully"
else
    echo "User $SERVICE_USER already exists"
fi

# Create base directory
echo "Creating base directory: $BASE_DIR"
mkdir -p "$BASE_DIR"

# Create subdirectories
echo "Creating subdirectories..."
mkdir -p "$BASE_DIR/obsidian-vault"
mkdir -p "$BASE_DIR/anki-data"
mkdir -p "$BASE_DIR/workspace"
mkdir -p "$BASE_DIR/calendar"

# Create config directory
echo "Creating config directory: /home/openclaw/.openclaw"
mkdir -p /home/openclaw/.openclaw

# Set ownership
echo "Setting ownership..."
chown -R "$SERVICE_USER:$SERVICE_GROUP" /home/openclaw

# Set permissions
echo "Setting permissions..."
chmod 755 "$BASE_DIR"
chmod 755 "$BASE_DIR/obsidian-vault"
chmod 755 "$BASE_DIR/anki-data"
chmod 755 "$BASE_DIR/workspace"
chmod 755 "$BASE_DIR/calendar"
chmod 700 /home/openclaw/.openclaw

echo ""
echo "========================================"
echo "Directory structure setup complete!"
echo "========================================"
echo ""
echo "Created directories:"
echo "  - $BASE_DIR"
echo "  - $BASE_DIR/obsidian-vault"
echo "  - $BASE_DIR/anki-data"
echo "  - $BASE_DIR/workspace"
echo "  - $BASE_DIR/calendar"
echo "  - /home/openclaw/.openclaw"
echo ""
echo "Ownership: $SERVICE_USER:$SERVICE_GROUP"
echo "Permissions: 755 (data dirs), 700 (.openclaw)"
echo ""
echo "Next steps:"
echo "  1. Place your Obsidian vault in: $BASE_DIR/obsidian-vault"
echo "  2. Place your Anki data in: $BASE_DIR/anki-data"
echo "  3. Configure OpenClaw in: /home/openclaw/.openclaw"
echo "  4. Run the Docker container as user: $SERVICE_USER"
echo ""
