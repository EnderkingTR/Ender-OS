#!/usr/bin/env bash
set -euo pipefail

EDITION="${EDITION:-hyprland}"
GPU_STACK="${GPU_STACK:-main}"
FEDORA_VERSION="${FEDORA_VERSION:-45}"
IMAGE_VERSION="${IMAGE_VERSION:-0.1.0}"
GIT_SHA="${GIT_SHA:-dev}"

case "${EDITION}" in
    hyprland)
        DE_PRETTY="Hyprland"
        ;;
    plasma)
        DE_PRETTY="KDE Plasma 6"
        ;;
    *)
        echo "Unsupported EDITION: ${EDITION}" >&2
        exit 1
        ;;
esac

if [[ "${GPU_STACK}" == "nvidia-open" ]]; then
    FULL_IMAGE_NAME="ender-os-${EDITION}-nvidia"
    GPU_PRETTY="NVIDIA Open"
    VARIANT_ID="${EDITION}-nvidia"
else
    FULL_IMAGE_NAME="ender-os-${EDITION}"
    GPU_PRETTY="AMD / Intel Mesa"
    VARIANT_ID="${EDITION}"
fi

EDITION_PRETTY="${DE_PRETTY} • ${GPU_PRETTY}"
BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
IMAGE_REF="ghcr.io/enderkingtr/${FULL_IMAGE_NAME}:latest"

# Update /usr/lib/os-release cleanly for Ender-OS identity while keeping Fedora compatibility
OS_RELEASE="/usr/lib/os-release"
if [[ -f "${OS_RELEASE}" ]]; then
    sed -i \
        -e '/^NAME=/d' \
        -e '/^PRETTY_NAME=/d' \
        -e '/^ID=/d' \
        -e '/^ID_LIKE=/d' \
        -e '/^VARIANT=/d' \
        -e '/^VARIANT_ID=/d' \
        -e '/^HOME_URL=/d' \
        -e '/^DOCUMENTATION_URL=/d' \
        -e '/^SUPPORT_URL=/d' \
        -e '/^BUG_REPORT_URL=/d' \
        -e '/^OSTREE_VERSION=/d' \
        "${OS_RELEASE}"
fi

cat >> "${OS_RELEASE}" <<EOF
NAME="Ender-OS"
PRETTY_NAME="Ender-OS ${FEDORA_VERSION} (${EDITION_PRETTY})"
ID="ender-os"
ID_LIKE="fedora"
VARIANT="${EDITION_PRETTY}"
VARIANT_ID="${VARIANT_ID}"
OSTREE_VERSION="${IMAGE_VERSION}"
HOME_URL="https://github.com/EnderkingTR/Ender-OS"
DOCUMENTATION_URL="https://github.com/EnderkingTR/Ender-OS/blob/main/docs/ARCHITECTURE.md"
SUPPORT_URL="https://github.com/EnderkingTR/Ender-OS/issues"
BUG_REPORT_URL="https://github.com/EnderkingTR/Ender-OS/issues"
EOF

mkdir -p /usr/share/ender-os
cat > /usr/share/ender-os/image-info.json <<EOF
{
  "name": "Ender-OS",
  "image_name": "${FULL_IMAGE_NAME}",
  "edition": "${EDITION}",
  "gpu_stack": "${GPU_STACK}",
  "variant_id": "${VARIANT_ID}",
  "variant_pretty": "${EDITION_PRETTY}",
  "fedora_version": "${FEDORA_VERSION}",
  "version": "${IMAGE_VERSION}",
  "git_sha": "${GIT_SHA}",
  "build_date": "${BUILD_DATE}",
  "image_ref": "${IMAGE_REF}"
}
EOF
