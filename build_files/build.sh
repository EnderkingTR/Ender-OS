#!/usr/bin/env bash
set -euo pipefail

PHASE="${1:-}"

if [[ -z "${PHASE}" ]]; then
    echo "Usage: $0 <common|gpu-main|gpu-nvidia|finalize>" >&2
    exit 1
fi

export EDITION="${EDITION:-hyprland}"
export GPU_STACK="${GPU_STACK:-main}"
export FEDORA_VERSION="${FEDORA_VERSION:-45}"
export IMAGE_VERSION="${IMAGE_VERSION:-0.1.0}"
export GIT_SHA="${GIT_SHA:-dev}"

log() {
    printf '\n[ender-os:%s] %s\n' "${PHASE}" "$*"
}

case "${PHASE}" in
    common)
        log "Copying shared system files overlay..."
        cp -avf /ctx/system_files/shared/. /
        chmod 0755 /usr/bin/ender-ctl /usr/bin/ender-gamescope-session

        log "Running common build modules for edition=${EDITION}..."
        bash /ctx/modules/00-branding.sh
        bash /ctx/modules/10-core-and-dev.sh
        bash /ctx/modules/30-gaming.sh
        bash "/ctx/modules/40-desktop-${EDITION}.sh"
        bash /ctx/modules/50-services-and-tuning.sh
        ;;
    gpu-main)
        log "Installing AMD/Intel Mesa + Vulkan GPU stack..."
        bash /ctx/modules/20-gpu-main.sh
        ;;
    gpu-nvidia)
        log "Copying NVIDIA overlay and installing akmods-nvidia-open stack..."
        cp -avf /ctx/system_files/nvidia/. /
        chmod 0644 /etc/profile.d/99-ender-nvidia-wayland.sh
        bash /ctx/modules/20-gpu-nvidia.sh
        ;;
    finalize)
        log "Refreshing branding for GPU_STACK=${GPU_STACK} and running finalization..."
        bash /ctx/modules/00-branding.sh
        bash /ctx/modules/99-finalize.sh
        ;;
    *)
        echo "Unknown build phase: ${PHASE}" >&2
        exit 1
        ;;
esac
