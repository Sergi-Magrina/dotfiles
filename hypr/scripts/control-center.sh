#!/usr/bin/env bash
# control-center.sh — spawn the Control Center windows on workspace 0. Each
# has a unique `cc-*` app-id; the matching window rule in hyprland.lua floats
# it at a fixed size/position on ws 10.
#
# Phase 6 built the frame (all placeholders); phase 8 swaps each `place …`
# line for the real widget, KEEPING the same app-id so the hyprland.lua rules
# keep matching without edits. Still placeholders: cc-calendar / cc-todo
# (gated on Jarvis).

# --keep-focus: skip the login-time snap to ws 1 at the end. Used by
# set-theme's mid-session respawn (phase 8), where yanking the view to ws 1
# on every theme switch would be a bug, not a fix.
keep_focus=0
[ "${1:-}" = "--keep-focus" ] && keep_focus=1

# place <app-id> <label>: a foot window whose class is <app-id>, showing <label>,
# held open by `cat` (blocks on the pty until the window is closed).
place() {
    foot --app-id="$1" -e sh -c \
        "clear; printf '  %s\n\n  (phase-6 placeholder)\n' \"$2\"; exec cat" &
}

# cava (phase 8a): the real widget — same app-id, so the phase-6 cc-cava float
# rule still matches with no hyprland.lua edit. Config is the palette-generated
# cava/config (via ~/.config/cava symlink). Until cava is installed (Sergi's
# pacman action) fall back to a labelled placeholder, so the panel — and the
# 4-window focus wait below — keep working either way.
if command -v cava >/dev/null; then
    foot --app-id=cc-cava cava &
else
    place cc-cava "cava — audio visualizer (not installed: sudo pacman -S cava)"
fi
place cc-calendar "calendar  (jarvis)"
place cc-todo     "todo list (jarvis)"
# music widget (phase 8b): GTK now-playing panel driven by playerctl/MPRIS
# (hypr/scripts/cc-music.py). It sets its own app_id to cc-music via
# GLib.set_prgname, so the same phase-6 rule floats it — verify the class on
# its first real launch. Needs python-gobject (import gi must give PyGObject,
# not the bare at-spi2-core namespace stub — hence the require_version probe);
# fall back to a labelled placeholder until it's installed.
if python3 -c 'import gi; gi.require_version' 2>/dev/null \
        && command -v playerctl >/dev/null; then
    "$(dirname "$(realpath "$0")")/cc-music.py" &
else
    place cc-music "music player — spotify (needs: sudo pacman -S python-gobject playerctl)"
fi
# NOTE: no window for the "other jarvis things (TBD)" zone — it stays empty
#       wallpaper until that area is designed.

# Keep the login view on the empty workspace 1. The cc-* rules already use
# `workspace = "10 silent"` so spawning shouldn't pull focus — and it doesn't
# once a session is settled — but on a FRESH login (ws 1 not yet the settled
# active workspace) the first silent spawn still lands the view on ws 10.
# Verified live: without this, login shows the populated Control Center instead
# of the empty desktop. So once all four placeholders are actually placed, snap
# focus back to ws 1. `hyprctl` works here because the script inherits
# Hyprland's env from the hyprland.start autostart that runs it.
if [ "$keep_focus" -eq 0 ]; then
    for _ in $(seq 1 50); do
        [ "$(hyprctl clients -j | grep -c '"class": "cc-')" -ge 4 ] && break
        sleep 0.1
    done
    hyprctl dispatch 'hl.dsp.focus({workspace=1})'
fi
