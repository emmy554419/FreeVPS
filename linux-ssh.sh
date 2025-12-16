#!/bin/bash
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
ngrok tcp 22 --log=stdout > ngrok.log &

sleep 8

echo ""
echo "=========================================="
echo "SSH CONNECTION COMMAND:"
grep -oE "tcp://[a-z0-9\.]+:[0-9]+" ngrok.log | \
sed "s#tcp://#ssh runner@#; s#:# -p #"
echo "=========================================="