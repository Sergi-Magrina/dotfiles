#!/usr/bin/env bash
# pick.sh — rofi picker for theme + wallpaper (phase 7b). The "choose freely"
# UX: a rofi menu over the two switch CLIs (set-theme / set-wallpaper). Theme
# and wallpaper are independent axes, so the menu branches to one or the other.
# A full settings app is a later frontend phase; this reuses the phase-3 rofi
# launcher, so it needs no new tooling. Bind it to a key (Super+T) or run it
# directly.
set -euo pipefail

THEME="$(dirname "$(realpath "$0")")"
REPO="$(dirname "$THEME")"
WALLDIR="$REPO/hypr/wallpapers"

menu() { rofi -dmenu -i -p "$1"; }

active_palette="red-black"
[ -f "$THEME/state/active-palette" ] && active_palette="$(cat "$THEME/state/active-palette")"

# Top level: which axis to change. Plain-text labels (no Nerd Font PUA glyphs —
# those get stripped when the file is written).
top="$(printf '%s\n%s\n' "Theme (colours)" "Wallpaper" | menu "Customise")"

case "$top" in
    "Theme (colours)")
        choice="$(for f in "$THEME"/palettes/*.env; do basename "${f%.env}"; done \
                  | menu "Theme  [current: $active_palette]")"
        [ -n "$choice" ] && "$THEME/set-theme.sh" "$choice"
        ;;
    "Wallpaper")
        choice="$(for f in "$WALLDIR"/*; do basename "$f"; done | menu "Wallpaper")"
        [ -n "$choice" ] && "$THEME/set-wallpaper.sh" "$choice"
        ;;
esac
