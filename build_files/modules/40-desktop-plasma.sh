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

if systemctl list-unit-files plasmalogin.service >/dev/null 2>&1; then
    systemctl enable plasmalogin.service
elif systemctl list-unit-files sddm.service >/dev/null 2>&1; then
    systemctl enable sddm.service
fi
systemctl set-default graphical.target
