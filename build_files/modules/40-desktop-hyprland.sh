#!/usr/bin/env bash
set -euo pipefail

echo "Applying Hyprland desktop configuration overlay..."
cp -avf /ctx/system_files/hyprland/. /

echo "Installing Hyprland compositor stack from lionheartp/Hyprland COPR..."
dnf5 -y copr enable lionheartp/Hyprland
dnf5 -y install \
    hyprland \
    hyprlock \
    hypridle \
    hyprpaper \
    xdg-desktop-portal-hyprland

if ! dnf5 -y install hyprpolkitagent; then
    dnf5 -y install --skip-unavailable polkit-gnome || dnf5 -y install --skip-unavailable lxqt-policykit || true
fi
dnf5 -y copr disable lionheartp/Hyprland

echo "Installing Wayland bar, launcher, notifications, and desktop utilities..."
dnf5 -y install \
    waybar \
    rofi \
    kitty \
    thunar \
    thunar-archive-plugin \
    gvfs \
    gvfs-mtp \
    grim \
    slurp \
    wl-clipboard \
    brightnessctl \
    playerctl \
    pavucontrol \
    network-manager-applet \
    blueman \
    xdg-desktop-portal-gtk \
    qt5-qtwayland \
    qt6-qtwayland \
    sddm \
    sddm-wayland-generic \
    adw-gtk3-theme

if ! dnf5 -y install SwayNotificationCenter; then
    if dnf5 -y copr enable erikreider/SwayNotificationCenter && dnf5 -y install SwayNotificationCenter; then
        dnf5 -y copr disable erikreider/SwayNotificationCenter || true
    else
        dnf5 -y copr disable erikreider/SwayNotificationCenter || true
        echo "SwayNotificationCenter unavailable; falling back to mako..."
        dnf5 -y install --skip-unavailable mako || true
    fi
fi

dnf5 -y install --skip-unavailable papirus-icon-theme || true

mkdir -p /usr/lib/sddm/sddm.conf.d
cat > /usr/lib/sddm/sddm.conf.d/10-ender-wayland.conf <<'EOF'
[General]
DisplayServer=wayland
GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell

[Wayland]
CompositorCommand=weston --shell=kiosk-shell.so
EOF

# Seed default active theme symlink inside /etc/skel for new users
mkdir -p /etc/skel/.config/ender-os
ln -sfn /usr/share/ender-os/themes/ender-obsidian /etc/skel/.config/ender-os/current-theme

systemctl enable sddm.service
systemctl set-default graphical.target
