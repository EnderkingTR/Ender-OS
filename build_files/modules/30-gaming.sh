#!/usr/bin/env bash
set -euo pipefail

echo "Installing core gaming runtime, overlays, and audio compatibility stack..."
dnf5 install -y \
    gamescope \
    gamemode \
    gamemode.i686 \
    mangohud \
    mangohud.i686 \
    vulkan-loader \
    vulkan-loader.i686 \
    vulkan-tools \
    lutris \
    wine-core \
    winetricks \
    sdl2-compat \
    sdl2-compat.i686 \
    pipewire-alsa \
    pipewire-alsa.i686 \
    pipewire-pulseaudio \
    wireplumber \
    libcap

echo "Installing Steam from rpmfusion-nonfree-steam (enabled strictly for build step)..."
dnf5 install -y fedora-workstation-repositories || true
if [[ -f /etc/yum.repos.d/rpmfusion-nonfree-steam.repo ]]; then
    dnf5 config-manager setopt rpmfusion-nonfree-steam.enabled=1
    if ! dnf5 -y --setopt=install_weak_deps=False install steam; then
        dnf5 config-manager setopt rpmfusion-nonfree-steam.enabled=0 || true
        exit 1
    fi
    dnf5 config-manager setopt rpmfusion-nonfree-steam.enabled=0
else
    echo "WARNING: rpmfusion-nonfree-steam.repo not found; Steam can be installed via Flathub fallback." >&2
fi

echo "Installing optional sched_ext (scx-scheds) gaming CPU schedulers..."
if dnf5 -y copr enable bieszczaders/kernel-cachyos-addons && dnf5 -y install scx-scheds; then
    dnf5 -y copr disable bieszczaders/kernel-cachyos-addons || true
else
    dnf5 -y copr disable bieszczaders/kernel-cachyos-addons || true
    echo "WARNING: scx-scheds unavailable in COPR for current Fedora release; continuing without scx-scheds." >&2
fi

if [[ -x /usr/bin/gamescope ]]; then
    setcap cap_sys_nice=eip /usr/bin/gamescope || true
fi
