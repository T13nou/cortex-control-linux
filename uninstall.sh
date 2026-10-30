#!/usr/bin/env bash
# One-line uninstaller for Cortex Control on Linux:
#   curl -fsSL https://raw.githubusercontent.com/T13nou/cortex-control-linux/main/uninstall.sh | bash
# Removes the Wine prefix (with Cortex Control and its settings), the menu entry and icons, the
# scripts, the cached installer and, after asking, the udev rule. Packages (Wine…) are kept.
# CORTEX_YES=1 answers yes to every question.
set -euo pipefail

DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
APP_DIR="$DATA/cortex-control-linux"
BIN="$HOME/.local/bin/cortex-control"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/cortex-control-linux"
LOG="${XDG_STATE_HOME:-$HOME/.local/state}/cortex-control.log"
PREFIX="${CORTEX_PREFIX:-$DATA/wineprefixes/cortex-control}"
RULE=/etc/udev/rules.d/70-quad-cortex.rules

ok()   { printf '  \e[32mOK\e[0m  %s\n' "$*"; }
die()  { printf '\e[31mError:\e[0m %s\n' "$*" >&2; exit 1; }

ask() {
    local ans
    [[ "${CORTEX_YES:-}" == 1 ]] && return 0
    has_tty || die "no terminal to ask: run again with CORTEX_YES=1"
    read -r -p "  $1 [y/N] " ans </dev/tty
    [[ "$ans" =~ ^[YyOo]$ ]]
}
has_tty() { { : </dev/tty; } 2>/dev/null; }
on_tty() { if has_tty; then "$@" </dev/tty; else "$@" </dev/null; fi; }

# Called on the last line, once bash has read the whole script from the pipe.
main() {
    local desk f ws
    [[ $EUID -ne 0 ]] || die "run this as your normal user, not root: it asks for sudo when needed"

    echo "This removes Cortex Control, its Wine prefix ($PREFIX) and its settings."
    ask "Continue?" || die "cancelled, nothing was changed"

    if [[ -d "$PREFIX" ]]; then
        # Debian and Ubuntu keep wineserver out of PATH.
        ws="$(type -P wineserver || compgen -G '/usr/lib/*/wine/wineserver' | head -1 || true)"
        [[ -n "$ws" ]] && WINEPREFIX="$PREFIX" "$ws" -k 2>/dev/null || true
        rm -rf "$PREFIX"
        ok "Wine prefix removed"
    fi

    desk="$(xdg-user-dir DESKTOP 2>/dev/null || echo "$HOME/Desktop")"
    rm -rf "$DATA/applications/wine/Programs/Cortex Control"
    rm -f "$DATA/applications/cortex-control.desktop" \
          "$DATA/desktop-directories/wine-Programs-Cortex Control.directory" \
          "$desk/Cortex Control.lnk"
    f="$desk/Cortex Control.desktop"
    if [[ -f "$f" ]] && grep -qi wine "$f"; then rm -f "$f"; fi
    find "$DATA/icons/hicolor" -path '*/apps/*' \( -name 'cortex-control.png' -o -name '*_Cortex Control.0.png' \) \
        -delete 2>/dev/null || true
    command -v update-desktop-database >/dev/null && update-desktop-database "$DATA/applications" >/dev/null 2>&1 || true
    command -v kbuildsycoca6 >/dev/null && kbuildsycoca6 >/dev/null 2>&1 || true
    ok "Menu entry, shortcuts and icons removed"

    [[ -L "$BIN" ]] && rm -f "$BIN"
    rm -rf "$APP_DIR" "$CACHE_DIR"
    rm -f "$LOG"
    ok "Scripts, cached installer and log removed"

    if [[ -f "$RULE" ]]; then
        if ask "Remove the udev rule $RULE (needs sudo)?"; then
            on_tty sudo rm -f "$RULE"
            on_tty sudo udevadm control --reload
            ok "udev rule removed"
        else
            echo "  udev rule kept: $RULE"
        fi
    fi

    echo
    echo "Done. Packages installed for it (wine, winetricks, 7zip, imagemagick) were kept."
}

main "$@"
