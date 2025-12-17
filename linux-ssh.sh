#!/bin/bash
# SSH-only FreeVPS (Hardened for GitHub Actions)
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

echo "### Ensure SSH service is running ###"
sudo systemctl enable ssh
sudo systemctl restart ssh

echo "### Install ngrok v3 ###"
wget -q https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip
unzip -o ngrok-v3-stable-linux-amd64.zip
chmod +x ngrok
sudo mv ngrok /usr/local/bin/ngrok

echo "### Configure ngrok ###"
ngrok config add-authtoken "$NGROK_AUTH_TOKEN"

echo "### Start ngrok TCP tunnel for SSH (port 22) ###"
rm -f ngrok.log

# Start ngrok in background with fixed region (IMPORTANT)
nohup ngrok tcp 22 --region=eu --log=stdout > ngrok.log 2>&1 &

TRIES=0
MAX_TRIES=20
NGROK_HOST=""
NGROK_PORT=""

while [[ -z "$NGROK_HOST" && $TRIES -lt $MAX_TRIES ]]; do
  sleep 5

  LINE=$(grep -oE "tcp://[a-z0-9\.]+:[0-9]+" ngrok.log | head -n1)

  if [[ -n "$LINE" ]]; then
    HOST=$(echo "$LINE" | sed 's#tcp://##' | cut -d: -f1)
    PORT=$(echo "$LINE" | cut -d: -f2)

    # Confirm DNS is actually resolvable before accepting it
    if getent hosts "$HOST" > /dev/null; then
      NGROK_HOST="$HOST"
      NGROK_PORT="$PORT"
    fi
  fi

  TRIES=$((TRIES+1))
done

if [[ -n "$NGROK_HOST" ]]; then
  echo ""
  echo "=========================================="
  echo "SSH CONNECTION COMMAND:"
  echo "ssh $USER@$NGROK_HOST -p $NGROK_PORT"
  echo "=========================================="
else
  echo "❌ ngrok tunnel started but DNS never propagated"
  echo "Check ngrok.log for details"
  exit 4
fi

echo "### Keeping runner alive for SSH access ###"
sleep infinity