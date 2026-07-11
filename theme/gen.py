#!/usr/bin/env python3
"""Palette generator for the rice (roadmap step 7).

Reads the active palette (theme/palettes/<name>.env, where <name> comes from
theme/state/active-palette, defaulting to red-black) and renders every colour
consumer that can't read the palette itself:

  * theme/templates/*.in  ->  the concrete config files (waybar, rofi, foot, cava)
  * theme/colors.env       <- KEY='#hex' for the volume scripts to source/read

Hyprland's colours are NOT rendered here: hypr/colors.lua reads the same palette
directly and Hyprland hot-reloads it. Likewise the wallpaper is a separate axis
(theme/set-wallpaper.sh), never touched by this generator.

Run it directly (`theme/gen.py`) or via `theme/set-theme.sh <name>`. Idempotent:
re-running with the same active palette reproduces byte-identical files.
"""
import re
import sys
from pathlib import Path

# gen.py lives at theme/gen.py; resolve() follows the ~/.config/theme symlink
# back to the real repo, so this works whether run from ~/dotfiles or ~/.config.
THEME = Path(__file__).resolve().parent
REPO = THEME.parent

DEFAULT_PALETTE = "red-black"

# template  ->  the real (symlinked-into-place) file it generates
TEMPLATES = {
    "style.css.in":     REPO / "waybar" / "style.css",
    "config.jsonc.in":  REPO / "waybar" / "config.jsonc",
    "config.rasi.in":   REPO / "rofi" / "config.rasi",
    "foot.ini.in":      REPO / "foot" / "foot.ini",
    "cava.config.in":   REPO / "cava" / "config",
    "mako.config.in":   REPO / "mako" / "config",
    # Spotify client re-skin (phase 8c) — rendered here, but only *applied*
    # where spicetify exists (real hardware); see the template's header.
    "spicetify-color.ini.in": REPO / "spicetify" / "color.ini",
}

# colors.env keys (UPPERCASE, '#'-prefixed) <- palette slots (bare hex).
# These are what the volume scripts consume.
SCRIPT_COLORS = ["background", "accent", "accent_bright", "muted", "foreground"]

PLACEHOLDER = re.compile(r"\{\{(\w+)\}\}")


def active_palette_name():
    """Name from theme/state/active-palette, or the default if absent/empty."""
    state = THEME / "state" / "active-palette"
    try:
        name = state.read_text().strip()
    except FileNotFoundError:
        return DEFAULT_PALETTE
    return name or DEFAULT_PALETTE


def load_palette(name):
    """Parse theme/palettes/<name>.env into {key: value} (bare hex / knobs).

    Lines are `key=value`; blank lines, `#` comment lines, and inline
    `# ...` comments after a value are ignored. Falls back to the default
    palette if <name> doesn't exist, so a bad state file never breaks the desktop.
    """
    path = THEME / "palettes" / f"{name}.env"
    if not path.exists():
        if name != DEFAULT_PALETTE:
            print(f"gen: palette '{name}' not found, using {DEFAULT_PALETTE}",
                  file=sys.stderr)
            return load_palette(DEFAULT_PALETTE)
        sys.exit(f"gen: default palette missing: {path}")

    palette = {}
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        value = value.split("#", 1)[0].strip()   # drop any inline comment
        palette[key.strip()] = value
    return palette


def render(template_text, palette, template_name):
    """Substitute every {{key}} with its palette value; fail on unknown keys."""
    def sub(match):
        key = match.group(1)
        if key not in palette:
            sys.exit(f"gen: {template_name} references unknown palette key "
                     f"'{{{{{key}}}}}'")
        return palette[key]
    return PLACEHOLDER.sub(sub, template_text)


def write_colors_env(palette):
    """Emit theme/colors.env: KEY='#hex' for the bash / python volume scripts."""
    lines = [
        "# GENERATED FILE — do not edit. Written by theme/gen.py from the active palette.",
        "# Sourced by waybar/scripts/volume.sh; read by waybar/scripts/volume-slider.py.",
    ]
    for slot in SCRIPT_COLORS:
        lines.append(f"{slot.upper()}='#{palette[slot]}'")
    (THEME / "colors.env").write_text("\n".join(lines) + "\n")


def main():
    name = active_palette_name()
    palette = load_palette(name)

    for template_name, target in TEMPLATES.items():
        text = (THEME / "templates" / template_name).read_text()
        target.write_text(render(text, palette, template_name))

    write_colors_env(palette)
    print(f"gen: rendered palette '{name}' -> "
          f"{len(TEMPLATES)} configs + colors.env")


if __name__ == "__main__":
    main()
