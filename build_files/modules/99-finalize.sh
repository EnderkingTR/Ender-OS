#!/usr/bin/env bash
set -euo pipefail

if [[ -f /tmp/.ender-rebuild-initramfs ]]; then
    KERNEL_VERSION="$(rpm -q --queryformat="%{evr}.%{arch}" kernel-core)"
    echo "Regenerating initramfs for kernel ${KERNEL_VERSION}..."
    export DRACUT_NO_XATTR=1
    /usr/bin/dracut \
        --no-hostonly \
        --kver "${KERNEL_VERSION}" \
        --reproducible \
        -v \
        --add ostree \
        -f "/lib/modules/${KERNEL_VERSION}/initramfs.img"
    chmod 0600 "/lib/modules/${KERNEL_VERSION}/initramfs.img"
    rm -f /tmp/.ender-rebuild-initramfs
fi

# Guarantee no COPR or temporary third-party repos remain enabled in final image
for repo_file in /etc/yum.repos.d/_copr*.repo /etc/yum.repos.d/rpmfusion-nonfree-steam.repo; do
    if [[ -f "${repo_file}" ]]; then
        sed -i 's@enabled=1@enabled=0@g' "${repo_file}"
    fi
done

# Validate native Ender-OS CLI tooling
chmod 0755 /usr/bin/ender-ctl /usr/bin/ender-gamescope-session
python3 -m py_compile /usr/bin/ender-ctl

dnf5 clean all
find /var/tmp -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
