#!/bin/bash
# Free Ubuntu SSH with Cloudflare Tunnel (public trycloudflare.com hostname)
# Required secrets:
# LINUX_USER_PASSWORD
# Optional:
# LINUX_MACHINE_NAME

set -e

USER="runner"

echo "### Set hostname (optional) ###"
if [[ -n "$LINUX_MACHINE_NAME" ]]; then
  sudo hostname "$LINUX_MACHINE_NAME"
fi

echo "### Set SSH password for runner ###"
echo -e "$LINUX_USER_PASSWORD\n$LINUX_USER_PASSWORD" | sudo passwd "$USER"

echo "### Ensure SSH service is running ###"
sudo apt-get update -y
sudo apt-get install -y openssh-server
sudo systemctl enable ssh
sudo systemctl restart ssh

echo "### Install cloudflared ###"
wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
chmod +x cloudflared-linux-amd64
sudo mv cloudflared-linux-amd64 /usr/local/bin/cloudflared

echo "### Start Cloudflare Tunnel for SSH (public trycloudflare.com) ###"
# Start tunnel in background
nohup cloudflared tunnel --url ssh://localhost:22 > cloudflared.log 2>&1 &

# Wait until tunnel prints a valid hostname
TRIES=0
MAX_TRIES=15
PUBLIC_HOST=""

while [[ -z "$PUBLIC_HOST" && $TRIES -lt $MAX_TRIES ]]; do
    sleep 3
    # Extract only trycloudflare.com hostnames
    PUBLIC_HOST=$(grep -oE '([a-z0-9\-]+\.trycloudflare\.com)' cloudflared.log | head -n1)
    TRIES=$((TRIES+1))
done

if [[ -z "$PUBLIC_HOST" ]]; then
    echo "❌ Could not detect Cloudflare public hostname"
    exit 1
fi

echo ""
echo "=========================================="
echo "🎯 SSH CONNECTION INFO (FREE & PUBLIC)"
echo "Host: $PUBLIC_HOST"
echo "User: $USER"
echo "Password: $LINUX_USER_PASSWORD"
echo ""
echo "Connect using:"
echo "ssh -o ProxyCommand='cloudflared access ssh --hostname %h' $USER@$PUBLIC_HOST"
echo "=========================================="

echo "### Keeping runner alive for SSH access ###"
sleep infinity