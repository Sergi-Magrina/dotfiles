#!/usr/bin/env bash
# set-wallpaper <img> — swap the live wallpaper, INDEPENDENTLY of the palette
# (phase 7b). <img> is an absolute path or a filename under hypr/wallpapers/.
# The live selection is local, gitignored state; the committed wallpaper path in
# hypr/hyprpaper.conf never moves (honouring the "don't commit wallpaper" rule).
#
# Driven over hyprpaper's IPC (`hyprctl hyprpaper`), which replaced swaybg on
# real hardware — swapping now happens inside the running daemon instead of
# killing and respawning it, so there's no flicker. See vm-substitutions.md.
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

# hyprctl talks to Hyprland over its instance socket, so it needs
# HYPRLAND_INSTANCE_SIGNATURE (and hyprpaper itself needs WAYLAND_DISPLAY).
# Recover both from waybar's environment if we weren't launched inside a session
# that has them — e.g. run over SSH.
for var in HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY; do
    eval "cur=\${$var:-}"
    [ -n "$cur" ] && continue
    pid="$(pgrep -x waybar | head -1 || true)"
    [ -n "$pid" ] || continue
    val="$(tr '\0' '\n' < "/proc/$pid/environ" | grep -m1 "^$var=" | cut -d= -f2-)"
    [ -n "$val" ] && export "$var=$val"
done

# Start hyprpaper if it isn't up (e.g. it crashed), and wait for its IPC to
# answer — a `wallpaper` sent before the daemon is listening is silently lost.
if ! pgrep -x hyprpaper >/dev/null; then
    setsid hyprpaper >/dev/null 2>&1 &
    for _ in $(seq 1 50); do
        hyprctl hyprpaper listactive >/dev/null 2>&1 && break
        sleep 0.1
    done
fi

# `,<path>` targets all monitors (empty monitor field = every output). This is
# the whole point of using hyprpaper: it swaps inside the running daemon, so no
# kill/respawn and no flicker.
#
# hyprpaper 0.8 removed `preload` and `unload` — it manages image memory itself,
# and those requests now fail with "invalid hyprpaper request". Don't re-add them
# from an older guide; `wallpaper` alone is the whole API here (plus `listactive`).
hyprctl hyprpaper wallpaper ",$img" >/dev/null

echo "set-wallpaper: wallpaper -> $img"
