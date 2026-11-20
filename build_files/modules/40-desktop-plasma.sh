#!/usr/bin/env bash
set -euo pipefail

echo "Applying KDE Plasma 6 gaming configuration overlay..."
cp -avf /ctx/system_files/plasma/. /

echo "Installing Plasma developer and QoL companion packages..."
dnf5 -y install --skip-unavailable \
    konsole \
    kate \
    kde-gtk-config \
    kio-extras \
    papirus-icon-theme

mkdir -p /etc/skel/.config/ender-os
ln -sfn /usr/share/ender-os/themes/ender-obsidian /etc/skel/.config/ender-os/current-theme

systemctl enable sddm.service
systemctl set-default graphical.target
