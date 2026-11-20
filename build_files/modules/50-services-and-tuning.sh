#!/usr/bin/env bash
set -euo pipefail

echo "Enabling core Ender-OS system services..."
for unit in \
    podman.socket \
    firewalld.service \
    fstrim.timer \
    power-profiles-daemon.service \
    systemd-oomd.service; do
    if systemctl list-unit-files "${unit}" >/dev/null 2>&1; then
        systemctl enable "${unit}"
    fi
done

mkdir -p /etc/skel/.config/ender-os
printf 'balanced\n' > /etc/skel/.config/ender-os/profile.conf
printf 'ender-obsidian\n' > /etc/skel/.config/ender-os/theme.conf
