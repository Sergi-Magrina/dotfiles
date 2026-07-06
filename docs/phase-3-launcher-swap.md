# Phase 3 — Launcher swap (wofi → rofi-wayland)

Spec for a fresh Claude Code session. Roadmap step 3 in
[../CLAUDE.md](../CLAUDE.md).

## Goal
Replace the current app launcher (`wofi`) with **rofi-wayland**, themed to
the project's red/black/gold palette, and rebind `Super+R` to it. Leave
`wofi` installed but unused (no removal).

## Read first
- `CLAUDE.md` — project brief, working conventions, VM constraints (this is
  auto-loaded, but read it).
- `hypr/colors.lua` — the palette, single source of truth.
- `hypr/hyprland.lua` — the `menu` variable (line ~40) and the `Super+R`
  bind (line ~278) are what you'll change.

## Hard constraints (from CLAUDE.md — do not relitigate)
- **`rofi-wayland`, NOT plain `rofi`.** Plain rofi is X11-only and scales
  badly under Hyprland. The `rofi-wayland` package provides the `rofi`
  binary.
- **Claude can't `sudo`/`pacman`.** Ask Sergi to run:
  `sudo pacman -S rofi-wayland`.
- **Symlink discipline.** Config lives in `~/dotfiles/`, symlinked into
  `~/.config/`. Put it in `~/dotfiles/rofi/`, then
  `ln -s ~/dotfiles/rofi ~/.config/rofi`. Never edit `~/.config` directly.
- **Colors = `hypr/colors.lua`.** rofi themes are `.rasi` and can't
  `require()` Lua, so mirror the exact hex values (table below) into the
  theme and add a comment that `colors.lua` is the source of truth.
- **Never assume aesthetic decisions.** Ask Sergi the open questions below
  before finalizing the theme.
- **One logical change per commit.** (Normal commit rules — this is config,
  not a background.)
- **VM software rendering:** judge structure/correctness here, not final
  aesthetics; the final look is judged on real hardware later.

## Palette — mirror into the `.rasi` theme
| Role | Hex |
|---|---|
| background (near-black) | `#0d0d0d` |
| red — text / interactive | `#c8102e` |
| red-bright — hover / active | `#e8384f` |
| gold — accent, used sparingly | `#d4af37` |
| gray — inactive / disabled | `#5a5a5a` |

## Open decisions — ASK Sergi before building the theme
1. **Layout:** centered floating box (typical)? Width (e.g. 600px / 40%)?
   How many result rows visible (e.g. 8)?
2. **Icons:** show app icons next to entries (needs an icon theme
   installed), or text-only?
3. **Font:** which font + size? (monospace to match `foot`, or a sans?)
   Check what's installed first.
4. **Transparency:** opaque, or semi-transparent window? (Ties into the
   phase-5 terminal-transparency look — Sergi may want consistency.)
5. **Accent placement:** red for the selected-entry highlight; gold for the
   prompt/border? Confirm which single element gets gold (it's the *sparing*
   accent — don't overuse it).
6. **Rounding:** match Hyprland's `rounding = 10`?

## Implementation steps
1. Sergi installs `rofi-wayland`.
2. Create `~/dotfiles/rofi/config.rasi` — a `configuration { }` block
   (`modi`, `show-icons`, etc. per the decisions) plus the theme (inline or
   `@theme`).
3. Put the palette into the theme; comment that `hypr/colors.lua` is
   canonical and these hexes must be kept in sync with it.
4. Symlink: `ln -s ~/dotfiles/rofi ~/.config/rofi`.
5. In `hypr/hyprland.lua`, change `local menu = "wofi --show drun"` →
   `local menu = "rofi -show drun"`. `Super+R` already runs `menu`.
   Hyprland hot-reloads on save.
6. Leave `wofi` installed.

## Verify (don't skip)
- Trigger `rofi -show drun` (or press `Super+R` in the live session) and
  screenshot it. Use the desktop-screenshot workflow — it's in this
  project's memory (`grim` via a `WAYLAND_DISPLAY` borrowed from a running
  GUI process; no sudo needed).
- Confirm: rofi opens, is themed red/black/gold, lists apps, launches a
  selected app, and shows no Wayland scaling glitches. Note anything whose
  look can only be judged on real hardware.

## Done when
- `rofi-wayland` installed; `~/dotfiles/rofi/` symlinked into `~/.config/rofi`.
- `Super+R` opens rofi (not wofi), themed to the palette.
- Verified by screenshot in the live session.
- Committed in logical chunks, e.g. "Add rofi-wayland launcher config" then
  "Rebind Super+R from wofi to rofi".

---

## Kickoff prompt (paste into the new session)
```
Start phase 3 of the Hyprland rice — the launcher swap. Read CLAUDE.md and
docs/phase-3-launcher-swap.md first, then work through that spec.

Goal: replace wofi with rofi-wayland as the Super+R app launcher, themed to
the red/black/gold palette in hypr/colors.lua, leaving wofi installed but
unused.

Before building the theme, ask me the open aesthetic decisions listed in the
spec (layout/width, icons, font, transparency, where gold goes, rounding) —
don't assume them. I'll install rofi-wayland myself (you can't sudo). Follow
the symlink discipline, keep commits to one logical change each, and verify
the result with a screenshot of rofi running in the live session. Remember:
rofi-wayland, not plain rofi.
```
