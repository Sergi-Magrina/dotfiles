# Phase 7 — Selectable color palettes (runtime hot-swap)

Spec for a fresh Claude Code session. Roadmap step 7 in
[../CLAUDE.md](../CLAUDE.md). This phase turns the single fixed black/red theme
into **one of several complete palettes**, switchable on the **live session**
(no logout), applied to the **whole desktop at once**.

It splits into two sub-phases that should land in order:

- **7a — Consolidation refactor** (the roadmap's "prerequisite refactor").
  *No visible change.* Black/red stays pixel-identical; the only difference is
  that it now flows from **one** palette source through a generator into every
  colored surface, instead of being hand-copied. This is the foundation — do it
  first, on its own.
- **7b — Multiple palettes + hot-swap.** Add more palettes and a switch
  command/keybind that reskins the running session.

The **Decisions (settled)** section is settled — don't re-ask it. The genuinely
open items (which is *most* of the aesthetic/architecture surface) are collected
at the bottom under **Open decisions still needed** — ask Sergi before building
those, don't invent.

---

## Why 7a exists (and why the roadmap undercounts the work)

The roadmap says the palette is *"hand-copied into three files
(`hypr/colors.lua`, `waybar/style.css`, `rofi/config.rasi`) plus the swaybg
wallpaper."* **That is out of date.** A full audit of the repo
(`git grep` for hex codes) finds the palette hardcoded in **seven files plus the
wallpaper**, and turns up a **fifth colour** that isn't in `colors.lua` at all.

Any runtime switch has to update **all** of these, so the refactor's first job is
just to *see* them. This is the authoritative inventory — build against it, not
the roadmap's "three files".

### The complete palette-consumer inventory

| # | File | What it holds | Syntax | Reloads how? |
|---|---|---|---|---|
| 1 | [../hypr/colors.lua](../hypr/colors.lua) | **Source of truth today.** `background`, `red`, `red_bright`, `gray` + `rgba()` helper. Consumed by Hyprland borders (`hyprland.lua:120`). | bare hex, no `#` | Hyprland **auto hot-reloads** on save |
| 2 | [../waybar/style.css](../waybar/style.css) | `@define-color` × 4 **+ `#ffffff`** (inactive workspace numbers, line 40 — *not in colors.lua*) **+ `alpha(@red, 0.35)`** (hairline, derived) | `@define-color n #hex;` | Waybar **does NOT hot-reload** → `killall waybar && waybar &` |
| 3 | [../waybar/config.jsonc](../waybar/config.jsonc) | line 26: inline Pango `<span foreground='#c8102e'>0</span>` (the ws-0 pill) | `#hex` inside a JSON string, inside Pango markup | with waybar (as above) |
| 4 | [../waybar/scripts/volume.sh](../waybar/scripts/volume.sh) | lines 14–16: `RED`, `RED_BRIGHT`, `GRAY` | Bash `'#hex'` | re-runs on each audio event / waybar start |
| 5 | [../waybar/scripts/volume-slider.py](../waybar/scripts/volume-slider.py) | lines 30–33: `BG`, `RED`, `RED_BRIGHT`, `GRAY` → builds GTK CSS | Python `"#hex"` | rebuilt each popup open |
| 6 | [../rofi/config.rasi](../rofi/config.rasi) | `bg`, **`bg-alpha` = `#0d0d0dcc`** (derived: background @ ~80%), `red`, `red-bright`, `gray`, `transparent` | rasi `n: #hex;` / 8-digit `#rrggbbaa` | re-read **on each launch** — no reload needed |
| 7 | [../foot/foot.ini](../foot/foot.ini) | `background=0d0d0d` + `alpha=0.85`. Foreground/ANSI are still **foot defaults** (deferred). | bare hex, no `#` | applies to **new** foot windows only |
| — | swaybg wallpaper | image path in the autostart line, `hyprland.lua:68` | file path, not a colour | `killall swaybg; swaybg -i … &` |

### Five colours, not four

`colors.lua` defines four (`background`, `red`, `red_bright`, `gray`), but the
live desktop uses a **fifth**: plain white `#ffffff` for **inactive workspace
numbers** (`style.css:40`). It was never promoted into the palette because in a
black/red world "white text" reads as theme-neutral. It isn't — a green or blue
palette will want different inactive-number and muted tones. So the palette
schema needs slots for it. Proposed 5-slot schema (names to confirm):

| Slot | Today | Role |
|---|---|---|
| `background` | `0d0d0d` | near-black surface |
| `red` (→ generic `accent`) | `c8102e` | primary text / interactive |
| `red_bright` (→ `accent_bright`) | `e8384f` | hover / active / selection |
| `gray` (→ `muted`) | `5a5a5a` | inactive / disabled |
| `foreground` **(new)** | `ffffff` | plain text (inactive ws numbers) |

Plus two **derived** values the generator must reproduce, not store:
`rofi bg-alpha` = `background` + alpha byte `cc`; `waybar hairline` =
`alpha(@red, 0.35)` (stays a literal GTK expression referencing the accent — no
hex derivation). And one **non-colour per-theme knob**: `foot_alpha` (`0.85`).

> **Wallpaper is NOT a palette field.** Theme (colours) and wallpaper (image)
> are **two independent axes** — pick any theme with any wallpaper. See
> "Wallpaper is its own axis" below. This is a settled decision, not the
> earlier draft's per-theme wallpaper.

> **Naming note:** keeping the field names `red` / `red_bright` in a *multi-theme*
> world is a lie (a blue theme's `red` = blue). Renaming to
> `accent` / `accent_bright` / `muted` is cleaner but touches every consumer +
> `hyprland.lua`. Whether to rename now (in 7a, while touching everything anyway)
> or keep the red-named fields is **Open decision 6**.

---

## Recommended architecture (a proposal — forks flagged as open decisions)

The roadmap's ask: *"a single palette definition that generates the waybar CSS +
rofi rasi rather than three copies edited by hand."* Generalised to the real
seven consumers, the cleanest shape that keeps the current symlink model intact:

```
theme/
  palettes/
    red-black.env          # THE palette source: key=hex + foot_alpha (NO wallpaper — separate axis)
    <other>.env            # 7b: more palettes (colours TBD — Open decision 1)
  templates/
    style.css.in           # waybar CSS with {{red}} {{background}} … placeholders
    config.rasi.in         # rofi
    foot.ini.in            # foot
    ws0-label.jsonc.in     # the one Pango line in waybar/config.jsonc (or template the whole file)
  gen.<lang>               # reads active palette → renders templates → writes the real files
                           #   + emits theme/colors.env (KEY=#hex) for the scripts
  set-theme.sh <name>      # 7b: switch active palette → gen → reload waybar → Hyprland auto-reloads
  set-wallpaper.sh <img>   # 7b: swap the wallpaper INDEPENDENTLY (killall swaybg; swaybg …)
  pick.sh                  # 7b: rofi menu → set-theme / set-wallpaper (free choice, no settings app yet)
  state/                   # LOCAL runtime state — GITIGNORED (see "don't commit wallpaper" rule)
    active-palette         #   name of the live palette   (absent → default red-black)
    active-wallpaper       #   path of the live wallpaper (absent → the frozen swaybg line, Gargantua)
```

`hypr/colors.lua` (the shim) and `gen` read `state/active-palette`, falling back
to **red-black** when it's absent — so a fresh clone works with no state. The
live wallpaper is read from `state/active-wallpaper`, falling back to the
committed `path` in `hypr/hyprpaper.conf`. Both state files are **gitignored** —
the live selections are local, exactly as the "don't commit wallpaper changes"
rule wants.

> **Amended 2026-07-20 — the generated configs are no longer committed.**
> Originally the red-black renderings were committed as the fresh-clone
> baseline, and a palette switch left all nine files dirty in `git status`
> "by design". That backfired: a session tidied the dirty files with
> `git checkout`, which reverted them to red-black but left
> `state/active-palette` still reading `purple-blue` — so the state file and
> the actual desktop disagreed, silently.
>
> They're now **gitignored build artifacts**, rendered from
> `templates/*.in` + `palettes/*.env`. `gen.py` runs at bootstrap
> (`install/bootstrap-symlinks.sh`, *before* the symlinks — `link()` skips a
> missing source) and again at every login (`hypr/hyprland.lua`, at parse
> time via a blocking `os.execute`, so waybar and the Control Center find
> their configs already written). The palette **selection** is the only
> persisted thing; the configs are re-derived from it.
>
> Consequences: switching palettes never dirties the tree, drift is
> structurally impossible, red-black remains the default via the
> `DEFAULT_PALETTE` constants in `gen.py`/`colors.lua` rather than via
> committed file contents, and a palette choice now survives a reboot on its
> own. The acceptance test at the bottom of this doc ("the generated files
> match what's committed") no longer applies — nothing is committed to match.

**One palette format, readable by all three languages.** Make the palette a
plain `key=hex` file:

```sh
# theme/palettes/red-black.env   — colours only; no wallpaper (that's a separate axis)
background=0d0d0d
red=c8102e
red_bright=e8384f
gray=5a5a5a
foreground=ffffff
foot_alpha=0.85
```

This one format is:
- **`source`-able by Bash** (`volume.sh`),
- **trivially parsed by Lua** (`colors.lua` reads it and rebuilds the `M` table,
  keeping the `rgba()` helper and the exact field names `hyprland.lua` expects —
  so `require("colors")` keeps working unchanged), and
- **trivially parsed by Python** (`volume-slider.py`, and the generator if it's
  Python).

**Two integration styles, by consumer type:**
- **Declarative configs** (CSS, rasi, ini, the jsonc Pango line) → **templated**:
  `gen` renders `*.in` → the concrete file that's already symlinked into place.
  Comments and formatting live in the template, so the generated file is
  byte-for-byte what's committed today.
- **Executable scripts** (`volume.sh`, `volume-slider.py`) → **runtime-read**:
  they `source ~/.config/theme/colors.env` (or read it) instead of hardcoding
  hex. Cleaner than find/replacing inside code, and it means those two files stop
  carrying literals entirely.

**`hypr/colors.lua` stays the Hyprland entry point** but becomes a ~15-line shim:
read the active `.env`, build `M.background/red/red_bright/gray/foreground`, keep
`M.rgba()`. Hyprland still `require("colors")`s it and still hot-reloads.

### Architecture forks (recommended, but confirm — Open decisions 6–9)
- **Palette format** = `key=hex` env (above). *Recommended* over Lua-table
  palettes because CSS/rasi/scripts can't `require()` Lua but can all read
  key=hex.
- **Generator language** = **Python** (already a repo dependency via
  `volume-slider.py`; robust string handling). Bash+`sed` is simpler but fragile
  with `#`/`/` in values. *Recommend Python.*
- **Generated declarative files: commit them or gitignore them?**
  - *(A, recommended)* **Keep them committed.** They're symlinked exactly as now;
    `gen` overwrites them in place; a clone works with zero build step. The
    acceptance test for 7a becomes "regenerating reproduces the committed files."
    Cost: generated CSS/rasi live in git (a little redundant with the templates).
  - *(B)* Gitignore them, generate on clone/switch. Cleaner git, but a fresh
    clone's waybar/rofi are broken until `gen` runs, and the symlink targets must
    exist first.
- **Theme dir location** = top-level `theme/` (theming is cross-app; it doesn't
  belong under `hypr/` or `waybar/`).

### Wallpaper is its own axis (settled)

Theme = colours, wallpaper = image, chosen **independently**. You pick a palette
*and* a wallpaper separately; neither is bound to the other. Concretely:

- Palettes hold **no** wallpaper field. Wallpaper is its own selection.
- Two independent live selections, each a **local, gitignored** state file
  (`state/active-palette`, `state/active-wallpaper`) — swapped by two separate
  commands, `set-theme` and `set-wallpaper`.
- **This is how free wallpaper choice coexists with "don't commit wallpaper
  changes":** the live wallpaper is local runtime state (exactly the "local-only"
  handling CLAUDE.md already describes), the wallpaper *images* live in
  `hypr/wallpapers/`, and the committed `swaybg` default line stays frozen at
  Gargantua. Switching at runtime writes local state, never a commit.
- A missing/removed image → `set-wallpaper` falls back to the committed default
  (or a solid colour), never a black screen.

### The picker (settled: rofi) and the settings app (a later frontend phase)

**Mechanism first, UI later** — the roadmap's rule. `set-theme` and
`set-wallpaper` are the mechanism; anything that *calls* them is a frontend:

- **Now (Phase 7b): a `rofi` menu** (`theme/pick.sh`) — rofi is already the
  launcher (phase 3), so a `rofi -dmenu` list of palettes and of wallpapers gives
  **free choice immediately**, over the same two CLIs. This is the "choose the
  wallpaper and the theme freely" UX, with zero new tooling. A cycle keybind can
  sit on top if wanted.
- **Later (its own future phase): a clean settings app** — a GUI frontend over
  these same CLIs (and any future toggles). It is **not** part of Phase 7 and
  **not** a prerequisite for anything: because the switch is a clean CLI, the app
  is a thin layer buildable whenever, and it can grow to cover more settings. Its
  shape/tech is intentionally left open (see the roadmap's new frontend phase).
  Phase 7's only obligation to it is: **keep the CLIs clean and scriptable.**

---

## 7a — Consolidation refactor (do this first; zero visible change)

**Goal:** the black/red desktop looks **identical** before and after, but every
colour now derives from `theme/palettes/red-black.env` via `gen`. This is pure
plumbing and is **fully judgeable in the VM** — it's a correctness task
(pixels match), not an aesthetic one.

**Steps (each ≈ one commit — see Commit breakdown):**
1. **Create `theme/` + `red-black.env`** with today's exact values (including the
   newly-inventoried `foreground=ffffff`, `foot_alpha=0.85`, `wallpaper=`).
2. **Add templates** (`style.css.in`, `config.rasi.in`, `foot.ini.in`, the ws-0
   Pango line) — copies of today's files with hex swapped for `{{placeholders}}`,
   comments preserved.
3. **Write `gen`** — render templates → write the real files; compute the derived
   `rofi bg-alpha` (`background` + `cc`); emit `theme/colors.env` for the scripts.
4. **Rewrite `hypr/colors.lua` as the shim** that reads the active `.env`. Verify
   Hyprland borders still render red (hot-reload, check a window border).
5. **Repoint the two scripts** (`volume.sh`, `volume-slider.py`) to read
   `theme/colors.env` instead of hardcoded hex.
6. **Symlink the new dir**: `~/.config/hypr` is **per-file** symlinked (not a
   whole-dir link), so `theme/` needs its own link into wherever `gen` and the
   scripts expect it — e.g. `ln -s ~/dotfiles/theme ~/.config/theme`. (rofi,
   foot, and colors.lua are already linked; the *generated* files land at their
   existing symlinked paths, so those links don't change.)

**Acceptance test for 7a (the whole point):** run `gen`, then
`git diff` — the regenerated `style.css`, `config.rasi`, `foot.ini`, and the
`config.jsonc` Pango line should be **unchanged** (or trivially, explainably
different — e.g. whitespace). Then screenshot the desktop and compare to a
pre-refactor capture: **no visible difference.** If regeneration reproduces the
committed files and the screenshot matches, the consolidation is correct.

> **Waybar reload reminder:** waybar doesn't hot-reload, so after `gen` rewrites
> `style.css`/`config.jsonc` you must `killall waybar && waybar &` to *see* the
> (identical) result. rofi and foot pick up on next launch/new-window; Hyprland
> hot-reloads `colors.lua` itself.

---

## 7b — Multiple palettes + runtime hot-swap

Only start once 7a is solid (one palette flowing through the generator).

**Steps:**
1. **Add palette file(s)** — `theme/palettes/<name>.env`. The actual colours are
   **Open decision 1** (pure aesthetics — ask Sergi). *Recommend proving the
   mechanism with a single second palette first, then adding more.*
2. **Write `theme/set-theme.sh <name>`** — the **colours-only** switch:
   ```
   write  state/active-palette  ← <name>
   run    gen                                   # regenerate every colour consumer
   waybar: killall waybar && waybar &           # no hot-reload
   Hyprland: (nothing — it hot-reloads colors.lua on the gen write)
   rofi/foot: (nothing — re-read on next launch / new window)
   ```
   Note it does **not** touch the wallpaper — that's the separate axis.
3. **Write `theme/set-wallpaper.sh <img>`** — the **independent** wallpaper swap:
   ```
   write  state/active-wallpaper ← <img>        # local state, gitignored
   swaybg: killall swaybg; swaybg -i <img> -m fill &
   ```
   `<img>` is one of `hypr/wallpapers/*`; a missing file falls back to the
   committed default. Never edits the committed `swaybg` line in `hyprland.lua`.
4. **Write `theme/pick.sh`** — the **rofi picker** (the "choose freely" UX): a
   `rofi -dmenu` list of palettes → `set-theme`, and of wallpapers → `set-wallpaper`
   (two entry points, or one menu that branches). This is the settled trigger;
   a full settings app is a later frontend phase over these same commands.
5. **Handle the reload-heterogeneity** (below) — the trickiest part of a *hot* swap.
6. **Wire the picker to keybinds** (optional) — e.g. bind `pick.sh` to a key, and/or
   a cycle bind. The Control Center / settings-app UI is explicitly **later**.

### Reload-heterogeneity — what actually updates live, and what doesn't

| Surface | Re-theme trigger | Fully live? |
|---|---|---|
| Hyprland borders | auto hot-reload on `colors.lua` write | ✅ instant |
| rofi | re-read on next launch | ✅ (next open) |
| waybar (bar, ws-0 pill, volume glyph) | `killall waybar && waybar &` | ✅ (brief flicker) |
| swaybg wallpaper | `killall swaybg; swaybg -i … &` (via `set-wallpaper`, not `set-theme`) | ✅ (brief flash) |
| **foot terminals** | new colours apply to **new** windows only | ⚠️ **open foot windows keep old colours until reopened** |

The foot caveat is inherent (foot re-reads config only on launch). Options:
accept it (document "reopen terminals to re-theme"), or have `set-theme` not
touch already-open terminals. **Not a blocker; just document it.** Note this also
affects the Control Center placeholder foot windows from phase 6.

---

## Hard constraints (from CLAUDE.md — do not relitigate)

- **Edit only inside `~/dotfiles`.** All live config is symlinked. New files under
  `theme/` need their own symlink into `~/.config` (see 7a step 6) — `~/.config`
  is **per-file / per-dir** symlinked, not a single whole-tree link.
- **Waybar does NOT hot-reload.** Central to both the 7a "did it regenerate?"
  check and the 7b switch (`killall waybar && waybar &`). Hyprland Lua *does*
  hot-reload. rofi and foot re-read on next launch.
- **Don't commit wallpaper changes.** This **collides** with per-theme
  wallpapers — see **Open decision 2**, the most important one in this phase. The
  committed wallpaper line is frozen at Gargantua; do not sweep a wallpaper swap
  into a 7b commit without settling that decision first.
- **Never assume aesthetics.** The *colours of the new palettes* are Sergi's call
  (**Open decision 1**). 7a invents nothing (it reproduces today's values); 7b's
  colours must be confirmed.
- **One logical change per commit.** See Commit breakdown.
- **VM software rendering.** 7a is fully judgeable here (correctness: does
  regeneration reproduce the files, do borders/bar still render). 7b's *mechanism*
  is judgeable here (does a switch propagate to every surface); whether each
  palette actually *looks good* is a real-hardware call (per the
  screenshots-are-aesthetic memory, compare each theme's capture to its intent).

## Decisions (settled — do NOT re-ask)

1. **Black/red is the default palette**, not a fixed theme — it becomes one entry
   in `theme/palettes/`. (Roadmap already reframes the Color-palette section this
   way.)
2. **Whole desktop switches at once**, as a **runtime hot-swap** — no logout.
3. **The switch mechanism comes before any UI.** A Control Center palette-picker
   is later and is *independent* of the mechanism.
4. **7a (consolidation) lands first, on its own**, and changes nothing visible.
   It can be pulled forward as prep (roadmap says so explicitly).
5. **Do not start 7 until phases 4–6 are solid** (they are, per git history) so
   every colored surface exists before the switcher is built.
6. **Theme and wallpaper are independent axes** — choose each freely; wallpaper is
   not a palette field. Live selections are local/gitignored (resolves the old
   Open decision 2). See "Wallpaper is its own axis".
7. **The pick-now UX is a `rofi` menu** (`theme/pick.sh`) — free choice over
   `set-theme` / `set-wallpaper`, reusing the phase-3 launcher (resolves the old
   Open decision 5). A cycle keybind is optional on top.
8. **The settings app is a separate, later frontend phase** — a GUI over these
   same CLIs, **not** part of Phase 7 and not a prerequisite for it. Phase 7's job
   toward it is only to keep the CLIs clean and scriptable.

---

## Commit breakdown (one logical change each)

**7a:**
1. *"Add theme/ palette source + templates for red-black (phase 7)"* — the `.env`,
   the four templates, no behaviour change yet (nothing consumes them).
2. *"Generate waybar/rofi/foot configs from the palette (phase 7)"* — add `gen`;
   the generated files match what's committed (acceptance test).
3. *"Read palette from theme source in colors.lua + volume scripts (phase 7)"* —
   the Lua shim + repointing the two scripts. After this, one palette flows
   end-to-end; desktop still identical.

**7b:**
4. *"Add <name> palette (phase 7)"* — the second palette file (per Open decision 1).
5. *"Add set-theme + set-wallpaper switch commands (phase 7)"* — the two CLIs and
   the `state/` fallbacks; also gitignore `theme/state/` (live selections are
   local). No committed wallpaper line moves.
6. *"Add rofi theme + wallpaper picker (phase 7)"* — `theme/pick.sh`, the
   free-choice UX over the two CLIs.
7. *"Bind the picker to <keybind> (phase 7)"* — optional cycle/launch keybind.

## Verify (don't skip)

- **7a:** `gen` → `git diff` shows the generated configs unchanged → screenshot
  matches a pre-refactor capture (desktop-screenshot workflow is in project
  memory: `grim` via a borrowed `WAYLAND_DISPLAY`, no sudo). Restart waybar to
  see the (identical) bar; confirm Hyprland borders and rofi still render red.
- **7b:** run `set-theme <name>` on the live session; confirm **every colour**
  surface changed — Hyprland border, waybar bar + ws-0 pill + volume glyph, rofi
  window, foot background (in a *newly opened* terminal) — **without** the
  wallpaper moving. Then run `set-wallpaper <img>` and confirm the wallpaper
  changes with the palette **untouched** (the two axes are independent). Drive
  both from `pick.sh` (the rofi menu). Screenshot each theme and compare to its
  intent. Switch back to red-black + the default wallpaper and confirm it returns
  exactly to the 7a baseline.

## Done when

- **7a:** one palette source (`theme/palettes/red-black.env`) drives all seven
  consumers via `gen`; regeneration reproduces the committed files; the desktop
  is visually unchanged; the two scripts and `colors.lua` read from the source.
- **7b:** ≥2 palettes exist; `set-theme <name>` reskins colours across every
  surface (foot caveat documented) and `set-wallpaper <img>` swaps the wallpaper
  **independently**; the `rofi` picker (`pick.sh`) drives both for free choice.
- **Untouched (later):** the **settings app** (its own future frontend phase — the
  roadmap defers it; mechanism only here); any Spicetify/Spotify re-skin (phase 8).

---

## Open decisions still needed (ask Sergi — do NOT invent)

1. **Which palettes?** The concrete colours of the non-default themes — pure
   aesthetics, so Sergi's call. How many, and what colours? *Recommend: start
   with one second palette to prove the hot-swap, then add more.*
2. ✅ **RESOLVED (settled decision 6).** ~~Per-theme wallpapers vs the "don't
   commit" rule.~~ Wallpaper is an **independent axis**, not a palette field; the
   live selection is local/gitignored, so free choice keeps the no-commit rule
   intact. See "Wallpaper is its own axis". *(Kept here, struck, to preserve the
   numbering the rest of the doc references.)*
3. **The 5th colour + `gray` semantics across themes.** Confirm `foreground`
   (today `#ffffff`, inactive ws numbers) and `gray`/`muted` become real palette
   slots that each theme sets — vs. staying fixed white/gray regardless of theme.
   *Recommend: make them per-theme slots.*
4. **Foot foreground/ANSI theming — now or keep background-only?** Today only
   foot's *background* is themed (foreground/ANSI are foot defaults, deliberately
   deferred). Non-red themes will want matching terminal text. Bring foot's full
   palette in during 7b, or keep background-only for now? *Recommend:
   background-only through 7a (identical-output constraint); reconsider a full
   per-theme foot palette in 7b.*
5. ✅ **RESOLVED (settled decision 7).** ~~Switch trigger.~~ A **`rofi` picker**
   (`theme/pick.sh`) over `set-theme` / `set-wallpaper`, reusing the phase-3
   launcher — free choice now, no settings app needed. An optional cycle keybind
   (e.g. `Super+Shift+T`) can sit on top; which key is still yours to pick.
6. **Rename `red`/`red_bright` → `accent`/`accent_bright`/`muted`?** Truthful in a
   multi-theme world, but touches every consumer + `hyprland.lua`. Do it in 7a
   (while touching everything) or keep the red-named fields? *Recommend: rename in
   7a — it's the cheapest moment.*
7. **Generator language** — Python (recommended) vs Bash/`sed`.
8. **Commit the generated configs (A) or gitignore them (B)?** *Recommend A* —
   keeps the clone-and-symlink flow working with no build step.
9. **Palette format** — `key=hex` env (recommended, tri-language readable) vs a
   Lua-table palette (Hyprland-native but opaque to CSS/rasi/scripts).

---

## Kickoff prompt (paste into the new session)

```
Start phase 7 of the Hyprland rice — selectable colour palettes with a runtime
hot-swap. Read CLAUDE.md and docs/phase-7-selectable-palettes.md first.

Do phase 7a ONLY to begin with: the consolidation refactor. It must produce ZERO
visible change — black/red stays pixel-identical. The one job is to make every
colour flow from a single palette source (theme/palettes/red-black.env) through a
generator into all SEVEN consumers the spec inventories (colours.lua, waybar
style.css, waybar config.jsonc's Pango ws-0 line, volume.sh, volume-slider.py,
rofi config.rasi, foot.ini) — NOT the "three files" the roadmap claims. Note the
fifth colour (#ffffff) that isn't in colours.lua today.

Acceptance test for 7a: regenerating reproduces the committed config files
(git diff clean) and a screenshot matches a pre-refactor capture. Remember waybar
doesn't hot-reload (killall waybar && waybar &) but Hyprland does; theme/ needs
its own symlink into ~/.config; edit only inside ~/dotfiles; one logical change
per commit.

Do NOT start 7b (extra palettes + set-theme/set-wallpaper + the rofi picker)
until 7a is solid. Theme and wallpaper are independent axes (settled); the picker
is rofi (settled); the settings app is a separate later phase, not this one.
Before 7b, ask me the remaining "Open decisions still needed" — the palette
colours especially. Don't invent aesthetics.
```
