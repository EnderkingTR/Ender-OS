#!/usr/bin/env bash
set -euo pipefail

echo "Installing AMD & Intel Mesa/Vulkan 64-bit and 32-bit drivers..."
dnf5 install -y \
    vulkan-loader \
    vulkan-loader.i686 \
    vulkan-tools \
    mesa-vulkan-drivers \
    mesa-vulkan-drivers.i686 \
    mesa-dri-drivers \
    mesa-dri-drivers.i686 \
    mesa-filesystem.i686 \
    mesa-libEGL.i686 \
    mesa-libGL.i686 \
    mesa-libgbm.i686 \
    mesa-va-drivers.i686 \
    libva-utils \
    libva-intel-media-driver
