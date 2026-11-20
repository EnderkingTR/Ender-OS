# shellcheck shell=sh
# Ender-OS NVIDIA Open Wayland & Video Acceleration Environment
if [ -n "${WAYLAND_DISPLAY:-}" ] || [ "${XDG_SESSION_TYPE:-}" = "wayland" ]; then
    export LIBVA_DRIVER_NAME="${LIBVA_DRIVER_NAME:-nvidia}"
    export NVD_BACKEND="${NVD_BACKEND:-direct}"
    export __GLX_VENDOR_LIBRARY_NAME="${__GLX_VENDOR_LIBRARY_NAME:-nvidia}"
    export GBM_BACKEND="${GBM_BACKEND:-nvidia-drm}"
    export WLR_NO_HARDWARE_CURSORS="${WLR_NO_HARDWARE_CURSORS:-1}"
    export MOZ_ENABLE_WAYLAND="${MOZ_ENABLE_WAYLAND:-1}"
    export ELECTRON_OZONE_PLATFORM_HINT="${ELECTRON_OZONE_PLATFORM_HINT:-auto}"
fi
