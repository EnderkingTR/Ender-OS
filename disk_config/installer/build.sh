#!/usr/bin/env bash
set -euxo pipefail

LIVE_BASE_IMAGE="${LIVE_BASE_IMAGE:?LIVE_BASE_IMAGE is required}"
INSTALL_IMAGE_PAYLOAD="${INSTALL_IMAGE_PAYLOAD:?INSTALL_IMAGE_PAYLOAD is required}"
TARGET_EDITION="${TARGET_EDITION:?TARGET_EDITION is required}"

echo "Building Ender-OS Live Installer layer (base=${LIVE_BASE_IMAGE}, payload=${INSTALL_IMAGE_PAYLOAD}, edition=${TARGET_EDITION})..."

# Ensure /root target directory exists (in bootc images /root -> /var/roothome)
mkdir -p "$(realpath /root)"
mount -o remount,rw /proc/sys || true

# Install Live ISO runtime, Anaconda WebUI installer, storage backends, EFI boot binaries, and fuse-overlayfs
dnf5 install -y --allowerasing \
    dracut-live \
    livesys-scripts \
    anaconda-live \
    libblockdev-btrfs \
    libblockdev-lvm \
    libblockdev-dm \
    firefox \
    gparted \
    grub2-efi-x64-cdboot \
    grub2-efi-x64 \
    shim-x64 \
    fuse-overlayfs

# Pull the target Ender-OS OCI image directly into the live image's container storage for offline installation
mkdir -p /var/lib/containers/storage
if ! podman pull --storage-opt additionalimagestore='' "${INSTALL_IMAGE_PAYLOAD}"; then
    echo "Default podman pull failed inside container build; retrying with fuse-overlayfs..."
    podman --storage-driver=overlay \
        --storage-opt overlay.mount_program=/usr/bin/fuse-overlayfs \
        --storage-opt additionalimagestore='' \
        pull "${INSTALL_IMAGE_PAYLOAD}"
fi
podman image exists "${INSTALL_IMAGE_PAYLOAD}"
podman images

# Rebuild initramfs with live squashfs + overlay support for the installed Fedora kernel
KERNEL_VERSION="$(rpm -q --queryformat="%{evr}.%{arch}" kernel-core)"
echo "Generating live initramfs for kernel ${KERNEL_VERSION}..."
DRACUT_NO_XATTR=1 dracut -v --force --reproducible --no-hostonly \
    --add "dmsquash-live dmsquash-live-autooverlay" \
    "/usr/lib/modules/${KERNEL_VERSION}/initramfs.img" "${KERNEL_VERSION}"

# Configure Fedora livesys for KDE Plasma 6 live desktop (autologin + Install to Hard Drive icon)
mkdir -p /etc/sysconfig
if [[ -f /etc/sysconfig/livesys ]]; then
    if grep -q '^livesys_session=' /etc/sysconfig/livesys; then
        sed -i 's/^livesys_session=.*/livesys_session=kde/' /etc/sysconfig/livesys
    else
        echo 'livesys_session=kde' >> /etc/sysconfig/livesys
    fi
else
    printf 'livesys_session=kde\n' > /etc/sysconfig/livesys
fi
systemctl enable livesys.service livesys-late.service

# Disable KWallet prompts in live session
mkdir -p /etc/skel/.config
cat > /etc/skel/.config/kwalletrc <<'EOF'
[Wallet]
Enabled=false
EOF

# Stage EFI bootloader binaries where Titanoboa expects them (/boot/efi/EFI)
mkdir -p /boot/efi
if [[ -d /usr/lib/efi ]]; then
    cp -av /usr/lib/efi/*/*/EFI /boot/efi/
fi
mkdir -p /boot/efi/EFI/BOOT
if [[ -f /boot/efi/EFI/fedora/grubx64.efi ]]; then
    cp -fv /boot/efi/EFI/fedora/grubx64.efi /boot/efi/EFI/BOOT/grubx64.efi
    cp -fv /boot/efi/EFI/fedora/grubx64.efi /boot/efi/EFI/BOOT/fbx64.efi
fi
if [[ -f /boot/efi/EFI/fedora/shimx64.efi && ! -f /boot/efi/EFI/BOOT/BOOTX64.EFI ]]; then
    cp -fv /boot/efi/EFI/fedora/shimx64.efi /boot/efi/EFI/BOOT/BOOTX64.EFI
fi
test -f /boot/efi/EFI/BOOT/BOOTX64.EFI
test -f /boot/efi/EFI/BOOT/grubx64.efi

# Prepare Anaconda WebUI state and interactive kickstart deploying the embedded Ender-OS container image
mkdir -p /var/lib/rpm-state /usr/share/anaconda
cat >> /usr/share/anaconda/interactive-defaults.ks <<EOF

%pre-install
rm -rf /mnt/sysroot/boot/efi/EFI/fedora || true
%end

ostreecontainer --url=${INSTALL_IMAGE_PAYLOAD} --transport=containers-storage --no-signature-verification

%post --log=/tmp/ender-bootc-switch.log
bootc switch --mutate-in-place --transport registry ${INSTALL_IMAGE_PAYLOAD} || true
%end

%post --log=/tmp/ender-restorecon.log
setenforce 0 || true
restorecon -R /etc/selinux || true
%end
EOF

# Set default UTC timezone for live environment
rm -f /etc/localtime
systemd-firstboot --timezone UTC || true

# Provide larger tmpfs on /var/tmp in live session so ostree/anaconda extraction never runs out of /run space
rm -rf /var/tmp
mkdir -p /var/tmp
cat > /etc/systemd/system/var-tmp.mount <<'EOF'
[Unit]
Description=Larger tmpfs for /var/tmp on live system

[Mount]
What=tmpfs
Where=/var/tmp
Type=tmpfs
Options=size=50%%,nr_inodes=1m

[Install]
WantedBy=local-fs.target
EOF
systemctl enable var-tmp.mount

# Ensure /mnt is a real directory (not a symlink) so systemd-tmpfiles/Anaconda can label the install target
rm -rf /mnt
mkdir -p /mnt

# Disable background timers/services that should not run during a live ISO session
for unit in \
    rpm-ostree-countme.service \
    rpm-ostreed-automatic.timer \
    flatpak-add-fedora-repos.service \
    fstrim.timer \
    bootloader-update.service; do
    if systemctl list-unit-files "${unit}" >/dev/null 2>&1; then
        systemctl disable "${unit}" || true
    fi
done

# Provide Titanoboa ISO config
mkdir -p /usr/lib/bootc-image-builder
cp -fv /src/iso.yaml /usr/lib/bootc-image-builder/iso.yaml

# Clean DNF caches to minimize squashfs ISO size
dnf5 clean all
