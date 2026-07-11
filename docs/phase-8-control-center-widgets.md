# Phase 8 — Control Center widgets (fill the placeholders) + deferred bucket

Spec for a fresh Claude Code session. Roadmap step 8 ("Deferred / later work") in
[../CLAUDE.md](../CLAUDE.md). Phase 6 built the Control Center **frame** — four
floating `cc-*` placeholder windows on workspace 0. **Phase 8 fills them with the
real widgets**, plus the two client-side items in the deferred bucket (Spicetify;
Jarvis). It does *not* invent new layout — the frame, sizes, and positions are
already settled in [phase-6-control-center.md](phase-6-control-center.md).

The **Decisions (settled)** section is settled — don't re-ask it. The genuinely
open items (mostly toolkit + aesthetics) are collected at the bottom under **Open
decisions still needed** — ask Sergi before building those, don't invent.

> **This is a grab-bag phase, not one feature.** Unlike phases 6/7, step 8 is a
> *list* of loosely-related deferred items at very different readiness levels.
> This spec partitions them into **buildable now**, **gated on Jarvis**, and
> **gated on real hardware** — read "The map" first; it's the most important part.

---

## The map — what's actually buildable, and what's blocked

| Sub-phase | Zone / target | Placeholder today | Status | Blocked on |
|---|---|---|---|---|
| **8a — cava** | `cc-cava` | labelled foot | ✅ **buildable now** (VM-testable) | package install only |
| **8b — Spotify now-playing widget** | `cc-music` | labelled foot | 🟡 **mechanism buildable now** | toolkit decision; "queue of 2" needs more than MPRIS |
| **8c — Spicetify (re-skin the Spotify *client*)** | ws-4 Spotify app | (not a CC panel) | 🔴 **likely real-hardware only** | Spotify (Electron) running in the VM |
| calendar / todo | `cc-calendar`, `cc-todo` | labelled foot | ⛔ **out of scope** | Jarvis (apps read a live DB — the Jarvis build) |
| "other jarvis (TBD)" zone | centre-left empty | *(none)* | ⛔ **undesigned** | Jarvis / a layout decision |
| ASCII-art quick-task terminal | — | *(does not exist)* | ⛔ **blocked on a layout decision** | phase-6 Open decision 2 (the terminal was dropped from the sketch) |
| Jarvis integration + its two terminal panes | — | — | ⛔ **last, explicitly out of scope** | the whole Jarvis project |

**So the real phase-8 work you can start today is 8a and 8b.** 8c is a
real-hardware task you *prepare* for (verify Spotify even launches) but likely
can't finish in the VM. Everything else is gated on Jarvis or on a layout
decision that isn't yours to make — do **not** build them speculatively.

---

## The Phase-6 → Phase-8 contract (read this; it's the whole mechanism)

Phase 6 deliberately made this phase cheap. Every Control Center panel is a
`foot` window with a unique **`cc-*` app-id**, and the floating/sizing/placement
lives in a `hyprland.lua` window rule that **matches on that app-id**. Phase 8
swaps only the *launch command* inside
[../hypr/scripts/control-center.sh](../hypr/scripts/control-center.sh),
**keeping the same app-id**, so the phase-6 rule keeps matching with **zero
changes to `hyprland.lua`**:

```sh
# phase 6 (placeholder):
place cc-cava  "cava — audio visualizer"       # foot showing a label, held open

# phase 8 (real widget) — SAME app-id, so the cc-cava float rule still matches:
foot --app-id=cc-cava cava &
```

That's the contract. `size`/`move`/`float`/`workspace = "10 silent"` are already
correct from phase 6; you're only changing *what runs inside the window*. If a
real widget is a GUI (not a TUI in foot), it sets its own class — read it live
with `hyprctl clients | grep -iE 'class|initialClass'` and either make the app
set `app_id = cc-music` or repoint that one rule's `match` (same "verify class on
first launch" caveat phases 4 and 6 already use).

---

## The new constraint phase 6 didn't have: everything must be a palette consumer

Phase 6 predated phase 7. **Phase 7 now exists** — the whole desktop hot-swaps
between palettes (`theme/palettes/*.env` → `theme/gen.py` → every colored
surface; `set-theme <name>` reskins the live session). CLAUDE.md's phase-7 goal
is *"the whole desktop + all workspaces at once."* **Workspace 0 is part of the
desktop.** So any phase-8 widget with colour must plug into the palette, or it
becomes a dead patch that ignores theme switches — the one thing phase 7 was
built to prevent.

Phase 7 already established **two integration styles**. Reuse them; invent no
third:

| Style | How | Phase-7 precedent | Phase-8 users |
|---|---|---|---|
| **Runtime-read** | the program `source`s / reads `theme/colors.env` (`KEY='#hex'`) at launch and builds its own colours | [../waybar/scripts/volume.sh](../waybar/scripts/volume.sh), [../waybar/scripts/volume-slider.py](../waybar/scripts/volume-slider.py) | the Spotify widget (if it's a script/GTK app) |
| **Templated** | add a `theme/templates/<x>.in` with `{{placeholders}}`; wire it into `gen.py`'s `TEMPLATES` map; `gen` renders the real (symlinked) config | `style.css.in`, `config.rasi.in`, `foot.ini.in`, `config.jsonc.in` | **cava's `config`**, and (if in scope) **Spicetify's `color.ini`** |

`theme/gen.py`'s `TEMPLATES` dict ([../theme/gen.py](../theme/gen.py), ~line 42)
maps each `*.in` to the file it writes — adding a consumer is one line there plus
the template. The palette slots available are exactly:
`background`, `accent`, `accent_bright`, `muted`, `foreground` (+ the non-colour
knob `foot_alpha`). Same five every palette defines — see
[../theme/palettes/red-black.env](../theme/palettes/red-black.env).

### Phase 8 extends phase 7's reload-heterogeneity table

Phase 7 documented which surfaces update live on `set-theme`. Phase 8 adds rows —
and `set-theme.sh` must learn to reload the new ones (or they'll only re-theme on
next launch, like the existing foot caveat):

| New surface | Re-theme trigger on `set-theme` | Fully live? |
|---|---|---|
| **cava** (`cc-cava`) | `gen` rewrites `~/.config/cava/config`; cava re-reads on **restart** (respawn the `cc-cava` foot window). An in-app reload exists (`r` key); whether a *signal* (e.g. `SIGUSR1/2`) reloads it scriptably is **verify-live** | ⚠️ respawn to re-theme (mirrors the foot caveat) |
| **Spotify widget** (`cc-music`) | if runtime-read: it re-reads `colors.env` on **restart**; if it long-runs, it needs a reload path or a respawn | ⚠️ likely respawn |
| **Spicetify** (Spotify client) | `spicetify apply` **patches the client and restarts Spotify** — heavy. Almost certainly **not** part of the live loop | 🔴 manual re-apply, not hot-swap (Open decision) |

Practical upshot: `set-theme.sh` should, after `gen`, **respawn the Control
Center** (re-run `control-center.sh` after killing the `cc-*` windows) so cava
and the music widget pick up the new palette — the same "it doesn't hot-reload,
so restart it" pattern as waybar. Spicetify stays *out* of the live loop.

---

## Install reality: Claude can't `pacman`, and some of this won't run in the VM

- **Claude cannot run `sudo`/`pacman`** (project memory: the desktop-screenshot
  workflow note). So **every install is Sergi's action** — cava, `playerctl`,
  the Spotify client, `spicetify-cli`. This spec says *what* to install and
  *how to wire the config*; Sergi runs the install, Claude writes the dotfiles.
- **VM software rendering gates the client-side items** (same root cause as
  kitty/hyprpaper — see [../vm-substitutions.md](../vm-substitutions.md)):
  - **cava** renders in a terminal (CPU/ncurses) → **works in the VM.** It needs
    an audio *monitor* source; the existing volume widget proves PipeWire is up,
    but a loopback/monitor source is **verify-live** (no source → cava draws a
    flat line; the *widget structure* is still testable).
  - **Spotify (Electron)** is the same GPU class as kitty. It may fail to launch
    or need `--disable-gpu`. **Verify it runs at all before 8c.** If it doesn't,
    add a row to `vm-substitutions.md` and defer 8c (and any real Spotify
    routing test) to the showroom.
  - **The now-playing *widget* dodges this** by reading **MPRIS via `playerctl`**,
    which works against *any* player — so develop/test its mechanism against
    **Firefox** (already on ws-3, native Wayland, works in the VM) playing
    anything. The mechanism is VM-testable even though the real Spotify client
    isn't. (Classic phase-7 split: mechanism here, final integration on hardware.)

---

## 8a — cava (the audio visualizer, `cc-cava`)

The smallest, cleanest win: a TUI in a foot window, fully VM-testable, a pure
palette-consumer add. Do this **first**.

**Steps:**
1. **Sergi installs cava** (`cava`, in the Arch `extra` repo) — Claude can't.
2. **Swap the placeholder** in `control-center.sh`: the `place cc-cava …` line
   becomes `foot --app-id=cc-cava cava &`. Same app-id → the phase-6 `cc-cava`
   float rule (`hyprland.lua`, `size = "30% 15%"`, `move = "3% 82%"`) still
   matches, no `hyprland.lua` edit.
3. **Make cava a palette consumer (templated style):**
   - Add `theme/templates/cava.config.in` — a cava config whose `[color]` section
     uses `{{placeholders}}`. Proposed mapping (confirm the exact look live):
     - `background = 'default'` — inherit foot's **transparent** themed background
       so cava reads as wallpaper-behind, like the other CC panels (no
       placeholder needed — it's the literal string `default`).
     - `foreground = '{{accent}}'` — bars in the accent colour.
     - Optionally a gradient `accent → accent_bright` (`gradient = 1`,
       `gradient_color_1 = '{{accent}}'`, `gradient_color_2 = '{{accent_bright}}'`)
       for a themed fade up each bar. **Aesthetic — confirm (Open decision 3).**
   - Wire it into `theme/gen.py`'s `TEMPLATES` map: one line,
     `"cava.config.in": Path.home()/".config"/"cava"/"config"` — **but** prefer
     rendering into the repo and symlinking (below) to keep the edit-in-dotfiles
     rule. So map it to `REPO / "cava" / "config"` and symlink that into place.
4. **Symlink** (`~/.config` is per-file/per-dir linked — a new file isn't
   auto-covered): create `cava/config` in the repo and
   `ln -s ~/dotfiles/cava/config ~/.config/cava/config` (mirrors how
   `waybar/scripts`, `hypr/scripts`, `rofi`, `foot` are each linked). cava reads
   `~/.config/cava/config`.
5. **Teach `set-theme.sh` to re-theme cava** — after `gen`, respawn the `cc-cava`
   window (or send cava's reload if a scriptable signal is verified). See the
   reload table above; respawn is the guaranteed path.

**cava-specific notes:**
- `[input] method` — leave cava's autodetect (it finds PipeWire/Pulse). If it
  shows a flat line in the VM, the fix is an audio **monitor** source, not a cava
  bug — verify live; it's a VM-audio question, not a phase blocker.
- cava is `cc-cava`'s *only* content — the phase-6 sketch made cava the sole TUI
  widget (settled decision 2 there).

**VM verdict:** structure + theming fully judgeable here (does cava fill the
`cc-cava` panel, in accent colour, transparent background, re-theming on
`set-theme`). Whether the bars actually *dance* depends on a live audio source —
verify, but don't block the phase on it.

---

## 8b — Spotify now-playing widget (`cc-music`)

The phase-6 sketch's `cc-music` panel: **current song, basic controls
(pause/skip), and a queue of the next 2 songs.** Two hard questions gate this —
the **toolkit** and the **"queue of 2" data source** — both flagged as open
decisions; do **not** invent either.

### Data source (settled direction): `playerctl` / MPRIS

`playerctl` reads now-playing metadata (title/artist/art/status) from **any**
MPRIS player and sends `play-pause` / `next` / `previous`. This is the right
spine because:
- It **decouples the widget from Spotify** — same widget works with Spotify on
  hardware and with **Firefox** in the VM, so the mechanism is VM-testable.
- Controls (pause/skip) map directly to `playerctl` verbs.
- Sergi installs `playerctl` (Arch `extra`).

**The catch — the "queue of 2" is not in MPRIS.** `playerctl`/MPRIS exposes the
*current* track only; Spotify's **upcoming queue is not available over MPRIS**.
Showing "the next 2 songs" needs the **Spotify Web API** (an OAuth app + token +
network calls) or `librespot` — materially more scope and credentials. So the
"queue of 2" is **Open decision 2**: either
- **(A, recommended for the first cut)** drop the queue — ship
  song + art + pause/skip (all pure `playerctl`), revisit the queue later; or
- **(B)** add Spotify-Web-API integration for the queue — bigger, needs auth,
  and only works with the real Spotify client (not the VM's Firefox stand-in).

### Toolkit (Open decision 1 — ask; don't invent)

| Option | Shape | Themes via | Pros | Cons |
|---|---|---|---|---|
| **(A) TUI in foot** | a shell/python loop rendering text in the `cc-music` foot window | foot's themed bg + `colors.env` ANSI (runtime-read) | cheapest; on-theme for free; VM-native; matches cava's foot pattern | clicks/controls in a terminal are clumsy (keybinds, not buttons); no album art |
| **(B) GTK widget (recommended)** | a Python GTK window (real buttons, album art) | **runtime-read `colors.env` → build GTK CSS** — *exactly what `volume-slider.py` already does* | proper controls + art; **direct precedent in the repo**; palette-consumer for free | more code; sets its own class → repoint the `cc-music` rule's `match` (verify-live) |
| **(C) eww** | a declarative widget (eww bar/window) | eww's own scss (would need a `.in` template) | powerful if the Control Center grows many widgets; phase-9 already floats eww/quickshell | a **new dependency** + its own config language for one widget; heavier |

**Recommendation: (B) GTK**, because
[../waybar/scripts/volume-slider.py](../waybar/scripts/volume-slider.py) is
already a themed GTK-in-Python widget reading `theme/colors.env` — the Spotify
widget is the same pattern with `playerctl` as its data source, so it's a
palette consumer with no new machinery. But this is **Sergi's call** — confirm
before building.

**Wherever it lives:** a new script under
[../hypr/scripts/](../hypr/scripts/) (e.g. `hypr/scripts/cc-music.py`), reusing
the **existing** `~/.config/hypr/scripts` symlink (from phase 6) — no new symlink
needed. `control-center.sh`'s `place cc-music …` line becomes the launch of that
script.

**VM verdict:** the whole *mechanism* (metadata display + pause/skip driving
`playerctl`) is testable against Firefox in the VM. Whether it looks good, album
art rendering, and the real Spotify hookup are hardware calls.

---

## 8c — Spicetify (re-skin the Spotify *client* — separate from 8b)

This is **not** the now-playing widget; it re-skins the actual Spotify desktop
app to the palette. CLAUDE.md gates it: *"needs Spotify installed and its ws-4
routing rule verified first; this is the client re-skin, separate from the
now-playing widget above."*

**Prerequisites (all Sergi-side, mostly real-hardware):**
1. **Spotify installed and actually launching.** In the VM it's an Electron app
   on a software GPU — **verify it runs** (maybe only with `--disable-gpu`). If
   it won't, 8c is a **showroom task** — record it in `vm-substitutions.md` and
   stop here for the VM.
2. **Verify the ws-4 routing rule.** The phase-4 `ws-spotify` rule
   ([../hypr/hyprland.lua](../hypr/hyprland.lua), ~line 414) matches
   `^(spotify|Spotify)$` with a *"verify on first launch (likely XWayland
   Spotify)"* caveat — confirm the real class once Spotify runs, repoint if
   needed.
3. **`spicetify-cli`** (AUR) installed; it needs write access to the Spotify
   install and runs `spicetify backup apply`.

**Palette integration + the hot-swap question (Open decision 4):** Spicetify's
colours live in a `color.ini`. It *could* be a `gen.py` template
(`theme/templates/spicetify-color.ini.in` → the Spicetify config), making the
Spotify client a palette consumer. **But** applying it (`spicetify apply`)
**patches the client's files and restarts Spotify** — far too heavy for the live
`set-theme` loop. **Recommendation:** generate the `color.ini` from the active
palette, but **re-apply Spicetify manually** (a documented step or a `--spicetify`
flag on `set-theme`), *not* automatically on every theme switch. Confirm.

**Maintenance note (real hardware):** Spotify auto-updates routinely break
Spicetify and require `spicetify apply` again — a showroom upkeep item, worth a
line in the eventual docs.

**VM verdict:** almost certainly **not completable in the VM.** Treat 8c as
*prepare + defer*: get the `color.ini` template ready (judgeable as text), but
the actual apply/verify is a hardware task.

---

## Out of scope for phase 8 (gated — do NOT build speculatively)

These are in the deferred bucket but blocked; building them now would be inventing
against unresolved decisions:

- **calendar (`cc-calendar`) + todo (`cc-todo`).** Phase-6 settled decision 3:
  they're **apps built with Jarvis** that read a live DB behind the browser —
  part of the Jarvis build, not standalone widgets. Phase 6 *reserved* their
  spots; phase 8 leaves the placeholders until Jarvis exists. When the real apps
  land they're GUIs → set `app_id = cc-calendar`/`cc-todo` or repoint those rules
  (verify class live), exactly as phase 6 documented.
- **The centre-left "other jarvis (TBD)" zone.** Undesigned; stays empty
  wallpaper (phase-6 Open decision 1 was to leave it blank). Needs a layout
  decision before anything goes there.
- **The ASCII-art quick-task terminal.** CLAUDE.md step 8 lists "ASCII art for
  the quick-task terminal" — but **that terminal was dropped from the phase-6
  vision sketch** and is still unresolved (**phase-6 Open decision 2**: dropped /
  folded into the TBD zone / wanted elsewhere). You cannot make ASCII art for a
  widget that isn't in the layout. **Resolve phase-6 Open decision 2 first** — if
  Sergi still wants the terminal, that's a small layout addition (a new `cc-*`
  zone) *before* the ASCII art, and both are their own follow-up, not part of the
  8a/8b core.
- **Jarvis integration + its two terminal panes** (live-actions pane +
  memory/context pane). CLAUDE.md is explicit: Jarvis comes **last**, "out of
  scope until called for directly," once the Control Center shell is proven. Not
  this phase.

---

## Hard constraints (from CLAUDE.md — do not relitigate)

- **Keep the `cc-*` app-ids.** The phase-6 window rules match on them; phase 8
  swaps launch commands only. Don't touch the float/size/move rules in
  `hyprland.lua` unless a GUI widget forces a `match` repoint (verify class live).
- **Every colored widget is a palette consumer.** Runtime-read `colors.env` or
  add a `gen.py` template — never hardcode hex. Phase 7 exists to reskin the
  *whole* desktop, ws 0 included; a widget that ignores the palette is a bug.
- **Edit only inside `~/dotfiles`; symlink new files.** `~/.config` is
  per-file/per-dir linked. cava's `config` needs its own symlink; the music
  widget reuses the existing `~/.config/hypr/scripts` link.
- **Waybar doesn't hot-reload; cava/foot/the widget re-read on restart.** The
  `set-theme` respawn pattern covers ws-0 widgets.
- **Claude can't install packages.** cava, `playerctl`, Spotify, `spicetify-cli`
  are Sergi's `pacman`/AUR actions. Claude wires the config around them.
- **Never assume aesthetics.** cava's gradient/colours, the widget's toolkit and
  layout, whether the queue exists — all Sergi's call (Open decisions below).
- **Don't commit wallpaper changes.** Phase 8 doesn't touch the wallpaper axis.
- **One logical change per commit.** See Commit breakdown.
- **VM software rendering.** 8a fully judgeable here; 8b's *mechanism* judgeable
  (via Firefox/MPRIS); 8c almost certainly a hardware task. Compare each widget's
  screenshot to the sketch's intent (screenshots-are-aesthetic memory).

## Decisions (settled — do NOT re-ask)

1. **Phase 8 fills the phase-6 placeholders by swapping launch commands, keeping
   the `cc-*` app-ids** — the phase-6 contract. No new layout is invented here.
2. **Every colored widget plugs into the phase-7 palette** (runtime-read
   `colors.env` or a `gen.py` template) — reskinning ws 0 with the rest of the
   desktop.
3. **cava is the only foot/TUI Control Center widget** (phase-6 settled
   decision 2); it's `cc-cava`'s sole content.
4. **The now-playing widget is spine'd on `playerctl`/MPRIS** — decoupled from
   the Spotify client, so its mechanism is VM-testable against Firefox.
5. **calendar/todo/Jarvis and the TBD zone are out of scope** — gated on the
   Jarvis build; phase 6 only reserved their spots.
6. **8a first, then 8b; 8c prepared-and-deferred to real hardware.** Order by
   VM-testability and independence.

---

## Commit breakdown (one logical change each)

**8a — cava:**
1. *"Add cava config templated from the palette (phase 8)"* — `cava/config` (or
   `.in` + `gen.py` wiring) + symlink; inert until cava runs there.
2. *"Run cava in the Control Center cava panel (phase 8)"* — the
   `control-center.sh` swap (`foot --app-id=cc-cava cava`).
3. *"Re-theme cava on theme switch (phase 8)"* — extend `set-theme.sh` to respawn
   the ws-0 widgets so cava picks up palette changes.

**8b — Spotify widget** (after the toolkit decision):
4. *"Add playerctl now-playing widget for the music panel (phase 8)"* — the new
   `hypr/scripts/cc-music.*`, palette-read, `playerctl`-driven (song + controls;
   queue per Open decision 2).
5. *"Run the now-playing widget in the music panel (phase 8)"* — the
   `control-center.sh` swap for `cc-music` (+ repoint the rule's `match` if the
   toolkit gives the window a new class).

**8c — Spicetify** (real hardware, likely later):
6. *"Generate Spicetify color.ini from the palette (phase 8)"* — the template +
   `gen.py` wiring (text-judgeable in the VM).
7. *"Apply Spicetify theme to the Spotify client (phase 8)"* — the apply step /
   `set-theme --spicetify` flag — **on hardware, after verifying Spotify runs.**

Each commit leaves the repo working (inert config first, then flip it on), the
same rhythm as phases 4/6/7.

## Verify (don't skip)

- **8a:** `Super+0`; the `cc-cava` panel runs cava in the accent colour on a
  transparent background at its zone. Run `set-theme purple-blue` → the cava
  panel re-themes (after respawn). Screenshot ws 0, compare to the sketch. Audio
  liveness (do the bars move) is a separate verify-live once a monitor source
  exists — not a blocker.
- **8b:** with **Firefox** playing something, the `cc-music` widget shows the
  track and pause/skip actually drive it (`playerctl` verbs). Confirm it re-themes
  on `set-theme`. The real-Spotify hookup and the "queue of 2" (if built) are
  hardware/Web-API verifies.
- **8c (hardware):** Spotify launches, routes to ws 4, and Spicetify applies the
  palette's `color.ini`; re-verify after a Spotify update.
- **Screenshots are aesthetic too** (project memory) — compare each filled panel
  to the phase-6 sketch's intent, don't just check it runs.

## Done when

- **8a:** `cc-cava` runs cava, themed from the palette (a `gen.py` consumer),
  transparent, re-theming on `set-theme` via the ws-0 respawn. (VM-complete.)
- **8b:** `cc-music` runs a `playerctl`-driven now-playing widget (toolkit per
  Open decision 1) — song + pause/skip, palette-themed, mechanism verified
  against Firefox. Queue per Open decision 2.
- **8c:** *(hardware)* the Spotify client is Spicetify-skinned to the palette,
  Spotify routes to ws 4. Prepared-only in the VM.
- **Untouched (gated):** calendar/todo, the TBD zone, the ASCII-art terminal, and
  all Jarvis integration — waiting on Jarvis or on phase-6 Open decision 2.

---

## Open decisions still needed (ask Sergi — do NOT invent)

1. **Now-playing widget toolkit** — TUI-in-foot / **GTK-in-Python (recommended,
   mirrors `volume-slider.py`)** / eww. Decides how the widget is built and
   themed, and whether the `cc-music` rule's `match` needs repointing.
2. **The "queue of 2 songs."** MPRIS/`playerctl` **can't** provide the upcoming
   queue. Drop it for the first cut (recommended — song + controls only), or add
   Spotify-Web-API integration (OAuth + token, real-Spotify-only, bigger scope)?
3. **cava's look** — gradient `accent → accent_bright` up the bars vs a flat
   accent; bar width/spacing/style. Pure aesthetics; confirm live.
4. **Is Spicetify part of the live hot-swap or a one-time skin?** Recommendation:
   generate its `color.ini` from the palette but **re-apply manually** (not on
   every `set-theme` — it patches + restarts the client). Confirm.
5. **The ASCII-art quick-task terminal — resolve phase-6 Open decision 2 first.**
   Is that terminal dropped, folded into the TBD zone, or wanted somewhere? Only
   then does "ASCII art for it" have a target. Not part of the 8a/8b core.
6. **Where the music-widget script lives** — `hypr/scripts/` (reuses the phase-6
   symlink; recommended) vs a new dir. Minor; confirm.

---

## Kickoff prompt (paste into the new session)

```
Start phase 8 of the Hyprland rice — fill the Control Center placeholders with
real widgets. Read CLAUDE.md, docs/phase-8-control-center-widgets.md, and
docs/phase-6-control-center.md first. The "Decisions (settled)" section is
settled — don't re-ask it.

Do 8a (cava) FIRST — it's the only fully VM-completable item. Swap the cc-cava
placeholder in hypr/scripts/control-center.sh for `foot --app-id=cc-cava cava`
(same app-id, so the phase-6 float rule still matches — no hyprland.lua edit).
Make cava a PALETTE CONSUMER: add a theme/templates/cava.config.in, wire it into
theme/gen.py's TEMPLATES map, symlink cava/config into ~/.config, and extend
set-theme.sh to respawn the ws-0 widgets so cava re-themes. cava's background =
'default' inherits foot's transparent themed bg.

Then 8b (Spotify now-playing widget for cc-music): spine it on playerctl/MPRIS so
the mechanism is testable against Firefox in the VM. Ask me the toolkit first
(recommend GTK-in-Python, mirroring waybar/scripts/volume-slider.py) and whether
to drop the "queue of 2" — MPRIS can't provide the queue.

Do NOT build calendar/todo, the TBD zone, the ASCII-art terminal, Jarvis, or
finish Spicetify (Spotify is Electron — verify it even runs in the VM before 8c;
it's likely a real-hardware task). I install packages (cava, playerctl, spotify,
spicetify-cli) — you can't pacman. One logical change per commit. Every colored
widget must plug into the phase-7 palette. Ask me the "Open decisions still
needed" before building anything aesthetic — don't invent.
```
