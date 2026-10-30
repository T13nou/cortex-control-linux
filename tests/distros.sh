#!/usr/bin/env bash
# Runs install.sh in throwaway containers to check the package step on several distributions.
# Usage: tests/distros.sh [image…]   (needs podman; nothing is installed on the host)
# Without USB device nor desktop, the run is expected to stop later, at the udev rule: only the
# package step and the Wine version are checked.
set -euo pipefail

cd "$(dirname "$0")/.."
IMAGES=("$@")
(( ${#IMAGES[@]} )) || IMAGES=(archlinux:latest fedora:latest ubuntu:latest debian:stable)
LOGS="${TMPDIR:-/tmp}/cortex-control-distros"
mkdir -p "$LOGS"

for image in "${IMAGES[@]}"; do
    case "$image" in
        archlinux*)       setup='pacman -Syu --noconfirm sudo' ;;
        fedora*)          setup='dnf install -y sudo' ;;
        ubuntu*|debian*)  setup='apt-get update && apt-get install -y sudo ca-certificates' ;;
        *) echo "unknown image family: $image"; continue ;;
    esac
    log="$LOGS/${image//[:\/]/_}.log"
    printf '%-20s ' "$image"
    podman run --rm -v "$PWD/install.sh:/install.sh:ro,Z" "$image" bash -c "
        set -e
        { $setup; } >/dev/null 2>&1
        useradd -m tester
        echo 'tester ALL=(ALL) NOPASSWD:ALL' >/etc/sudoers.d/tester
        sudo -u tester -H bash -c 'cd && CORTEX_YES=1 bash /install.sh' || true
        echo '--- installed:'
        for c in wine winetricks 7z magick curl; do printf '%s=%s\n' \$c \"\$(command -v \$c || echo missing)\"; done
        wine --version 2>/dev/null || true
    " 2>&1 | sed 's/\x1b\[[0-9;]*m//g' >"$log" || true
    if grep -q '^==> Scripts' "$log"; then
        printf 'packages OK  %s\n' "$(grep -m1 -oE 'wine-[0-9][^ ]*' "$log" | tail -1)"
    else
        printf 'FAILED       see %s\n' "$log"
    fi
done
