#!/bin/bash
# =======================================================
#  BossHub Uninstaller
#  - Safely stops services, removes binaries, and cleans up configs
# =======================================================

echo -e "\033[1;31m"
echo " BossHub Offline Uninstaller "
echo "  ___                                   "
echo " | _ \___ _ __  _____ _____             "
echo " |   / -_) '  \/ _ \ V / -_)            "
echo " |_|_\___|_|_|_\___/\_/\___|            "
echo "                                        "
echo " - bosshub.io - "
echo -e "\033[0m"

if [ "$EUID" -ne 0 ]; then 
    echo "Error: Please run as root"
    exit
fi

CURRENT_USER=${SUDO_USER:-$(whoami)}
if [ "$CURRENT_USER" = "root" ]; then
    HOME_DIR="/root"
else
    HOME_DIR="/home/$CURRENT_USER"
fi

echo "[1/5] Stopping and disabling BossHub services..."
sudo systemctl stop ttyd novnc frpc bosshub-heartbeat 2>/dev/null
sudo systemctl disable ttyd novnc frpc bosshub-heartbeat 2>/dev/null

echo "[2/5] Killing related orphaned processes..."
killall -9 ttyd frpc websockify 2>/dev/null

echo "[3/5] Removing Systemd service files..."
sudo rm -f /etc/systemd/system/ttyd.service
sudo rm -f /etc/systemd/system/novnc.service
sudo rm -f /etc/systemd/system/frpc.service
sudo rm -f /etc/systemd/system/bosshub-heartbeat.service

echo "[4/5] Removing binaries, directories, and configurations..."
# Binaries & Scripts
sudo rm -f /usr/local/bin/ttyd
sudo rm -f /usr/local/bin/frpc
sudo rm -f /usr/local/bin/bosshub-heartbeat.py

# Directories
sudo rm -rf /usr/share/novnc
sudo rm -rf /etc/frp

# WayVNC Configs
sudo rm -f /etc/wayvnc/config
sudo rm -f "$HOME_DIR/.config/wayvnc/config"
# Clean up empty wayvnc dir if nothing else is inside
sudo rmdir "$HOME_DIR/.config/wayvnc" 2>/dev/null 

echo "[5/5] Uninstalling specific packages..."
export DEBIAN_FRONTEND=noninteractive

# Clean up pip package
echo "  -> Removing pip websockify..."
pip3 uninstall -y websockify --break-system-packages 2>/dev/null

# Clean up apt packages
echo "  -> Removing apt packages (websockify, novnc)..."
apt-get purge -y websockify python3-websockify novnc 2>/dev/null
# apt-get autoremove -y 2>/dev/null

echo "Reloading systemd daemon..."
sudo systemctl daemon-reload

echo -e "\033[1;32m"
echo "========================================"
echo " Uninstall Complete!"
echo " BossHub components have been successfully removed."
echo "========================================"
echo -e "\033[0m"
