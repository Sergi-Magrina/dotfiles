# Phase 6 — Control Center (workspace 0)

Spec for a fresh Claude Code session. Roadmap step 6 in
[../CLAUDE.md](../CLAUDE.md). The decisions in the "Decisions (settled with
Sergi)" section below are **settled** — don't re-ask them. The genuinely open
items are collected at the very bottom under "Open decisions still needed."

## Goal
Build the **layout shell** of the Control Center on **workspace 0** (internal
workspace **10**; waybar already relabels it `0`). It is a **floating
dashboard** — every widget is a window pinned to a fixed size/position, with
deliberate empty space and wallpaper showing through between them. This is the
structural opposite of every other workspace, which tiles.

Phase 6 builds the **frame** only. The real widget *contents* (cava, the
calendar/todo apps, the Spotify now-playing widget) are Phase 8 "Deferred"
work, so each zone is filled with a clearly-labeled **placeholder window** now.
See "Phase 6 vs Phase 8 — the boundary" below; it's the most important part of
this spec.

## How it differs structurally from every other workspace
| | Workspaces 1–4 | Workspace 0 (Control Center) |
|---|---|---|
| Layout | `dwindle` tiling — windows auto-fill all space | **Floating**, each window at a **fixed size + position** |
| Empty space | none — tiling expands to fill | **the whole point** — raw wallpaper between panels |
| How windows arrive | opened on demand, routed by class (phase 4) | **auto-spawned on login**, pinned by `cc-*` rules |
| Rule shape | `workspace = "N"` (view follows the app) | `float = true` + `size` + `move` + `workspace = "10 silent"` |

Everywhere else, tiling is what we want. Here it's exactly what we *don't* want —
tiling would pack the panels edge-to-edge and destroy the deliberate negative
space. So every Control Center window is floated and positioned by hand.

## Layout — read off the vision sketch (authoritative)
The layout comes from the user's sketch, `Control Center vision.png` (in this
`docs/` folder, next to this file). **That sketch is authoritative — do not
override it with your own taste.**
Reading it, clockwise:

```
┌───────────────────────── waybar (existing, ~22px) ─────────────────────────┐
│                                     ┌──────────┐ ┌──────────┐               │
│                                     │ calendar │ │ todo list│               │
│      (other jarvis things,          │ (jarvis) │ │ (jarvis) │               │
│        still TBD — left             └──────────┘ └──────────┘               │
│        as EMPTY wallpaper)                                                    │
│                                              ┌───────────────────┐          │
│                                              │  music player     │          │
│  ┌───────────────┐                           │  (spotify):       │          │
│  │  cava         │                           │  song / controls  │          │
│  │  (visualizer) │                           │  / queue of 2     │          │
│  └───────────────┘                           └───────────────────┘          │
└──────────────────────────────────────────────────────────────────────────┘
```

- **cava** (sketch writes "caba") — bottom-left corner. The audio visualizer.
  The **only** terminal/TUI widget (see decision 2).
- **calendar (jarvis)** — upper middle-right.
- **todo list (jarvis)** — upper-right corner.
- **music player / spotify** — bottom-right, the largest panel: current song,
  basic controls (pause/skip), and a queue of the next 2 songs.
- **other jarvis things, still TBD** — the big centre-left region. Undefined in
  the sketch. Phase 6 leaves it **empty** (reserved wallpaper), no window.

> **Divergences from CLAUDE.md's rough zones** (the sketch wins, but flag them):
> CLAUDE.md's step-6 prose sketched "Music/Spotify — top-left", "cava — bottom
> *strip*", plus a "quick-task terminal (ASCII art)" and a "tabbed notepad".
> The sketch instead puts **Spotify bottom-right**, **cava as a bottom-left
> corner box** (not a full-width strip), and shows **neither** the quick-task
> terminal nor the notepad. Following the sketch. See "Open decisions" for the
> notepad/terminal question.

## Phase 6 vs Phase 8 — the boundary (read this twice)
**Phase 6 = the floating frame.** All it produces: unique `cc-*` app-ids, the
window rules that float/size/position them on ws 10, one spawn script, and one
autostart line. Nothing real runs inside the panels yet.

**Every widget in Phase 6 is a PLACEHOLDER** — a terminal window with a unique
app-id that just prints a label and stays open. This works because a window
rule matches on **app-id**, and the terminal can set that app-id to whatever we
pass (verified in phase 4). So the frame is fully testable with zero installs.

**Phase 8 fills the panels.** Each deferred item swaps the placeholder's *launch
command* for the real widget while **keeping the same `cc-*` app-id**, so the
Phase-6 rule keeps matching without edits:

| Zone | Phase-6 placeholder | Phase-8 real widget | Deferred item in CLAUDE.md |
|---|---|---|---|
| cava | `foot --app-id=cc-cava` (label) | `foot --app-id=cc-cava cava` | step 8 "Install + configure cava" |
| calendar | `foot --app-id=cc-calendar` (label) | jarvis-linked calendar app (FastAPI) | step 8 / Jarvis integration |
| todo list | `foot --app-id=cc-todo` (label) | jarvis-linked todo app (FastAPI) | step 8 / Jarvis integration |
| music | `foot --app-id=cc-music` (label) | Spotify now-playing widget | step 8 "Spotify now-playing widget" |
| jarvis TBD | *(none — empty)* | *(undesigned)* | Jarvis integration (last) |

> **Terminal changed since this was written (2026-07-20):** the placeholder
> terminal is now **kitty**, not foot — the VM substitution was reversed on real
> hardware (see `vm-substitutions.md`). kitty spells the app-id **`--class=`**
> where foot spelled it `--app-id=`, so read every `foot --app-id=cc-X` above as
> `kitty --class=cc-X`. The app-id *strings* are unchanged, which is the whole
> point: **not one window rule needed editing.** The design below stands as-is.

> **Why calendar/todo are placeholders, not apps, now (decision 3):** their data
> lives in a live DB behind the browser and is part of the Jarvis build — a full
> day's work on its own. Phase 6 only **reserves the spot**. When the real app
> exists it's a GUI app (not a TUI), so on first launch read its real class with
> `hyprctl clients | grep -iE 'class|initialClass'` and either make it set
> `app_id = cc-calendar` / `cc-todo`, or update that rule's `match` to the real
> class — same "verify class on first launch" caveat as phase 4.

## Read first
- `CLAUDE.md` — project brief, working conventions, VM constraints (auto-loaded,
  but read it).
- `docs/Control Center vision.png` — the authoritative layout sketch.
- `hypr/hyprland.lua` — where everything goes. The phase-4 workspace rules are at
  the **bottom** under `WINDOWS AND WORKSPACES` (the `ws-browser` rule is the
  last one, ~line 417); the CC rules append right after it. The
  `hl.on("hyprland.start", …)` autostart block is ~line 60. The `Super + [0-9]`
  workspace loop is ~line 299. The `foot --app-id=yazi yazi` idiom is ~line 41.
- `hypr/colors.lua` — the red/black palette, single source of truth. The Control
  Center must reference these (it does so for free — see "Borders" below).
- `docs/phase-4-workspace-assignments.md` — the `--app-id` test-harness trick and
  the window-rule idiom this phase reuses.
- `vm-substitutions.md` — foot (not kitty), swaybg (not hyprpaper); cava is a
  Phase-8 install, so it isn't here yet.
- `/usr/share/hypr/stubs/hl.meta.lua` — ground-truth Lua API for Hyprland 0.55.4.
  `hl.window_rule` takes `match` + rule keys; `move` is already proven in the
  `move-hyprland-run` rule, and `size` / `workspace = "N silent"` are its
  companions.

## Hard constraints (from CLAUDE.md — do not relitigate)
- **Lua config, hot-reload.** Edit `hypr/hyprland.lua`; Hyprland reloads on save.
  Tight loop for tuning positions. **Waybar does NOT hot-reload** — but Phase 6
  needs **no waybar change** (the `0` pill already exists), so this won't come up.
- **Symlink discipline — and note the wrinkle.** `~/.config/hypr` is **not** a
  whole-directory symlink; it's a real dir with **per-file** symlinks
  (`hyprland.lua`, `colors.lua`, `wallpapers` each linked individually). So a
  **new** file under `hypr/` is **not** auto-covered — it needs its own symlink.
  The spawn script (below) therefore requires an explicit
  `ln -s ~/dotfiles/hypr/scripts ~/.config/hypr/scripts` (a dir symlink, mirroring
  how `waybar/scripts` is already linked). Edit only inside `~/dotfiles`.
- **Never assume aesthetics.** Sizes/positions here are read off the sketch and
  are *starting values to eyeball live*, not final pixel law. Anything the sketch
  doesn't pin down is in "Open decisions", not invented.
- **Don't commit wallpaper changes.** Phase 6 doesn't touch the wallpaper.
- **One logical change per commit.** See "Commit breakdown".
- **VM software rendering.** Judge **structure/correctness** here — do the
  windows float on ws 0? do they land in the right zone at the right relative
  size? does the login view stay on ws 1? Final **aesthetic** sizing/spacing is a
  real-hardware call.

## Decisions (settled with Sergi — do NOT re-ask)
1. **Positioning model = percentages.** Use `%` `size`/`move` strings so the
   layout survives the move to real hardware without a rewrite. If a particular
   `%` placement proves impossible/awkward, fixed pixels are an acceptable
   fallback (with the understanding it'll be redone off-VM).
2. **Only cava is foot/TUI.** cava runs in a `foot` window. The calendar, todo,
   and music widgets are standalone apps, not TUIs.
3. **Calendar + todo = apps built with Jarvis, reserved now.** They read a live
   DB behind the browser; implementing them is part of the Jarvis day-of-work.
   Phase 6 reserves their spots with placeholders (or a dummy) only.
4. **Borders first, borderless maybe later.** Start with borders/rounding; may
   switch to borderless if it looks better. (Phase 6 gets borders *for free* —
   see below — so this needs no extra rule now.)
5. **Auto-spawn on login.** The widgets launch on login, not on demand. (On real
   hardware most things — Spotify, Jarvis connections — will be auto-launched at
   setup too.)

## Borders / rounding — nothing to add
The global config (`hypr/hyprland.lua`, `general` + `decoration`) already gives
**every** window a 2px red gradient border (`colors.red` → `colors.red_bright`)
and `rounding = 10`. Floating windows inherit both. So the Control Center panels
get the red bordered, rounded look **automatically**, satisfying decision 4 with
zero extra config and referencing `colors.lua` transitively (no hardcoded hex).

To go borderless later, add `no_border = true` (and `rounding = 0`) to an
individual `cc-*` rule — a one-line, per-panel switch. Don't do it now.

## The per-widget frame (Phase 6)
Percentages are of the monitor, origin top-left. Read off the sketch; **tune
live**. Border/rounding is "inherited" (global) for all of them.

| Widget | app-id | Phase-6 launch (placeholder) | size (`w% h%`) | move (`x% y%`) | Border/round | Real or placeholder |
|---|---|---|---|---|---|---|
| cava (visualizer) | `cc-cava` | `foot --app-id=cc-cava …label…` | `30% 15%` | `3% 82%` | inherited | **Placeholder** → cava (P8) |
| calendar (jarvis) | `cc-calendar` | `foot --app-id=cc-calendar …label…` | `26% 34%` | `56% 6%` | inherited | **Placeholder** → app (P8) |
| todo list (jarvis) | `cc-todo` | `foot --app-id=cc-todo …label…` | `16% 34%` | `83% 6%` | inherited | **Placeholder** → app (P8) |
| music (spotify) | `cc-music` | `foot --app-id=cc-music …label…` | `31% 33%` | `66% 60%` | inherited | **Placeholder** → widget (P8) |
| other jarvis (TBD) | — | *(none — reserved empty space)* | — | — | — | **Empty** (undesigned) |

> Calendar/todo widths re-split 2026-07-11 (Sergi): calendar wider than todo
> (~1.6:1, matching the sketch), same height. Originally `20%`/`22%`.

> `6%` top-row `y` clears the 22px waybar comfortably on 1080p (~65px). If a
> top-row panel tucks under the bar on the real monitor, nudge `y` up a couple
> of points — verifiable live.

## The Hyprland window rules (in the existing Lua idiom)
Append these to `hypr/hyprland.lua` at the **end of the `WINDOWS AND
WORKSPACES` section**, immediately after the phase-4 `ws-browser` rule (the last
rule in the file, ~line 421). Written longhand to match the surrounding phase-4
rules — same `hl.window_rule({ name, match, … })` shape as everywhere else.

```lua
-- ─── Control Center (phase 6) ────────────────────────────────────────────────
-- Workspace 0 (internal 10; waybar relabels it "0") is a FLOATING dashboard —
-- the deliberate opposite of the dwindle tiling every other workspace uses.
-- Each widget is its own window with a unique `cc-*` app-id (set via
-- `foot --app-id=`); the rule floats it at a fixed %-size / %-position and drops
-- it on ws 10 *silently* — so the login view stays on ws 1, not ws 0.
--
-- Borders + rounding are INHERITED from the global general/decoration config
-- (red border, rounding 10), matching the "borders first" decision. To make a
-- panel borderless later, add `no_border = true` (and `rounding = 0`) to it.
--
-- PHASE-6 = frame only: every window here is a PLACEHOLDER foot terminal (see
-- scripts/control-center.sh). PHASE-8 swaps each launch command for the real
-- widget (cava; calendar/todo apps; Spotify now-playing) but keeps the same
-- `cc-*` app-id so these rules keep matching. The "other jarvis (TBD)" zone is
-- intentionally left EMPTY — raw wallpaper — until it's designed.
--
-- Sizes/positions are read off docs/Control Center vision.png; eyeball-tune
-- them live (structure is checkable in the VM; final sizing is a hardware call).

hl.window_rule({
    name      = "cc-cava",                  -- bottom-left: audio visualizer
    match     = { class = "^cc-cava$" },
    float     = true,
    size      = "30% 15%",
    move      = "3% 82%",
    workspace = "10 silent",
})

hl.window_rule({
    name      = "cc-calendar",              -- upper middle-right: calendar (jarvis)
    match     = { class = "^cc-calendar$" },
    float     = true,
    size      = "20% 34%",
    move      = "56% 6%",
    workspace = "10 silent",
})

hl.window_rule({
    name      = "cc-todo",                  -- upper-right: todo list (jarvis)
    match     = { class = "^cc-todo$" },
    float     = true,
    size      = "22% 34%",
    move      = "77% 6%",
    workspace = "10 silent",
})

hl.window_rule({
    name      = "cc-music",                 -- bottom-right: Spotify now-playing
    match     = { class = "^cc-music$" },
    float     = true,
    size      = "31% 33%",
    move      = "66% 60%",
    workspace = "10 silent",
})
```

**Confirm on first hot-reload** (5-second checks, same spirit as phase 4):
- `size`/`move` accept the `%` strings and the panels land where the table says.
  If `%` on `size`/`move` misbehaves on this Hyprland build, fall back to pixel
  values (decision 1 allows it) — e.g. `size = "560 160"`, `move = "40 900"`.
- `workspace = "10 silent"` keeps the windows on ws 0 **without** yanking the
  login view off ws 1. (If a placeholder still steals focus at spawn, that's the
  thing to note.)

## Spawn mechanism + new files + symlinks
**Auto-spawn on login (decision 5)** via one new script, called from autostart.
The window rules do the floating/placing; the script only *opens* the windows
with the right app-ids.

### New file — `hypr/scripts/control-center.sh`
```sh
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
```
Make it executable: `chmod +x ~/dotfiles/hypr/scripts/control-center.sh`.

> Placeholder foot windows inherit foot's now-transparent background (alpha
> 0.85, committed earlier), so they'll read as semi-transparent red-bordered
> black panels with wallpaper behind — already on-theme, nothing to style.

### Symlink (required — `hypr` is per-file linked, not a whole-dir link)
```bash
ln -s ~/dotfiles/hypr/scripts ~/.config/hypr/scripts
```
This mirrors the existing `~/.config/waybar/scripts -> ~/dotfiles/waybar/scripts`
dir symlink. Without it, `~/.config/hypr/scripts/control-center.sh` won't exist
and the autostart line silently does nothing.

### Autostart line — `hypr/hyprland.lua`, in the `hyprland.start` block (~line 60)
Add after the `swaybg` line, before `VBoxClient`:
```lua
    -- Control Center (phase 6): spawn the ws-0 placeholder widgets on login.
    -- The cc-* rules float them onto ws 10 silently, so we stay on ws 1.
    -- Phase 8 replaces the placeholders inside this script (same app-ids).
    hl.exec_cmd("~/.config/hypr/scripts/control-center.sh")
```
(`~` expansion is fine here — the existing `swaybg` line uses the same idiom.)

## Entering / leaving workspace 0 (verified against current keybinds)
**No new keybind is needed.** The `Super + [0-9]` loop in `hyprland.lua`
(~line 299) is:
```lua
for i = 1, 10 do
    local key = i % 10                       -- i=10 → key 0
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i}))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end
```
So at `i = 10`, `key = 10 % 10 = 0`:
- **`Super + 0`** → `focus({ workspace = 10 })` → **enters the Control Center.**
- **`Super + Shift + 0`** → moves the active window to ws 10.

**Leave** with any of the existing binds: `Super + 1..4` (jump to another
workspace), `Super + scroll` (`e+1` / `e-1`, ~line 310), or the **3-finger
horizontal gesture** (~line 260). Clicking the red **`0`** pill in waybar also
activates it (`on-click: activate`). All pre-existing — Phase 6 adds none.

## Commit breakdown (one logical change each)
1. **Add the Control Center floating window rules** — the four `cc-*`
   `hl.window_rule` blocks in `hyprland.lua`. Inert on their own (nothing spawns
   yet). Commit: *"Add Control Center floating window rules on ws 0 (phase 6)"*.
2. **Add the placeholder spawn script** — new `hypr/scripts/control-center.sh`
   (+ `chmod +x`; create the `~/.config/hypr/scripts` symlink locally). Still
   inert — nothing calls it. Commit: *"Add Control Center placeholder spawn
   script (phase 6)"*.
3. **Wire the spawner into autostart** — the one `hl.exec_cmd(…)` line in the
   `hyprland.start` block. This is the switch that turns it on. Commit:
   *"Auto-spawn Control Center widgets on login (phase 6)"*.

(1 → 2 → 3 mirrors phase 4's "inert config first, then flip it on". Each commit
leaves the repo working: rules inert, then script present-but-uncalled, then
active. Commits 2 and 3 could merge if you prefer, but keeping them apart lets
you land the script and eyeball it via `Super+0` + a manual run before autostart
makes it every-login.)

## Verify (don't skip)
- After commit 1, hot-reload and manually run
  `foot --app-id=cc-cava -e sleep 30` (and the other three app-ids) from another
  workspace — each should appear **floating** on ws 0 at its zone/size, **without
  pulling the view** off your current workspace (`silent`). Check placement/size
  with `hyprctl clients` and by pressing `Super+0`.
- After commit 2, run `~/.config/hypr/scripts/control-center.sh` by hand: all
  four placeholders appear on ws 0 in the sketch's arrangement, each labelled.
- After commit 3, **log out and back in** (or restart Hyprland): the four
  placeholders auto-appear on ws 0, and the **login view stays on ws 1** (empty
  desktop). `Super+0` reveals the populated Control Center.
- **Screenshot ws 0** — desktop-screenshot workflow is in this project's memory
  (`grim` via a borrowed `WAYLAND_DISPLAY`, no sudo). Compare against the sketch:
  right zones, roughly right relative sizes, real empty space in the centre-left.
- **VM caveat:** structure/placement/floating/silent-login are all checkable
  here. Whether the sizes/gaps *look* balanced is a real-hardware judgment — set
  starting values now, refine in the showroom.

## Done when
- The four `cc-*` floating rules are in `hyprland.lua`, verified to float their
  windows onto ws 0 at the sketch's zones without stealing the login view.
- `hypr/scripts/control-center.sh` exists, is executable, is symlinked into
  `~/.config/hypr/scripts`, and spawns the four labelled placeholders.
- The autostart line spawns them on login; ws 1 stays the empty desktop on login.
- `Super+0` enters a populated Control Center; the centre-left "TBD" zone is
  deliberately empty wallpaper.
- Committed in the three logical chunks above.
- **Untouched (Phase 8 / later):** installing/configuring cava, the calendar/todo
  apps, the Spotify now-playing widget, ASCII art, and all Jarvis integration.
  Phase 6 only reserved their spots.

## Open decisions still needed (ask Sergi — do NOT invent)
The sketch + settled decisions cover the frame, but these are genuinely
ambiguous. Confirm before/while building; don't guess aesthetics.

1. **The "other jarvis things (TBD)" zone.** Phase 6 leaves it **empty
   wallpaper** (no window). Confirm that's right for now — or does Sergi want a
   labelled placeholder box there too (a fifth `cc-*` window), so the zone is
   visibly reserved rather than blank?
2. **Notepad + quick-task terminal — dropped, moved, or folded in?** CLAUDE.md's
   step-6 prose lists a *tabbed notepad* and a *quick-task terminal with ASCII
   art*; the vision sketch shows **neither**. Are they (a) dropped, (b) folded
   into the "other jarvis (TBD)" zone, or (c) still wanted somewhere the sketch
   doesn't show? This changes how many `cc-*` zones exist.
3. **Exact sizes/positions.** The `%` values in the tables are my read of the
   sketch and *will* need eyeballing on the live session. Fine to start with them
   and tune, but confirm Sergi wants me to set starting values vs. wanting to
   dictate specific ones. (Not blocking — just don't treat my numbers as final.)
4. **Placeholder look.** Is a plain labelled foot terminal enough for the Phase-6
   placeholders, or does Sergi want them styled/ASCII'd now? (Default: plain
   label — real styling comes with the real widgets in Phase 8.)
5. **cava shape — corner box vs strip.** The sketch shows cava as a bottom-left
   **corner box**; CLAUDE.md said "bottom *strip*". Spec follows the sketch
   (box). Confirm that's the intent, or widen it toward a full-width strip.

---

## Kickoff prompt (paste into the new session)
```
Start phase 6 of the Hyprland rice — the Control Center (workspace 0). Read
CLAUDE.md and docs/phase-6-control-center.md first, then work through that spec.
Also open docs/Control Center vision.png — it's the authoritative
layout and must not be overridden with your own taste. The "Decisions (settled
with Sergi)" section is settled — don't re-ask it.

Goal: build the FLOATING dashboard frame on ws 0 (internal 10; waybar already
shows "0"). Every widget is its own foot window with a unique cc-* app-id, pinned
by a window rule (float + fixed %-size + %-position + workspace "10 silent") in
hyprland.lua, and auto-spawned on login by a new hypr/scripts/control-center.sh.
This phase builds the SHELL only: every panel is a labelled PLACEHOLDER — the
real cava / calendar / todo / Spotify widgets are Phase 8. Leave the centre-left
"other jarvis (TBD)" zone as empty wallpaper.

Remember: ~/.config/hypr is per-file symlinked, so the new scripts dir needs its
own `ln -s ~/dotfiles/hypr/scripts ~/.config/hypr/scripts`. Borders come free
from the global config (borders-first decision). Super+0 already enters ws 0 — no
new keybind. One logical change per commit (rules → script → autostart). Verify
live with a screenshot of ws 0 and compare to the sketch. Before building, ask me
the items under "Open decisions still needed" — don't invent aesthetics.
```
