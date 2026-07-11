#!/usr/bin/env bash
# Symlink every dotfiles config into ~/.config on a fresh machine.
#
# Mirrors the EXACT link layout from the VM: foot/theme/rofi/cava link as
# whole directories, while waybar/ and hypr/ keep a real directory with only
# specific files/subdirs linked inside them. (A blind link of the whole
# waybar/ or hypr/ dir would be wrong.)
#
# Idempotent — safe to re-run:
#   - an existing symlink is just re-pointed
#   - an existing REAL file/dir is moved to <name>.bak before linking
#
# Usage:   ./install/bootstrap-symlinks.sh
# Override repo location if needed:   DOTFILES=/path/to/dotfiles ./install/bootstrap-symlinks.sh
set -euo pipefail

DOTFILES="${DOTFILES:-$HOME/dotfiles}"
CONFIG="$HOME/.config"

link() {
    local src="$DOTFILES/$1" dest="$CONFIG/$2"
    if [[ ! -e "$src" ]]; then
        echo "SKIP    $2   (source missing: $src)"
        return
    fi
    mkdir -p "$(dirname "$dest")"          # ensure parent (e.g. ~/.config/waybar) exists
    if [[ -e "$dest" && ! -L "$dest" ]]; then
        mv "$dest" "$dest.bak"             # preserve a pre-existing real file/dir
        echo "BACKUP  $dest -> $dest.bak"
    fi
    ln -sfn "$src" "$dest"                 # -s symlink, -f force, -n don't descend into a linked dir
    echo "LINK    $dest -> $src"
}

# --- whole-directory links ---
link foot   foot
link theme  theme
link rofi   rofi
link cava   cava
link mako   mako

# --- waybar: directory stays real, only these are linked ---
link waybar/config.jsonc  waybar/config.jsonc
link waybar/scripts       waybar/scripts
link waybar/style.css     waybar/style.css

# --- hypr: directory stays real, only these are linked ---
link hypr/wallpapers    hypr/wallpapers
link hypr/scripts       hypr/scripts
link hypr/colors.lua    hypr/colors.lua
link hypr/hyprland.lua  hypr/hyprland.lua

echo
echo "Done. Log out/in (or restart Hyprland) and relaunch waybar:"
echo "    killall waybar 2>/dev/null; waybar &"
