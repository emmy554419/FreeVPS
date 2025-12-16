#!/bin/bash
# SSH-only FreeVPS
# Required secrets:
# NGROK_AUTH_TOKEN
# LINUX_USER_PASSWORD
# Optional:
# LINUX_MACHINE_NAME

set -e

USER="runner"

echo "### Checking required secrets ###"

if [[ -z "$NGROK_AUTH_TOKEN" ]]; then
  echo "Please set 'NGROK_AUTH_TOKEN'"
  exit 2
fi

if [[ -z "$LINUX_USER_PASSWORD" ]]; then
  echo "Please set 'LINUX_USER_PASSWORD'"
  exit 3
fi

echo "### Set hostname (optional) ###"
if [[ -n "$LINUX_MACHINE_NAME" ]]; then
  sudo hostname "$LINUX_MACHINE_NAME"
fi

echo "### Set SSH password for runner ###"
echo -e "$LINUX_USER_PASSWORD\n$LINUX_USER_PASSWORD" | sudo passwd "$USER"

echo "### Install ngrok v3 ###"
wget -q https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip
unzip -o ngrok-v3-stable-linux-amd64.zip
chmod +x ngrok
sudo mv ngrok /usr/local/bin/ngrok

echo "### Configure ngrok ###"
ngrok config add-authtoken "$NGROK_AUTH_TOKEN"

echo "### Start ngrok TCP tunnel for SSH (port 22) ###"
rm -f ngrok.log

# Start ngrok in background
nohup ngrok tcp 22 --log=stdout > ngrok.log 2>&1 &

# Wait until ngrok writes the tunnel info
TRIES=0
MAX_TRIES=10
NGROK_SSH=""
while [[ -z "$NGROK_SSH" && $TRIES -lt $MAX_TRIES ]]; do
  sleep 2
  NGROK_SSH=$(grep -oE "tcp://[a-z0-9\.]+:[0-9]+" ngrok.log | head -n1)
  TRIES=$((TRIES+1))
done

if [[ -n "$NGROK_SSH" ]]; then
  echo ""
  echo "=========================================="
  echo "SSH CONNECTION COMMAND:"
  echo "$NGROK_SSH" | sed "s#tcp://#ssh $USER@#; s#:# -p #"
  echo "=========================================="
else
  echo "⚠️ Could not detect SSH link from ngrok after $((TRIES*2)) seconds"
  exit 4
fi
echo "### Keeping runner alive for SSH access (CTRL+C to stop) ###"
sleep infinity