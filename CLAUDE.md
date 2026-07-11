# Arch + Hyprland Rice — Project Brief

## What this is
A Hyprland dotfiles repo, currently built and tested inside a VirtualBox VM
(the "workshop"). It will later be cloned onto real hardware (the
"showroom"). This repo — `~/dotfiles` — is the single source of truth for
the whole setup.

## Who you're working with
Sergi — comfortable but stil new with concepts, learning Bash/Arch day to day.
Explain non-obvious commands briefly when you introduce them. Don't assume
deep CLI fluency, but don't over-explain things already established in this
file either.

---

## Working conventions (read before editing)

- **One logical change per commit.** Small, reviewable diffs. Don't
  restructure multiple sections of a file in a single commit.
- **Don't commit wallpaper/background changes.** As of the Gargantua
  wallpaper (the last one committed), background swaps are local-only:
  change the live wallpaper and the `swaybg` path in `hyprland.lua` as
  needed, but don't create commits for them. The committed wallpaper line
  and `hypr/wallpapers/` reflect the last agreed background — leave them as
  they are. If you edit `hyprland.lua` for another reason, don't sweep an
  uncommitted wallpaper-line change into that commit.
- **Never assume aesthetic decisions.** Colors, layout specifics, sizing —
  ask before choosing, unless this file already states a decision.
- **Symlink discipline:** all live config is symlinked from `~/dotfiles/*`
  into the real config locations (`~/.config/hypr/`, `~/.config/waybar/`,
  etc.). Always edit files inside `~/dotfiles` — never edit `~/.config`
  directly. If you create a *new* config file here, remember to symlink it
  into place too, or it won't do anything.
- **Lua config, not `.conf`.** This is Hyprland 0.55+, using the Lua config
  format (`hyprland.lua`). Hyprland hot-reloads Lua changes automatically on
  save — no `hyprctl reload` needed for Hyprland itself. **Waybar does not
  hot-reload** — after touching waybar config/CSS, run
  `killall waybar && waybar &` (or trigger via Hyprland's autostart on a
  full restart) to see changes.
- **VM constraints — don't relitigate these:**
  - `kitty` crashes in this VM (software-rendered GPU can't serve it). The
    terminal is `foot`. Never suggest or install kitty here.
  - VirtualBox's shared clipboard does not work under Hyprland (Wayland
    compositor, not X11/GNOME) — this is a known upstream limitation, not a
    bug to chase. SSH + VS Code Remote-SSH is the actual clipboard solution
    in use.
  - When installing packages, check Wayland compatibility specifically —
    e.g. `rofi-wayland`, not plain `rofi` (X11-only, causes scaling issues
    under Hyprland).
  - `hyprpaper` does not render in this VM — it needs a real GL/EGL context
    the software-rendered GPU can't provide (same root cause as kitty). The
    wallpaper daemon here is `swaybg` (static-image, works under software
    rendering). See roadmap step 2 for the hardware-side reconsideration.
  - Visual polish (animations, gradients, general "does it look good") is
    not meaningful to judge in this VM — software rendering. Judge
    *structure and correctness* here; final aesthetic judgment happens on
    real hardware later.
  - The running list of VM-vs-real-hardware program swaps, with versions
    (e.g. kitty→foot, hyprpaper→swaybg), lives in `vm-substitutions.md`. Add
    or reverse a swap there — don't duplicate the version table into this file.

---

## Color palette

Single source of truth: `hypr/colors.lua`. Theme is **black background, red
for text/interactive elements**, with a brighter red variant for hover /
active states. Every other config — waybar, rofi, mako once added — should
`require()` or reference these same values rather than hardcoding its own hex
codes.

This black/red theme is the **default** palette. Roadmap step 7
(selectable palettes) turns it into one of several runtime-swappable themes;
until that phase lands, treat it as the single fixed theme.

---

## Roadmap

1. **Red/black theme** — apply palette to Hyprland borders + waybar
2. **Wallpaper** — wire up `swaybg` into autostart (see VM constraints for
   why not `hyprpaper`). Interim solid dark wallpaper first; custom-generated
   red/black wallpaper later.
   - **Revisit on real hardware:** hyprpaper (Hyprland's native daemon) can
     render there. But for a *single static* wallpaper it's functionally
     equal to swaybg — it only wins if runtime wallpaper switching (its IPC),
     preloading, or per-monitor wallpapers are wanted. Switch back only if
     one of those becomes a real need; otherwise swaybg stays. Cost to
     switch is ~one autostart line + a small `.conf`.
3. **Launcher swap** — install `rofi-wayland`, theme it to match the
   palette, rebind `Super+R` from `wofi` to `rofi`. Leave `wofi` installed
   but unused, no need to remove it.
4. **Workspace assignments** — window rules pinning apps to workspaces by
   class:
   - **1** — empty desktop: wallpaper + waybar only, nothing pinned here
   - **2** — file manager
   - **3** — browser (Firefox — chosen; native Wayland, class `firefox`)
   - **4** — general apps: Claude Desktop, VS Code, Spotify
   - **0** — Control Center (see below — special-cased, not a normal app
     workspace)
5. **Terminal transparency** — a window rule scoped specifically to `foot`
   (class match, not global `decoration.opacity`) so the terminal's black
   background is semi-transparent and wallpaper shows through behind the
   text. Other apps (browser, VS Code, etc.) stay fully opaque.
6. **Control Center layout** (workspace 0) — structurally different from
   every other workspace: windows here are **floating with fixed
   size/position**, not tiled. Tiling auto-fills all available space, which
   is exactly what we don't want here — the goal is deliberate empty space
   with raw wallpaper showing through. Rough intended layout:
   - Music/Spotify widget — top-left
   - `cava` audio visualizer — bottom strip
   - Quick-task terminal (with custom ASCII art, TBD) — a corner
   - Notepad — a tabbed notepad of its own (multiple tabs). Jarvis-linked
     later, so Jarvis can read/write its notes. Tool/app TBD.
7. **Selectable color palettes** (new phase — do not start until 4–6 are
   solid, so every colored surface exists before the switcher is built).
   Goal: several complete themes (not just red/black) the user picks
   from, applied to the whole desktop + all workspaces **at once**, as a
   **runtime hot-swap** (a command/keybind reskins the live session — no
   logout).
   - **Prerequisite refactor:** today the palette is hand-copied into three
     files (`hypr/colors.lua`, `waybar/style.css`, `rofi/config.rasi`) plus
     the swaybg wallpaper. Since CSS and rasi can't `require()` Lua, a
     runtime switch needs a single palette definition that *generates* the
     waybar CSS + rofi rasi (small templating step) rather than three copies
     edited by hand. This consolidation is the foundation and can be pulled
     forward as prep before the rest of the phase.
   - **Hot-swap mechanics:** regenerate waybar + rofi from the chosen
     palette, reload waybar (`killall waybar && waybar &` — it doesn't
     hot-reload), swap the swaybg wallpaper, and let Hyprland hot-reload its
     Lua. A palette-picker UI could later live in the Control Center
     (workspace 0), but the switch *mechanism* is independent of any UI and
     comes first.
   - Reframes the fixed-theme stance in the Color palette section above: the
     black/red theme becomes the *default* palette, one of several.
   - **Full spec: `docs/phase-7-selectable-palettes.md`.** Two things settled
     since this brief was written: the palette is actually hardcoded in **seven**
     files (+ the wallpaper), not three; and **theme and wallpaper are independent
     axes** — choose each freely (wallpaper is *not* a per-theme field, and its
     live selection stays local, honoring the "don't commit wallpaper" rule). The
     pick-now UI is a **rofi** menu; a full settings app is its own later phase
     (step 9).
8. **Deferred / later work** (do not start until 1–7 are solid):
   - Install + configure `cava`
   - Build a Spotify now-playing + basic controls widget
   - Theme the Spotify client itself to the palette via **Spicetify** (needs
     Spotify installed and its ws-4 routing rule verified first; this is the
     client re-skin, separate from the now-playing widget above)
   - ASCII art for the Control Center's quick-task terminal
   - Jarvis integration (voice assistant, separate long-running project) —
     this comes **last**, once the Control Center shell itself is proven
     out. Two Jarvis-fed terminal panes are planned eventually (one showing
     live agent actions/commands, one showing memory/context retrieval) but
     are explicitly out of scope until called for directly.
     **Called for (2026-07-11): the calendar + todo widgets only** — the
     first Jarvis slice, coordinated with a second Claude Code session in
     the jarvis repo (Sergi relays documents between them). Living doc:
     `docs/jarvis-integration.md`. The terminal panes / notepad / voice
     remain out of scope.
9. **Settings app** (a *frontend* — do not start until phase 7's switch
   mechanisms exist; this is a GUI *over* them, not a prerequisite for anything).
   Goal: a clean graphical surface to choose the theme and wallpaper (and, over
   time, other runtime knobs), superseding phase 7's interim rofi picker. Because
   the switches are clean CLIs (`set-theme`, `set-wallpaper`), the app is a thin
   layer buildable whenever after step 7.
   - **Ordering, not strictly last:** depends only on step 7; runs parallel to
     step 8's deferred items and is **independent of Jarvis** (which remains the
     final integration within step 8). Listed at 9 for placement, not because it
     comes after everything.
   - **Shape/tech intentionally open** — standalone GUI vs a Control Center
     (workspace 0) panel; toolkit TBD (e.g. GTK, a webview, or eww/quickshell,
     possibly shared with the Control Center widgets). Decide once the mechanisms
     are real and the desired scope is clearer. Ask, don't assume.

---

## Open decisions (ask, don't assume)

- Exact Control Center widget positions/sizes — rough zones are described
  above, but pixel-level layout should be confirmed before finalizing
- Custom wallpaper generation — revisit once basic theming (steps 1–5) is
  done

---

## Out of scope for this repo

- Ubuntu Server homelab — separate, unrelated project, don't touch
- Jarvis's own codebase — this repo only handles *wiring* Jarvis into the
  desktop later, not building Jarvis itself