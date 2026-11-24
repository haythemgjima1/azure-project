#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run this script on vm-web with sudo." >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y xfce4 xfce4-goodies xrdp
printf 'startxfce4\n' > /home/azureuser/.xsession
chown azureuser:azureuser /home/azureuser/.xsession
usermod -aG ssl-cert xrdp
systemctl enable --now xrdp
echo "XFCE and xrdp are installed. Keep port 3389 private; connect through an SSH tunnel."
