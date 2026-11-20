#!/usr/bin/env bash
set -euo pipefail

RELEASE="$(rpm -E %fedora)"
CURRENT_KERNEL="$(rpm -q --queryformat="%{evr}.%{arch}" kernel-core)"
TARGET_KERNEL="$(find /tmp/akmods-kernel-rpms -maxdepth 1 -name 'kernel-core-*.rpm' -printf '%f\n' | head -n1 | sed 's/^kernel-core-//;s/\.rpm$//')"

if [[ -n "${TARGET_KERNEL}" && "${CURRENT_KERNEL}" != "${TARGET_KERNEL}" ]]; then
    echo "Synchronizing kernel (${CURRENT_KERNEL} -> ${TARGET_KERNEL}) to match akmods-nvidia-open..."
    for pkg in kernel kernel-core kernel-modules kernel-modules-core kernel-modules-extra; do
        if rpm -q "${pkg}" >/dev/null 2>&1; then
            rpm --erase "${pkg}" --nodeps
        fi
    done

    INSTALL_D="/usr/lib/kernel/install.d"
    if [[ -d "${INSTALL_D}" ]]; then
        pushd "${INSTALL_D}" >/dev/null
        for hook in 05-rpmostree.install 50-dracut.install; do
            if [[ -f "${hook}" ]]; then
                mv "${hook}" "${hook}.bak"
                printf '#!/bin/sh\nexit 0\n' > "${hook}"
                chmod +x "${hook}"
            fi
        done
        popd >/dev/null
    fi

    dnf5 -y install \
        "/tmp/akmods-kernel-rpms/kernel-${TARGET_KERNEL}.rpm" \
        "/tmp/akmods-kernel-rpms/kernel-core-${TARGET_KERNEL}.rpm" \
        "/tmp/akmods-kernel-rpms/kernel-modules-${TARGET_KERNEL}.rpm" \
        "/tmp/akmods-kernel-rpms/kernel-modules-core-${TARGET_KERNEL}.rpm" \
        "/tmp/akmods-kernel-rpms/kernel-modules-extra-${TARGET_KERNEL}.rpm"

    if [[ -d "${INSTALL_D}" ]]; then
        pushd "${INSTALL_D}" >/dev/null
        for hook in 05-rpmostree.install 50-dracut.install; do
            if [[ -f "${hook}.bak" ]]; then
                mv -f "${hook}.bak" "${hook}"
            fi
        done
        popd >/dev/null
    fi

    dnf5 versionlock add kernel kernel-core kernel-modules kernel-modules-core kernel-modules-extra || true
fi

echo "Installing Wayland EGL integration for NVIDIA..."
dnf5 install -y \
    egl-wayland.x86_64 \
    egl-wayland.i686

dnf5 install -y --skip-unavailable \
    egl-wayland2.x86_64 \
    egl-wayland2.i686 || true

NVIDIA_INSTALLER=""
if [[ -f /tmp/akmods-nvidia/ublue-os/nvidia-install.sh ]]; then
    NVIDIA_INSTALLER="/tmp/akmods-nvidia/ublue-os/nvidia-install.sh"
elif [[ -f /tmp/akmods-nvidia/ublue-os/nvidia-install ]]; then
    NVIDIA_INSTALLER="/tmp/akmods-nvidia/ublue-os/nvidia-install"
else
    echo "Could not find Universal Blue nvidia-install script inside /tmp/akmods-nvidia/ublue-os/" >&2
    exit 1
fi

echo "Running Universal Blue NVIDIA Open installer (${NVIDIA_INSTALLER})..."
IMAGE_NAME="SKIP_PACKAGE_INSTALL" \
    AKMODNV_PATH="/tmp/akmods-nvidia" \
    MULTILIB=1 \
    FEDORA_MAJOR_VERSION="${RELEASE}" \
    bash "${NVIDIA_INSTALLER}"

# Prevent Nouveau Vulkan ICD conflicts and ensure libnvidia-ml symlink exists
rm -f /usr/share/vulkan/icd.d/nouveau_icd.*.json
if [[ ! -e /usr/lib64/libnvidia-ml.so && -e /usr/lib64/libnvidia-ml.so.1 ]]; then
    ln -s libnvidia-ml.so.1 /usr/lib64/libnvidia-ml.so
fi

# Clean up unnecessary peermem dracut warning and persist modeset config in /usr/lib
if [[ -f /usr/lib/dracut/dracut.conf.d/99-nvidia.conf ]]; then
    sed -i 's/ nvidia_peermem\b//' /usr/lib/dracut/dracut.conf.d/99-nvidia.conf
fi
if [[ -f /etc/modprobe.d/nvidia-modeset.conf ]]; then
    mkdir -p /usr/lib/modprobe.d
    cp -f /etc/modprobe.d/nvidia-modeset.conf /usr/lib/modprobe.d/nvidia-modeset.conf
fi

if systemctl list-unit-files nvidia-powerd.service >/dev/null 2>&1; then
    systemctl enable nvidia-powerd.service || true
fi
if systemctl list-unit-files nvidia-persistenced.service >/dev/null 2>&1; then
    systemctl disable nvidia-persistenced.service || true
fi

# Signal 99-finalize.sh to regenerate initramfs with NVIDIA + iGPU drivers baked in
touch /tmp/.ender-rebuild-initramfs
