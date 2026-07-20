#!/usr/bin/env bash
# set-theme <name> — switch the active COLOUR palette on the live session
# (phase 7b). Colours only; the wallpaper is a separate axis (set-wallpaper.sh).
#
#   writes theme/state/active-palette  ->  regenerates every colour consumer
#   restarts waybar (it doesn't hot-reload); Hyprland hot-reloads colors.lua
#   itself; rofi/kitty re-read on next launch / new window (already-open
#   terminals keep the old colours until reopened — kitty can be told to
#   re-read in place with ctrl+shift+F5).
set -euo pipefail

THEME="$(dirname "$(realpath "$0")")"

usage() {
    echo "usage: set-theme <name>      switch the live palette" >&2
    echo "       set-theme --list      palette names, one per line" >&2
    echo "       set-theme --current   the palette actually in use" >&2
    echo "       set-theme --default   the fallback palette name" >&2
    echo "palettes:" >&2
    for f in "$THEME"/palettes/*.env; do echo "  $(basename "${f%.env}")"; done >&2
    exit 1
}

# Must match gen.py's DEFAULT_PALETTE and colors.lua's DEFAULT — the value every
# consumer falls back to when no palette is selected.
DEFAULT_PALETTE="red-black"

# --- query interface (phase 9) ---------------------------------------------
# A frontend (the settings app; today theme/pick.sh) needs to render the list of
# palettes and show which one is live. Both answers come from here rather than
# each frontend re-implementing "read the state file, handle the fallbacks" —
# there are three fallback cases below and a UI getting them wrong shows the
# user a theme they aren't running. Output is one item per line on STDOUT,
# nothing else, exit 0, and the live session is left untouched.
case "${1:-}" in
    --list)
        for f in "$THEME"/palettes/*.env; do basename "${f%.env}"; done
        exit 0 ;;
    --current)
        # Report what the desktop is ACTUALLY using, which is not simply the
        # file's contents: absent, empty, or naming a palette that no longer
        # exists all mean every consumer falls back to the default.
        cur="$DEFAULT_PALETTE"
        if [ -r "$THEME/state/active-palette" ]; then
            n="$(tr -d '[:space:]' < "$THEME/state/active-palette")"
            [ -n "$n" ] && [ -f "$THEME/palettes/$n.env" ] && cur="$n"
        fi
        printf '%s\n' "$cur"
        exit 0 ;;
    --default)
        printf '%s\n' "$DEFAULT_PALETTE"
        exit 0 ;;
esac

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
# event, so autostart (waybar/hyprpaper/Control Center) is left untouched.
if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && command -v hyprctl >/dev/null; then
    hyprctl reload >/dev/null 2>&1 || true
fi

# waybar doesn't hot-reload at all -> restart it.
killall waybar 2>/dev/null || true
setsid waybar >/dev/null 2>&1 &

# mako DOES hot-reload, but only when told — no-op if it isn't running yet
# (it's D-Bus-activated on the first notification and reads the fresh config).
command -v makoctl >/dev/null && makoctl reload 2>/dev/null || true

# The ws-0 Control Center panels (phase 8) re-read their colours only on
# launch — cava's generated config, the GTK music widget, and the placeholder
# terminals alike — so respawn them: the same "doesn't hot-reload, restart it"
# pattern as waybar. Kill by window CLASS (exactly what the cc-* rules match):
# that covers the terminal panels and the GTK widget alike, and unlike a pkill
# -f on script paths it can't graze an unrelated process (e.g. an editor) whose
# command line merely mentions a cc-* file. If hyprctl is unreachable, fall back
# to pkill'ing the terminal panels — matching `--class=cc-`, which is how
# control-center.sh spawns them under kitty (it was `--app-id=cc-` under foot in
# the VM). --keep-focus skips control-center.sh's login-time snap to ws 1, so a
# live theme switch doesn't move the view.
hyprctl clients -j 2>/dev/null | python3 -c '
import json, os, signal, sys
for c in json.load(sys.stdin):
    if c["class"].startswith("cc-"):
        try:
            os.kill(c["pid"], signal.SIGTERM)
        except (ProcessLookupError, PermissionError):
            pass
' 2>/dev/null || pkill -f -- '--class=cc-' 2>/dev/null || true
setsid "$THEME/../hypr/scripts/control-center.sh" --keep-focus >/dev/null 2>&1 &

# Spicetify (phase 8c — Sergi's call: the Spotify client IS part of the live
# theme loop). gen already rewrote spicetify/color.ini above; `spicetify
# apply` re-patches the client and restarts it to pick the colours up. That's
# heavy, so it runs detached — and only where spicetify exists at all: it's
# absent in the VM, making this a no-op until real hardware.
if command -v spicetify >/dev/null; then
    setsid spicetify apply >/dev/null 2>&1 &
fi

echo "set-theme: active palette -> $name"
