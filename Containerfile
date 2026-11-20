# Global build arguments (override via podman build --build-arg ... --target final-<gpu_stack>)
ARG FEDORA_VERSION="45"
ARG EDITION="hyprland"
ARG GPU_STACK="main"
ARG BASE_IMAGE="ghcr.io/ublue-os/base-main:45"
ARG IMAGE_VERSION="0.1.0"
ARG GIT_SHA="dev"

# Build context stage (keeps build scripts and raw overlays out of final layer history)
FROM scratch AS ctx
COPY build_files /
COPY system_files /system_files

# Pre-compiled NVIDIA Open kernel modules & addons from Universal Blue akmods
FROM ghcr.io/ublue-os/akmods-nvidia-open:main-${FEDORA_VERSION} AS akmods-nvidia

# Common desktop, gaming, developer, and OS tuning stage
FROM ${BASE_IMAGE} AS stage-common

ARG FEDORA_VERSION="45"
ARG EDITION="hyprland"
ARG GPU_STACK="main"
ARG IMAGE_VERSION="0.1.0"
ARG GIT_SHA="dev"

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/cache/libdnf5 \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    EDITION="${EDITION}" \
    GPU_STACK="${GPU_STACK}" \
    FEDORA_VERSION="${FEDORA_VERSION}" \
    IMAGE_VERSION="${IMAGE_VERSION}" \
    GIT_SHA="${GIT_SHA}" \
    bash /ctx/build.sh common

# Edition target for AMD & Intel GPUs (Mesa + Vulkan multilib)
FROM stage-common AS final-main

ARG FEDORA_VERSION="45"
ARG EDITION="hyprland"
ARG IMAGE_VERSION="0.1.0"
ARG GIT_SHA="dev"

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/cache/libdnf5 \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    EDITION="${EDITION}" \
    GPU_STACK="main" \
    FEDORA_VERSION="${FEDORA_VERSION}" \
    IMAGE_VERSION="${IMAGE_VERSION}" \
    GIT_SHA="${GIT_SHA}" \
    bash /ctx/build.sh gpu-main && \
    EDITION="${EDITION}" \
    GPU_STACK="main" \
    FEDORA_VERSION="${FEDORA_VERSION}" \
    IMAGE_VERSION="${IMAGE_VERSION}" \
    GIT_SHA="${GIT_SHA}" \
    bash /ctx/build.sh finalize

LABEL containers.bootc="1" \
      org.opencontainers.image.title="ender-os-${EDITION}" \
      org.opencontainers.image.description="Ender-OS (${EDITION}, AMD/Intel Mesa) — Atomic Gaming & Developer Linux OS" \
      org.opencontainers.image.source="https://github.com/EnderkingTR/Ender-OS" \
      org.opencontainers.image.url="https://github.com/EnderkingTR/Ender-OS" \
      org.opencontainers.image.vendor="EnderkingTR" \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.version="${IMAGE_VERSION}"

RUN bootc container lint

# Edition target for NVIDIA GPUs (nvidia-open akmods + Wayland/CUDA multilib)
FROM stage-common AS final-nvidia-open

ARG FEDORA_VERSION="45"
ARG EDITION="hyprland"
ARG IMAGE_VERSION="0.1.0"
ARG GIT_SHA="dev"

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=bind,from=akmods-nvidia,src=/kernel-rpms,dst=/tmp/akmods-kernel-rpms \
    --mount=type=bind,from=akmods-nvidia,src=/rpms,dst=/tmp/akmods-nvidia \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/cache/libdnf5 \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    EDITION="${EDITION}" \
    GPU_STACK="nvidia-open" \
    FEDORA_VERSION="${FEDORA_VERSION}" \
    IMAGE_VERSION="${IMAGE_VERSION}" \
    GIT_SHA="${GIT_SHA}" \
    bash /ctx/build.sh gpu-nvidia && \
    EDITION="${EDITION}" \
    GPU_STACK="nvidia-open" \
    FEDORA_VERSION="${FEDORA_VERSION}" \
    IMAGE_VERSION="${IMAGE_VERSION}" \
    GIT_SHA="${GIT_SHA}" \
    bash /ctx/build.sh finalize

LABEL containers.bootc="1" \
      org.opencontainers.image.title="ender-os-${EDITION}-nvidia" \
      org.opencontainers.image.description="Ender-OS (${EDITION}, NVIDIA Open) — Atomic Gaming & Developer Linux OS" \
      org.opencontainers.image.source="https://github.com/EnderkingTR/Ender-OS" \
      org.opencontainers.image.url="https://github.com/EnderkingTR/Ender-OS" \
      org.opencontainers.image.vendor="EnderkingTR" \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.version="${IMAGE_VERSION}"

RUN bootc container lint

# Default final stage resolves from GPU_STACK
FROM final-${GPU_STACK} AS final
