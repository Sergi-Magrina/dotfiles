#!/usr/bin/env bash
# set-theme <name> — switch the active COLOUR palette on the live session
# (phase 7b). Colours only; the wallpaper is a separate axis (set-wallpaper.sh).
#
#   writes theme/state/active-palette  ->  regenerates every colour consumer
#   restarts waybar (it doesn't hot-reload); Hyprland hot-reloads colors.lua
#   itself; rofi/foot re-read on next launch / new window (already-open foot
#   terminals keep the old colours until reopened).
set -euo pipefail

THEME="$(dirname "$(realpath "$0")")"

usage() {
    echo "usage: set-theme <name>" >&2
    echo "palettes:" >&2
    for f in "$THEME"/palettes/*.env; do echo "  $(basename "${f%.env}")"; done >&2
    exit 1
}

name="${1:-}"
[ -n "$name" ] || usage
[ -f "$THEME/palettes/$name.env" ] || { echo "set-theme: no palette '$name'" >&2; usage; }

mkdir -p "$THEME/state"
printf '%s\n' "$name" > "$THEME/state/active-palette"

python3 "$THEME/gen.py"

# --- re-read the new colours on the live session ---------------------------
# From a Hyprland keybind HYPRLAND_INSTANCE_SIGNATURE / WAYLAND_DISPLAY are
# already set; when run detached, recover them from the live session (read
# waybar's env BEFORE we kill it) so hyprctl and waybar can reach Hyprland.
if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    for d in "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"/hypr/*/; do
        [ -S "$d/.socket.sock" ] && export HYPRLAND_INSTANCE_SIGNATURE="$(basename "$d")" && break
    done
fi
if [ -z "${WAYLAND_DISPLAY:-}" ]; then
    pid="$(pgrep -x waybar | head -1 || true)"
    [ -n "$pid" ] && export WAYLAND_DISPLAY="$(tr '\0' '\n' < "/proc/$pid/environ" \
        | grep -m1 '^WAYLAND_DISPLAY=' | cut -d= -f2)"
fi

# Hyprland re-runs colors.lua only on reload, and the gen write doesn't touch
# any file it watches — so without this nudge the window borders keep the old
# palette (the reason a switch used to leave every outline red). `hyprctl reload`
# re-reads config (colours/binds/rules) but does NOT re-fire the hyprland.start
# event, so autostart (waybar/swaybg/Control Center) is left untouched.
if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && command -v hyprctl >/dev/null; then
    hyprctl reload >/dev/null 2>&1 || true
fi

# waybar doesn't hot-reload at all -> restart it.
killall waybar 2>/dev/null || true
setsid waybar >/dev/null 2>&1 &

echo "set-theme: active palette -> $name"
