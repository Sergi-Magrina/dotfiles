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
