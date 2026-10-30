#!/usr/bin/env bash
# One-line installer for Cortex Control on Linux:
#   curl -fsSL https://raw.githubusercontent.com/T13nou/cortex-control-linux/main/install.sh | bash
# With an installer you already have:
#   curl -fsSL …/install.sh | bash -s -- ~/Downloads/'Cortex Control v4.1.0.exe'
# CORTEX_YES=1 answers yes to every question (sudo may still ask for your password).
# CORTEX_SOURCE=<dir> installs the scripts from a local copy instead of GitHub (tests).
set -euo pipefail

REPO=T13nou/cortex-control-linux
BRANCH="${CORTEX_BRANCH:-main}"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
APP_DIR="$DATA/cortex-control-linux"
BIN_DIR="$HOME/.local/bin"
PREFIX="${CORTEX_PREFIX:-$DATA/wineprefixes/cortex-control}"
RULE=/etc/udev/rules.d/70-quad-cortex.rules
MIN_WINE=11

step() { printf '\n\e[1;36m==> %s\e[0m\n' "$*"; }
ok()   { printf '  \e[32mOK\e[0m  %s\n' "$*"; }
warn() { printf '  \e[33m!!\e[0m  %s\n' "$*"; }
die()  { printf '\e[31mError:\e[0m %s\n' "$*" >&2; exit 1; }

# The script itself arrives on stdin through the pipe: questions are read from the terminal.
ask() {
    local ans
    [[ "${CORTEX_YES:-}" == 1 ]] && return 0
    has_tty || die "no terminal to ask: run again with CORTEX_YES=1"
    read -r -p "  $1 [y/N] " ans </dev/tty
    [[ "$ans" =~ ^[YyOo]$ ]]
}

# Commands that may read input get the terminal, not the rest of this script.
has_tty() { { : </dev/tty; } 2>/dev/null; }
on_tty() { if has_tty; then "$@" </dev/tty; else "$@" </dev/null; fi; }

# Everything runs from main(), called on the last line: bash has then read the whole script, so
# nothing it starts (sudo, Wine, the setup wizard) can swallow the rest of it from the pipe.
main() {
[[ $EUID -ne 0 ]] || die "run this as your normal user, not root: it asks for sudo when needed"

INSTALLER=""
if [[ $# -ge 1 ]]; then
    [[ -f "$1" ]] || die "installer not found: $1"
    INSTALLER="$(realpath "$1")"
fi

cat <<'EOF'

  Cortex Control on Linux (unofficial, not affiliated with Neural DSP)

  Provided as is, without warranty: back up your presets before using it.
  This script installs the missing packages, a udev rule (with sudo), downloads the
  official Cortex Control installer from Neural DSP and sets it up under Wine.
EOF
ask "Continue?" || die "cancelled, nothing was changed"

step "Packages"
local cmd missing=() pkgs=() pm=() yes wine_version major
for cmd in wine winetricks 7z magick curl tar; do command -v "$cmd" >/dev/null || missing+=("$cmd"); done
if (( ${#missing[@]} )); then
    if command -v pacman >/dev/null; then
        declare -A PKG=([wine]=wine [winetricks]=winetricks [7z]=7zip [magick]=imagemagick [curl]=curl [tar]=tar)
        pm=(sudo pacman -S --needed); yes=--noconfirm
    elif command -v dnf >/dev/null; then
        declare -A PKG=([wine]=wine [winetricks]=winetricks [7z]=p7zip-plugins [magick]=ImageMagick [curl]=curl [tar]=tar)
        pm=(sudo dnf install); yes=-y
    elif command -v apt-get >/dev/null; then
        declare -A PKG=([wine]=wine [winetricks]=winetricks [7z]=7zip [magick]=imagemagick [curl]=curl [tar]=tar)
        pm=(sudo apt-get install); yes=-y
        # apt-cache show succeeds for a package that is only referenced: check the install candidate.
        if [[ " ${missing[*]} " == *" winetricks "* ]] \
            && [[ "$(apt-cache policy winetricks 2>/dev/null | sed -n 's/^ *Candidate: *//p')" =~ ^(|\(none\))$ ]]; then
            die "winetricks is not in your apt sources. On Debian it is in the contrib section: add 'contrib' to your
       sources (/etc/apt/sources.list.d/debian.sources), run 'sudo apt update', then run this again"
        fi
    else
        die "missing: ${missing[*]}. Install them with your package manager, then run this again"
    fi
    for cmd in "${missing[@]}"; do pkgs+=("${PKG[$cmd]}"); done
    echo "  Missing: ${missing[*]}"
    ask "Run '${pm[*]} ${pkgs[*]}'?" || die "install ${pkgs[*]} yourself, then run this again"
    # CORTEX_YES=1 also answers the package manager's own question.
    [[ "${CORTEX_YES:-}" == 1 ]] && pm+=("$yes")
    on_tty "${pm[@]}" "${pkgs[@]}"
fi
wine_version="$(wine --version)"
major="$(sed -n 's/^wine-\([0-9]*\).*/\1/p' <<<"$wine_version")"
if (( ${major:-0} < MIN_WINE )); then
    warn "$wine_version: Cortex Control does not detect the device before Wine $MIN_WINE."
    warn "Get a newer Wine (https://gitlab.winehq.org/wine/wine/-/wikis/Download), or see"
    warn "https://github.com/0xteo/cortex-control-linux, which supports Wine 10."
    ask "Continue anyway?" || die "cancelled"
else
    ok "$wine_version"
fi
if ! compgen -G '/usr/share/vulkan/icd.d/*.json' >/dev/null && ! compgen -G '/etc/vulkan/icd.d/*.json' >/dev/null; then
    warn "no Vulkan driver found: the app window may stay black (install your distribution's Mesa Vulkan drivers)"
fi

step "Scripts"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR:-}"' EXIT
if [[ -n "${CORTEX_SOURCE:-}" ]]; then
    # Tests: install from a local copy of the project instead of GitHub.
    cp -a "$CORTEX_SOURCE/." "$TMP_DIR/" && rm -rf "$TMP_DIR/.git"
else
    curl -fsSL "https://github.com/$REPO/archive/refs/heads/$BRANCH.tar.gz" | tar -xz -C "$TMP_DIR" --strip-components=1 \
        || die "could not download the scripts from GitHub"
fi
rm -rf "$APP_DIR"
mkdir -p "$(dirname "$APP_DIR")" "$BIN_DIR"
mv "$TMP_DIR" "$APP_DIR"
trap - EXIT
ln -sf "$APP_DIR/cortex-control" "$BIN_DIR/cortex-control"
ok "Installed in $APP_DIR, command: $BIN_DIR/cortex-control"
[[ ":$PATH:" == *":$BIN_DIR:"* ]] || warn "$BIN_DIR is not in your PATH: use the menu entry or the full path"

step "USB access (udev rule)"
if cmp -s "$APP_DIR/udev/70-quad-cortex.rules" "$RULE"; then
    ok "udev rule already installed"
else
    echo "  Gives your user access to the Quad Cortex control channel ($RULE)."
    ask "Install it with sudo?" || die "without it Cortex Control cannot talk to the device"
    on_tty sudo install -m 644 "$APP_DIR/udev/70-quad-cortex.rules" "$RULE"
    on_tty sudo udevadm control --reload
    on_tty sudo udevadm trigger --subsystem-match=hidraw
    ok "udev rule installed: unplug and replug the Quad Cortex if it is connected"
fi

if find "$PREFIX/drive_c" -iname 'Cortex Control.exe' -print -quit 2>/dev/null | grep -q .; then
    step "Cortex Control is already installed: refreshing the menu entry"
    "$APP_DIR/cortex-control" desktop
    echo "  To look for a newer Cortex Control: cortex-control update"
else
    # Downloads the tested installer from Neural DSP (checksum verified) unless one was given.
    step "Installing under Wine (the Windows setup wizard opens: keep the default options)"
    on_tty "$APP_DIR/cortex-control" install ${INSTALLER:+"$INSTALLER"}
fi

step "Checks"
"$APP_DIR/cortex-control" doctor || true
printf '\nDone. Start "Cortex Control" from your application menu, or run: cortex-control run\n'
printf 'To uninstall: curl -fsSL https://raw.githubusercontent.com/%s/main/uninstall.sh | bash\n' "$REPO"
}

main "$@"
