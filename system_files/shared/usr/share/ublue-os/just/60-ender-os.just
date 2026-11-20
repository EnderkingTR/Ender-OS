# Ender-OS Universal Blue Justfile Recipes (`ujust ender-*`)

# Show Ender-OS system, GPU, profile, and theme summary
[group('Ender-OS')]
ender-status:
    @ender-ctl status

# Run Ender-OS gaming and developer health diagnostics
[group('Ender-OS')]
ender-doctor:
    @ender-ctl doctor

# Switch active performance profile (gaming, balanced, dev, powersave)
[group('Ender-OS')]
ender-profile profile="show":
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ "{{ profile }}" == "show" ]]; then
        ender-ctl profile show
    else
        ender-ctl profile set "{{ profile }}"
    fi

# Switch live Ender-OS visual theme (ender-obsidian, ender-nordic, ender-crimson)
[group('Ender-OS')]
ender-theme theme="list":
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ "{{ theme }}" == "list" ]]; then
        ender-ctl theme list
    else
        ender-ctl theme set "{{ theme }}"
    fi

# Install curated gaming, developer, or media Flatpaks from Flathub
[group('Ender-OS')]
ender-gaming group="gaming":
    @ender-ctl gaming setup --group "{{ group }}"

# Provision a curated Distrobox developer environment (rust, web, python, cpp, arch-lab)
[group('Ender-OS')]
ender-devbox stack="list":
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ "{{ stack }}" == "list" ]]; then
        ender-ctl devbox list
    else
        ender-ctl devbox create "{{ stack }}"
    fi

# Atomically update Ender-OS via bootc
[group('Ender-OS')]
ender-update:
    @ender-ctl update

# Switch between Ender-OS editions (hyprland, hyprland-nvidia, plasma, plasma-nvidia)
[group('Ender-OS')]
ender-switch edition:
    @ender-ctl switch "{{ edition }}"
