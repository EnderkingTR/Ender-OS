set dotenv-filename := "ender-os.env"
set dotenv-load := true

export repo_organization := env_var("REPO_ORGANIZATION")
export image_prefix := env_var("IMAGE_PREFIX")
export fedora_version := env_var("FEDORA_VERSION")
export default_tag := env_var("DEFAULT_TAG")
export bib_image := env_var("BIB_IMAGE")
export image_desc := env_var("IMAGE_DESC")
export image_keywords := env_var("IMAGE_KEYWORDS")

[private]
default:
    @just --list

# Check Justfile syntax and formatting
[group('Validation')]
check:
    #!/usr/bin/env bash
    set -euo pipefail
    just --unstable --fmt --check -f Justfile

# Format Justfile
[group('Validation')]
fix:
    #!/usr/bin/env bash
    set -euo pipefail
    just --unstable --fmt -f Justfile

# Run repository validation, unit tests, and shellcheck
[group('Validation')]
lint:
    #!/usr/bin/env bash
    set -euo pipefail
    python3 tests/validate_repo.py
    python3 -m unittest discover -s tests -v
    if command -v shellcheck >/dev/null 2>&1; then
        shellcheck \
            build_files/build.sh \
            build_files/modules/*.sh \
            system_files/shared/usr/bin/ender-gamescope-session \
            system_files/nvidia/etc/profile.d/*.sh
    else
        echo "shellcheck not installed; skipping shellcheck."
    fi

# Clean temporary build and output files
[group('Utility')]
clean:
    #!/usr/bin/env bash
    set -euo pipefail
    rm -rf output/ _build* *_build* previous.manifest.json changelog.md output.env

# Resolve edition name into BASE_IMAGE, DE, GPU_STACK, TARGET, IMAGE_NAME
[private]
_resolve-edition edition:
    #!/usr/bin/env bash
    set -euo pipefail
    case "{{ edition }}" in
        hyprland)
            echo "ghcr.io/ublue-os/base-main:${fedora_version} hyprland main final-main ${image_prefix}-hyprland"
            ;;
        hyprland-nvidia)
            echo "ghcr.io/ublue-os/base-main:${fedora_version} hyprland nvidia-open final-nvidia-open ${image_prefix}-hyprland-nvidia"
            ;;
        plasma)
            echo "ghcr.io/ublue-os/kinoite-main:${fedora_version} plasma main final-main ${image_prefix}-plasma"
            ;;
        plasma-nvidia)
            echo "ghcr.io/ublue-os/kinoite-main:${fedora_version} plasma nvidia-open final-nvidia-open ${image_prefix}-plasma-nvidia"
            ;;
        *)
            echo "Unsupported edition: {{ edition }} (expected: hyprland, hyprland-nvidia, plasma, plasma-nvidia)" >&2
            exit 1
            ;;
    esac

# Build an Ender-OS OCI image using Podman
[group('Build Image')]
build edition="hyprland" tag=default_tag:
    #!/usr/bin/env bash
    set -euo pipefail
    read -r base_image de gpu_stack target image_name <<< "$(just _resolve-edition "{{ edition }}")"
    git_sha="dev"
    if git rev-parse --short HEAD >/dev/null 2>&1; then
        git_sha="$(git rev-parse --short HEAD)"
    fi
    image_version="${fedora_version}.$(date -u +%Y%m%d).${git_sha}"
    podman build \
        --pull=newer \
        --target "${target}" \
        --build-arg "FEDORA_VERSION=${fedora_version}" \
        --build-arg "EDITION=${de}" \
        --build-arg "GPU_STACK=${gpu_stack}" \
        --build-arg "BASE_IMAGE=${base_image}" \
        --build-arg "IMAGE_VERSION=${image_version}" \
        --build-arg "GIT_SHA=${git_sha}" \
        --label "io.artifacthub.package.keywords=${image_keywords}" \
        --label "org.opencontainers.image.created=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --label "org.opencontainers.image.description=${image_desc}" \
        --tag "localhost/${image_name}:{{ tag }}" \
        --file Containerfile \
        .

# Rechunk a locally built image with rpm-ostree for smaller OTA deltas
[group('Build Image')]
ostree-rechunk edition="hyprland" tag=default_tag:
    #!/usr/bin/env bash
    set -euo pipefail
    read -r _base_image _de _gpu_stack _target image_name <<< "$(just _resolve-edition "{{ edition }}")"
    local_ref="localhost/${image_name}:{{ tag }}"
    graphroot="$(podman info --format '{{ '{{.Store.GraphRoot}}' }}')"
    podman run --rm --pull=never --privileged \
        --mount="type=image,src=${local_ref},target=/rpm-ostree" \
        --mount="type=bind,src=${graphroot},target=/run/host-container-storage,rw" \
        --mount="type=tmpfs,target=/run/rpm-ostree-storage" \
        --entrypoint /usr/bin/rpm-ostree \
        "${local_ref}" \
        compose build-chunked-oci \
        --max-layers 127 \
        --format-version=2 \
        --bootc \
        --rootfs /rpm-ostree \
        --output "containers-storage:[overlay@/run/host-container-storage+/run/rpm-ostree-storage]${local_ref}"

# Generate standard OCI release tags
[group('Utility')]
generate-tags tag=default_tag:
    #!/usr/bin/env bash
    set -euo pipefail
    date_tag="$(date -u +%Y%m%d)"
    tags=("{{ tag }}" "${fedora_version}" "${fedora_version}-${date_tag}")
    if git rev-parse --short HEAD >/dev/null 2>&1; then
        git_sha="$(git rev-parse --short HEAD)"
        tags+=("sha-${git_sha}" "${fedora_version}-${date_tag}-${git_sha}")
    fi
    echo "${tags[*]}"

# Build bootable artifact via bootc-image-builder (iso or qcow2)
[private]
_build-bib edition tag type config:
    #!/usr/bin/env bash
    set -euo pipefail
    read -r _base_image _de _gpu_stack _target image_name <<< "$(just _resolve-edition "{{ edition }}")"
    local_ref="localhost/${image_name}:{{ tag }}"
    mkdir -p output
    if ! sudo podman image exists "${local_ref}"; then
        uid_ref="${UID}@localhost::${local_ref}"
        tmp_scp="$(mktemp -d -p "${PWD}" _build_scp.XXXXXX)"
        trap 'rm -rf "${tmp_scp}"' EXIT
        sudo TMPDIR="${tmp_scp}" podman image scp "${uid_ref}" "root@localhost::${local_ref}"
    fi
    sudo podman run \
        --rm \
        --privileged \
        --pull=newer \
        --security-opt label=type:unconfined_t \
        -v "${PWD}/{{ config }}:/config.toml:ro" \
        -v "${PWD}/output:/output" \
        -v /var/lib/containers/storage:/var/lib/containers/storage \
        "${bib_image}" \
        --type "{{ type }}" \
        --use-librepo=True \
        --rootfs=btrfs \
        --config /config.toml \
        "${local_ref}"

# Build an installable Anaconda ISO for an Ender-OS edition
[group('Build Disk')]
build-iso edition="hyprland" tag=default_tag: (_build-bib edition tag "anaconda-iso" "disk_config/iso-" + edition + ".toml")

# Build a QCOW2 VM disk image for an Ender-OS edition
[group('Build Disk')]
build-qcow2 edition="hyprland" tag=default_tag: (_build-bib edition tag "qcow2" "disk_config/disk.toml")
