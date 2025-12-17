#!/bin/bash
# SSH-only FreeVPS using Cloudflare Tunnel (STABLE)
# Required secrets:
# CLOUDFLARE_TOKEN
# LINUX_USER_PASSWORD
# Optional:
# LINUX_MACHINE_NAME

set -e

USER="runner"

echo "### Checking required secrets ###"

if [[ -z "$CLOUDFLARE_TOKEN" ]]; then
  echo "❌ Please set 'CLOUDFLARE_TOKEN'"
  exit 2
fi

if [[ -z "$LINUX_USER_PASSWORD" ]]; then
  echo "❌ Please set 'LINUX_USER_PASSWORD'"
  exit 3
fi

echo "### Set hostname (optional) ###"
if [[ -n "$LINUX_MACHINE_NAME" ]]; then
  sudo hostname "$LINUX_MACHINE_NAME"
fi

echo "### Set SSH password for runner ###"
echo -e "$LINUX_USER_PASSWORD\n$LINUX_USER_PASSWORD" | sudo passwd "$USER"

echo "### Ensure SSH service is running ###"
sudo systemctl enable ssh
sudo systemctl restart ssh

echo "### Install cloudflared ###"
wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
chmod +x cloudflared-linux-amd64
sudo mv cloudflared-linux-amd64 /usr/local/bin/cloudflared

echo "### Start Cloudflare Tunnel for SSH (port 22) ###"

nohup cloudflared tunnel run --token "$CLOUDFLARE_TOKEN" > cloudflared.log 2>&1 &

echo ""
echo "=========================================="
echo "SSH CONNECTION INFO:"
echo "Use Cloudflare Access (Zero Trust) to connect"
echo "=========================================="

echo "### Keeping runner alive for SSH access ###"
sleep infinity