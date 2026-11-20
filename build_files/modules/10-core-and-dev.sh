#!/usr/bin/env bash
set -euo pipefail

echo "Installing core CLI, container, and developer utilities..."
dnf5 install -y \
    git \
    git-lfs \
    gh \
    podman \
    podman-compose \
    podman-docker \
    distrobox \
    tmux \
    neovim \
    zsh \
    fish \
    ripgrep \
    fd-find \
    bat \
    fzf \
    jq \
    just \
    btop \
    htop \
    fastfetch \
    direnv \
    curl \
    wget2 \
    unzip \
    p7zip \
    rsync \
    openssh-clients \
    NetworkManager-tui \
    firewalld \
    python3 \
    python3-pip

if ! rpm -q tuned-ppd power-profiles-daemon >/dev/null 2>&1; then
    dnf5 install -y tuned tuned-ppd
fi

echo "Installing developer & UI fonts..."
dnf5 install -y --skip-unavailable \
    jetbrains-mono-fonts-all \
    google-noto-color-emoji-fonts \
    rsms-inter-fonts

echo "Installing Starship prompt..."
if dnf5 -y copr enable atim/starship && dnf5 -y install starship; then
    dnf5 -y copr disable atim/starship || true
else
    dnf5 -y copr disable atim/starship || true
    echo "COPR atim/starship unavailable for current Fedora release; installing official Starship binary..."
    curl -fsSL https://starship.rs/install.sh -o /tmp/starship-install.sh
    sh /tmp/starship-install.sh -y -b /usr/bin
    rm -f /tmp/starship-install.sh
fi

# Register Ender-OS ujust recipes into Universal Blue's global justfile if present
UBLUE_JUSTFILE="/usr/share/ublue-os/justfile"
ENDER_JUST_IMPORT='import "/usr/share/ublue-os/just/60-ender-os.just"'
if [[ -f "${UBLUE_JUSTFILE}" ]]; then
    if ! grep -Fq "${ENDER_JUST_IMPORT}" "${UBLUE_JUSTFILE}"; then
        printf '\n%s\n' "${ENDER_JUST_IMPORT}" >> "${UBLUE_JUSTFILE}"
    fi
fi
