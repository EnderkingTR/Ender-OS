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

# Ensure /usr/bin/dnf symlink exists and expose Fedora 45 /usr/share/dnf5/repos.d files in /etc/yum.repos.d for bootc-image-builder
if [[ ! -e /usr/bin/dnf && -x /usr/bin/dnf5 ]]; then
    ln -s dnf5 /usr/bin/dnf
fi

mkdir -p /etc/yum.repos.d
for repo_name in fedora.repo fedora-updates.repo; do
    if [[ ! -f "/etc/yum.repos.d/${repo_name}" && -f "/usr/share/dnf5/repos.d/${repo_name}" ]]; then
        cp -f "/usr/share/dnf5/repos.d/${repo_name}" "/etc/yum.repos.d/${repo_name}"
    fi
done

# Disable COPR, third-party, multimedia, and archive repos in final image so only official Fedora repos remain active
for repo_file in \
    /etc/yum.repos.d/_copr*.repo \
    /etc/yum.repos.d/rpmfusion*.repo \
    /etc/yum.repos.d/*multimedia*.repo \
    /etc/yum.repos.d/*negativo17*.repo \
    /etc/yum.repos.d/fedora-cisco-openh264.repo \
    /etc/yum.repos.d/fedora-updates-archive.repo \
    /usr/share/dnf5/repos.d/_copr*.repo \
    /usr/share/dnf5/repos.d/rpmfusion*.repo \
    /usr/share/dnf5/repos.d/*multimedia*.repo \
    /usr/share/dnf5/repos.d/*negativo17*.repo \
    /usr/share/dnf5/repos.d/fedora-cisco-openh264.repo \
    /usr/share/dnf5/repos.d/fedora-updates-archive.repo; do
    if [[ -f "${repo_file}" ]]; then
        sed -i 's@enabled=1@enabled=0@g' "${repo_file}"
    fi
done

for official_repo in /etc/yum.repos.d/fedora.repo /etc/yum.repos.d/fedora-updates.repo; do
    if [[ -f "${official_repo}" ]] && ! grep -q '^enabled=1' "${official_repo}"; then
        sed -i '0,/enabled=0/{s/enabled=0/enabled=1/}' "${official_repo}"
    fi
done

# Dereference GPG key symlinks in /etc/pki/rpm-gpg and /usr/share/pki/rpm-gpg so external rootdir solvers never follow absolute links onto the host
for gpg_key in /etc/pki/rpm-gpg/* /usr/share/pki/rpm-gpg/*; do
    if [[ -L "${gpg_key}" && -e "${gpg_key}" ]]; then
        cp -f --remove-destination "$(readlink -f "${gpg_key}")" "${gpg_key}"
    fi
done

# Validate native Ender-OS CLI tooling
chmod 0755 /usr/bin/ender-ctl /usr/bin/ender-gamescope-session
python3 -m py_compile /usr/bin/ender-ctl

dnf5 clean all
find /var/tmp -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
