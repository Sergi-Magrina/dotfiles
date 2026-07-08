#!/usr/bin/env bash
# control-center.sh — spawn the Phase-6 Control Center placeholder windows on
# workspace 0. Each is a foot window with a unique `cc-*` app-id; the matching
# window rule in hyprland.lua floats it at a fixed size/position on ws 10.
#
# PHASE 6 = placeholders only (a label + a held-open terminal). PHASE 8 swaps
# each `place …` line for the real widget, KEEPING the same app-id, e.g.
#   foot --app-id=cc-cava cava &
# so the hyprland.lua rules keep matching without edits.

# place <app-id> <label>: a foot window whose class is <app-id>, showing <label>,
# held open by `cat` (blocks on the pty until the window is closed).
place() {
    foot --app-id="$1" -e sh -c \
        "clear; printf '  %s\n\n  (phase-6 placeholder)\n' \"$2\"; exec cat" &
}

place cc-cava     "cava — audio visualizer"
place cc-calendar "calendar  (jarvis)"
place cc-todo     "todo list (jarvis)"
place cc-music    "music player — spotify"
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
for _ in $(seq 1 50); do
    [ "$(hyprctl clients -j | grep -c '"class": "cc-')" -ge 4 ] && break
    sleep 0.1
done
hyprctl dispatch 'hl.dsp.focus({workspace=1})'
