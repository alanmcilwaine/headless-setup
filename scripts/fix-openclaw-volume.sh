#!/bin/bash
set -euo pipefail

echo "Fixing OpenClaw Docker volume issue..."

# Check if the volume exists
if ! docker volume inspect openclaw-home >/dev/null 2>&1; then
    echo "Creating openclaw-home volume..."
    docker volume create openclaw-home
fi

# The volume should be automatically mounted by docker-compose.extra.yml
# Let's verify the setup
cd /opt/openclaw-source

echo ""
echo "Current compose configuration:"
docker compose config | grep -A 20 "volumes:"

echo ""
echo "Checking if openclaw-home volume exists:"
docker volume inspect openclaw-home || echo "Volume does not exist!"

echo ""
echo "To fix the issue, you need to ensure the volume is properly mounted."
echo "The docker-compose.extra.yml should include:"
echo "  - openclaw-home:/home/node"
echo ""
echo "Let's check the extra compose file:"
cat docker-compose.extra.yml
