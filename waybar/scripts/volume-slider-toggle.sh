#!/usr/bin/env bash
# Toggle the themed volume-slider popup (volume-slider.py). Bound to a left-click
# on the waybar volume icon: if the slider is already open, close it; otherwise
# open it anchored under the cursor (i.e. under the icon you just clicked).
#
# The click x-coordinate comes from `hyprctl cursorpos` and is passed to the
# popup so it lands under the icon regardless of how wide the other right-side
# modules are.

SLIDER="$HOME/.config/waybar/scripts/volume-slider.py"

# Already open? Close and we're done.
if pkill -f "volume-slider.py"; then
    exit 0
fi

# Cursor x at click time → column to center the popup on.
x=$(hyprctl cursorpos 2>/dev/null | cut -d',' -f1 | tr -d ' ')
[[ "$x" =~ ^[0-9]+$ ]] || x=0

# setsid -f detaches so waybar's click handler returns immediately.
setsid -f python3 "$SLIDER" "$x" >/dev/null 2>&1
