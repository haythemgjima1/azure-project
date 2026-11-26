#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run this script on vm-web with sudo." >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y xfce4 xfce4-goodies xrdp dbus-x11 epiphany-browser
printf 'startxfce4\n' > /home/azureuser/.xsession
chown azureuser:azureuser /home/azureuser/.xsession
usermod -aG ssl-cert xrdp
install -d -o azureuser -g azureuser /home/azureuser/Desktop
cat <<'EOF' > /home/azureuser/Desktop/university-app.desktop
[Desktop Entry]
Type=Application
Name=University Assignment Manager
Exec=epiphany http://localhost
Icon=web-browser
Terminal=false
EOF
chmod +x /home/azureuser/Desktop/university-app.desktop
chown azureuser:azureuser /home/azureuser/Desktop/university-app.desktop
systemctl enable --now xrdp
echo "XFCE, epiphany-browser, and xrdp are installed. Keep port 3389 private; connect through an SSH tunnel."
