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
if [[ -f /etc/yum.repos.d/rpmfusion-nonfree-steam.repo || -f /usr/share/dnf5/repos.d/rpmfusion-nonfree-steam.repo ]] || dnf5 repolist --all 2>/dev/null | grep -qw 'rpmfusion-nonfree-steam'; then
    dnf5 -y --enablerepo=rpmfusion-nonfree-steam --setopt=install_weak_deps=False install steam
else
    RELEASE="$(rpm -E %fedora)"
    dnf5 -y install "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${RELEASE}.noarch.rpm"
    dnf5 -y --setopt=install_weak_deps=False install steam
    dnf5 config-manager setopt "rpmfusion-nonfree*.enabled=0" || true
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
