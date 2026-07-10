#!/usr/bin/env bash
# set-wallpaper <img> — swap the live wallpaper, INDEPENDENTLY of the palette
# (phase 7b). <img> is an absolute path or a filename under hypr/wallpapers/.
# The live selection is local, gitignored state; the committed swaybg line in
# hyprland.lua never moves (honouring the "don't commit wallpaper" rule).
set -euo pipefail

THEME="$(dirname "$(realpath "$0")")"
REPO="$(dirname "$THEME")"
WALLDIR="$REPO/hypr/wallpapers"
DEFAULT="$WALLDIR/gargantua.jpg"   # frozen committed default (fallback)

arg="${1:-}"
if [ -z "$arg" ]; then
    echo "usage: set-wallpaper <image>" >&2
    echo "wallpapers in $WALLDIR:" >&2
    for f in "$WALLDIR"/*; do echo "  $(basename "$f")"; done >&2
    exit 1
fi

if   [ -f "$arg" ];           then img="$(realpath "$arg")"
elif [ -f "$WALLDIR/$arg" ];  then img="$WALLDIR/$arg"
else
    echo "set-wallpaper: '$arg' not found — falling back to default" >&2
    img="$DEFAULT"
fi
[ -f "$img" ] || { echo "set-wallpaper: default missing too ($img)" >&2; exit 1; }

mkdir -p "$THEME/state"
printf '%s\n' "$img" > "$THEME/state/active-wallpaper"

# swaybg needs a Wayland connection; recover it if we're not already in one.
if [ -z "${WAYLAND_DISPLAY:-}" ]; then
    pid="$(pgrep -x waybar | head -1 || true)"
    [ -n "$pid" ] && export WAYLAND_DISPLAY="$(tr '\0' '\n' < "/proc/$pid/environ" \
        | grep -m1 '^WAYLAND_DISPLAY=' | cut -d= -f2)"
fi

killall swaybg 2>/dev/null || true
setsid swaybg -i "$img" -m fill >/dev/null 2>&1 &

echo "set-wallpaper: wallpaper -> $img"
